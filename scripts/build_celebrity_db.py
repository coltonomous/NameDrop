#!/usr/bin/env python3
"""
Build celebrity database for the NameDrop game.

Sources:
  1. ESPN Active Athletes (NFL, NBA, MLB, NHL) via public API
  2. Pantheon dataset (downloaded and cached locally as bz2)

Everyone is ranked by how often their English Wikipedia article is read
(average daily page views over the last 60 days) and only the best known
MAX_ENTRIES are kept, so the list is people players are likely to know
rather than every active roster player.

Outputs a minified JSON array to client/assets/celebrities.json.
ESPN results and page views are cached locally to avoid re-fetching.
"""

import argparse
import json
import os
import string
import time
import urllib.request
from collections import defaultdict
from datetime import datetime

import pandas as pd
import requests

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PANTHEON_PATH = os.path.join(SCRIPT_DIR, "person_2025_update.csv.bz2")
PANTHEON_URL = "https://storage.googleapis.com/pantheon-public-data/person_2025_update.csv.bz2"
ESPN_CACHE_PATH = os.path.join(SCRIPT_DIR, "espn_athletes_cache.json")
PAGEVIEWS_CACHE_PATH = os.path.join(SCRIPT_DIR, "pageviews_cache.json")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "client", "assets", "celebrities.json")

# How many of the best-known people to keep.
MAX_ENTRIES = 5000

WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
USER_AGENT = "NameDropDBBuilder/1.0 (https://github.com/coltonomous/NameDrop)"
WIKI_BATCH = 50  # Most pages the API takes per request.

# Article title qualifiers Wikipedia uses for athletes who share a name.
LEAGUE_QUALIFIERS = {
    "NFL Player": "American football",
    "NBA Player": "basketball",
    "MLB Player": "baseball",
    "NHL Player": "ice hockey",
}

SUFFIXES_TO_STRIP = {"Jr.", "Sr.", "Jr", "Sr", "II", "III", "IV", "V"}

# Title prefixes to strip — ordered longest first so multi-word titles
# are matched before their single-word components.
PREFIXES_TO_STRIP = [
    "Holy Roman Emperor", "Holy Roman Empress",
    "Emperor", "Empress", "King", "Queen", "Prince", "Princess",
    "Pope", "Saint", "St.", "Duke", "Duchess", "Grand Duke",
    "Count", "Countess", "Baron", "Baroness",
    "Lord", "Lady", "Sir", "Dame",
    "Sultan", "Caliph", "Shah", "Pharaoh", "Tsar", "Tsarina",
    "Archbishop", "Bishop", "Cardinal",
]

# ---------------------------------------------------------------------------
# ESPN configuration
# ---------------------------------------------------------------------------
ESPN_SPORTS = [
    {
        "sport": "football",
        "league": "nfl",
        "occupation": "NFL Player",
    },
    {
        "sport": "basketball",
        "league": "nba",
        "occupation": "NBA Player",
    },
    {
        "sport": "baseball",
        "league": "mlb",
        "occupation": "MLB Player",
    },
    {
        "sport": "hockey",
        "league": "nhl",
        "occupation": "NHL Player",
    },
]

# ---------------------------------------------------------------------------
# Pantheon occupation tiers
# ---------------------------------------------------------------------------
POP_CULTURE = {
    "ACTOR", "SINGER", "MUSICIAN", "FILM DIRECTOR", "COMEDIAN", "PRESENTER",
    "CELEBRITY", "MODEL", "PRODUCER", "DANCER", "YOUTUBER", "COMIC ARTIST",
}

PUBLIC_FIGURES = {
    "POLITICIAN", "SOCIAL ACTIVIST", "ASTRONAUT", "BUSINESSPERSON",
    "WRITER", "JOURNALIST",
}

SPORTS = {
    "SOCCER PLAYER", "BASKETBALL PLAYER", "TENNIS PLAYER", "ATHLETE",
    "BOXER", "WRESTLER", "RACING DRIVER", "HOCKEY PLAYER",
    "BASEBALL PLAYER", "AMERICAN FOOTBALL PLAYER", "GOLFER", "SWIMMER",
    "GYMNAST", "SKIER", "SKATER", "CYCLIST", "RUGBY PLAYER",
    "MARTIAL ARTS", "CRICKETER",
}


# ---------------------------------------------------------------------------
# Name processing
# ---------------------------------------------------------------------------
def process_name(name: str):
    """
    Clean a name and extract initials.
    Returns (cleaned_name, first_initial, last_initial) or None.
    """
    cleaned = name.strip()

    # Strip title prefixes (longest first to catch multi-word titles),
    # unless the title is part of the name itself ("Queen of Sheba").
    for prefix in PREFIXES_TO_STRIP:
        if cleaned.startswith(prefix + " "):
            rest = cleaned[len(prefix):].strip()
            if rest[:1].isupper():
                cleaned = rest
            break  # Only strip one prefix

    parts = cleaned.split()
    if len(parts) < 2:
        return None
    # Strip suffixes from the end
    while len(parts) > 1 and parts[-1] in SUFFIXES_TO_STRIP:
        parts.pop()
    if len(parts) < 2:
        return None
    first_initial = parts[0][0].upper()
    last_initial = parts[-1][0].upper()
    if first_initial not in string.ascii_uppercase or last_initial not in string.ascii_uppercase:
        return None
    return " ".join(parts), first_initial, last_initial


# ---------------------------------------------------------------------------
# ESPN fetching
# ---------------------------------------------------------------------------
def fetch_espn_athletes() -> list[dict]:
    """
    Fetch active athletes from ESPN for all configured sports.
    Uses local cache if available to avoid redundant API calls.
    """
    if os.path.exists(ESPN_CACHE_PATH):
        age_hours = (time.time() - os.path.getmtime(ESPN_CACHE_PATH)) / 3600
        if age_hours < 168:  # 7 days
            print(f"Using ESPN cache ({age_hours:.1f}h old): {ESPN_CACHE_PATH}")
            with open(ESPN_CACHE_PATH, "r") as f:
                return json.load(f)

    all_athletes = []
    session = requests.Session()

    for cfg in ESPN_SPORTS:
        sport = cfg["sport"]
        league = cfg["league"]
        occupation = cfg["occupation"]
        print(f"\nFetching {league.upper()} teams...")

        # Step 1: Get all team IDs
        teams_url = f"https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams"
        try:
            resp = session.get(teams_url, timeout=30)
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            print(f"  ERROR fetching teams for {league}: {e}")
            continue

        teams = data.get("sports", [{}])[0].get("leagues", [{}])[0].get("teams", [])
        print(f"  Found {len(teams)} teams")

        # Step 2: Fetch roster for each team
        league_count = 0
        for team_entry in teams:
            team = team_entry.get("team", {})
            team_id = team.get("id")
            team_name = team.get("displayName", "?")

            roster_url = f"https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams/{team_id}/roster"
            try:
                resp = session.get(roster_url, timeout=30)
                resp.raise_for_status()
                roster_data = resp.json()
            except Exception as e:
                print(f"  ERROR fetching roster for {team_name}: {e}")
                continue

            athlete_groups = roster_data.get("athletes", [])

            # ESPN uses two formats:
            #   - Grouped: each group has "items" list (NFL, MLB, NHL)
            #   - Flat: each entry IS a player dict (NBA)
            players = []
            for group in athlete_groups:
                if "items" in group and group["items"]:
                    # Grouped format
                    players.extend(group["items"])
                elif "fullName" in group or "displayName" in group:
                    # Flat format — the "group" IS a player
                    players.append(group)

            for player in players:
                full_name = player.get("fullName") or player.get("displayName")
                if not full_name:
                    continue

                birth_year = None
                dob = player.get("dateOfBirth")
                if dob:
                    try:
                        birth_year = int(dob[:4])
                    except (ValueError, TypeError):
                        pass

                all_athletes.append({
                    "name": full_name,
                    "occupation": occupation,
                    "birthYear": birth_year,
                    "source": "espn",
                })
                league_count += 1

            # Small delay to be polite to the API
            time.sleep(0.05)

        print(f"  {league.upper()}: {league_count} athletes")

    # Cache results
    with open(ESPN_CACHE_PATH, "w") as f:
        json.dump(all_athletes, f)
    print(f"\nCached {len(all_athletes)} ESPN athletes to {ESPN_CACHE_PATH}")

    return all_athletes


# ---------------------------------------------------------------------------
# Pantheon processing
# ---------------------------------------------------------------------------
def ensure_pantheon():
    """Download the Pantheon dataset if it isn't cached locally."""
    if os.path.exists(PANTHEON_PATH):
        return
    print(f"Downloading Pantheon dataset from {PANTHEON_URL} ...")
    urllib.request.urlretrieve(PANTHEON_URL, PANTHEON_PATH)


def load_pantheon() -> list[dict]:
    """
    Load and filter the Pantheon dataset per tier rules.
    Returns a list of celebrity dicts.
    """
    ensure_pantheon()
    print(f"\nReading Pantheon CSV from {PANTHEON_PATH} ...")
    df = pd.read_csv(PANTHEON_PATH, compression="bz2")
    print(f"  Total rows: {len(df)}")

    df = df.dropna(subset=["name", "hpi", "occupation"]).copy()
    df = df[df["is_group"].astype(str).str.upper() != "TRUE"]
    df["_occ_upper"] = df["occupation"].str.strip().str.upper()
    df["_birth"] = pd.to_numeric(df["birthyear"], errors="coerce")

    selected_indices = set()

    # These tiers only pick candidates. Pantheon's HPI favors people known
    # in many languages, so cast a wide net and let English page views
    # decide who makes the final list.

    # Tier 1: Pop culture, born after 1900
    pop = df[(df["_occ_upper"].isin(POP_CULTURE)) & (df["_birth"] > 1900)]
    pop = pop.sort_values(by="hpi", ascending=False).head(12000)
    selected_indices.update(pop.index)
    print(f"  Tier 1 (pop culture, born>1900, top 12000): {len(pop)}")

    # Tier 2: Public figures, born after 1900
    pub = df[(df["_occ_upper"].isin(PUBLIC_FIGURES)) & (df["_birth"] > 1900)]
    pub = pub.sort_values(by="hpi", ascending=False).head(3000)
    selected_indices.update(pub.index)
    print(f"  Tier 2 (public figures, born>1900, top 3000): {len(pub)}")

    # Tier 3: Retired sports legends, born after 1900
    # (Current athletes come from ESPN; this catches retired greats)
    sports = df[(df["_occ_upper"].isin(SPORTS)) & (df["_birth"] > 1900)]
    sports = sports.sort_values(by="hpi", ascending=False).head(6000)
    selected_indices.update(sports.index)
    print(f"  Tier 3 (sports legends, born>1900, top 6000): {len(sports)}")

    # Tier 4: All-time legends regardless of category
    legends = df.sort_values(by="hpi", ascending=False).head(1000)
    selected_indices.update(legends.index)
    print(f"  Tier 4 (all-time legends, top 1000): {len(legends)}")

    combined = df.loc[list(selected_indices)].sort_values(by="hpi", ascending=False)
    print(f"  Combined unique Pantheon entries: {len(combined)}")

    results = []
    for _, row in combined.iterrows():
        occ_val = str(row["occupation"]).strip().title()
        hpi_val = round(float(row["hpi"]), 2) if pd.notna(row["hpi"]) else 0.0
        birth_val = int(row["_birth"]) if pd.notna(row["_birth"]) else None

        results.append({
            "name": str(row["name"]),
            "occupation": occ_val,
            "birthYear": birth_val,
            "hpi": hpi_val,
            "pageId": int(row["wp_id"]) if pd.notna(row["wp_id"]) else None,
            "source": "pantheon",
        })

    return results


# ---------------------------------------------------------------------------
# Wikipedia page views
# ---------------------------------------------------------------------------
def _wiki_query(session, params: dict) -> dict:
    """
    Run one Action API query, following continuation, and return the merged
    {"pages": [...], "normalized": [...], "redirects": [...]}.
    """
    merged = {"pages": {}, "normalized": [], "redirects": []}
    cont = {}
    while True:
        for attempt in range(4):
            try:
                resp = session.get(
                    WIKIPEDIA_API,
                    params={**params, **cont, "format": "json", "formatversion": "2"},
                    headers={"User-Agent": USER_AGENT},
                    timeout=30,
                )
                resp.raise_for_status()
                data = resp.json()
                break
            except Exception as e:
                if attempt == 3:
                    raise
                print(f"  Wikipedia request failed ({e}); retrying...")
                time.sleep(2 ** attempt)
        query = data.get("query", {})
        merged["normalized"] += query.get("normalized", [])
        merged["redirects"] += query.get("redirects", [])
        for page in query.get("pages", []):
            key = page.get("pageid") or page.get("title")
            seen = merged["pages"].setdefault(key, page)
            if seen is not page:
                seen["pageviews"] = {**(seen.get("pageviews") or {}), **(page.get("pageviews") or {})}
                if "pageprops" in page:
                    seen["pageprops"] = page["pageprops"]
        if "continue" not in data:
            break
        cont = data["continue"]
        time.sleep(0.1)
    merged["pages"] = list(merged["pages"].values())
    return merged


def average_daily_views(page: dict) -> float:
    """Average daily views over the days the API has data for."""
    days = [v for v in (page.get("pageviews") or {}).values() if v is not None]
    return sum(days) / len(days) if days else 0.0


def _is_article(page: dict) -> bool:
    return (
        page.get("ns") == 0
        and not page.get("missing")
        and not page.get("invalid")
        and "disambiguation" not in (page.get("pageprops") or {})
    )


def views_by_page_id(session, page_ids: list[int]) -> dict[int, float]:
    """Average daily views for each English Wikipedia page id."""
    views = {}
    for i in range(0, len(page_ids), WIKI_BATCH):
        batch = page_ids[i:i + WIKI_BATCH]
        result = _wiki_query(session, {
            "action": "query",
            "prop": "pageviews",
            "pageids": "|".join(str(p) for p in batch),
        })
        for page in result["pages"]:
            if page.get("pageid") is not None:
                views[page["pageid"]] = average_daily_views(page)
        time.sleep(0.1)
    return views


def views_by_title(session, titles: list[str]) -> dict[str, tuple[int, float]]:
    """
    Look up titles (following redirects) and return {title: (page id,
    average daily views)} for the ones that are real articles, not
    disambiguation pages.
    """
    found = {}
    for i in range(0, len(titles), WIKI_BATCH):
        batch = titles[i:i + WIKI_BATCH]
        result = _wiki_query(session, {
            "action": "query",
            "prop": "pageviews|pageprops",
            "ppprop": "disambiguation",
            "redirects": "1",
            "titles": "|".join(batch),
        })
        normalized = {n["from"]: n["to"] for n in result["normalized"]}
        redirects = {r["from"]: r["to"] for r in result["redirects"]}
        pages = {p["title"]: p for p in result["pages"] if "title" in p}
        for title in batch:
            final = normalized.get(title, title)
            final = redirects.get(final, final)
            page = pages.get(final)
            if page and _is_article(page):
                found[title] = (page["pageid"], average_daily_views(page))
        time.sleep(0.1)
    return found


def add_page_views(entries: list[dict], session) -> None:
    """
    Set "views" (average daily English Wikipedia views) and "pageId" on each
    entry. Pantheon entries carry their page id. ESPN athletes are looked up
    by name, then as e.g. "Name (American football)" if the plain name is
    missing or ambiguous. Results are cached for a week.
    """
    cache = {}
    if os.path.exists(PAGEVIEWS_CACHE_PATH):
        age_hours = (time.time() - os.path.getmtime(PAGEVIEWS_CACHE_PATH)) / 3600
        if age_hours < 168:
            with open(PAGEVIEWS_CACHE_PATH, "r") as f:
                cache = json.load(f)
            print(f"Using page view cache ({age_hours:.1f}h old, {len(cache)} entries)")

    def key(entry):
        return f"id:{entry['pageId']}" if entry.get("pageId") else f"title:{entry['name']}"

    todo = [e for e in entries if key(e) not in cache]

    by_id = [e for e in todo if e.get("pageId")]
    if by_id:
        print(f"Fetching page views for {len(by_id)} pages by id...")
        views = views_by_page_id(session, [e["pageId"] for e in by_id])
        for e in by_id:
            cache[key(e)] = [e["pageId"], views.get(e["pageId"], 0.0)]

    by_name = [e for e in todo if not e.get("pageId")]
    if by_name:
        print(f"Fetching page views for {len(by_name)} pages by name...")
        found = views_by_title(session, sorted({e["name"] for e in by_name}))
        retry = defaultdict(list)
        for e in by_name:
            if e["name"] in found:
                cache[key(e)] = list(found[e["name"]])
            elif e.get("occupation") in LEAGUE_QUALIFIERS:
                retry[f"{e['name']} ({LEAGUE_QUALIFIERS[e['occupation']]})"].append(e)
            else:
                cache[key(e)] = [None, 0.0]
        if retry:
            print(f"Retrying {len(retry)} names with a sport qualifier...")
            found = views_by_title(session, sorted(retry))
            for title, group in retry.items():
                for e in group:
                    cache[key(e)] = list(found.get(title, (None, 0.0)))

    with open(PAGEVIEWS_CACHE_PATH, "w") as f:
        json.dump(cache, f)

    for e in entries:
        page_id, views = cache[key(e)]
        e["pageId"] = page_id
        e["views"] = views


# ---------------------------------------------------------------------------
# Merging, ranking & deduplication
# ---------------------------------------------------------------------------
def prepare_candidates(espn_athletes: list[dict], pantheon_entries: list[dict]):
    """
    Apply name processing rules to both sources. Pantheon comes first so it
    wins ties later (its entries have exact page ids and richer metadata).
    """
    candidates = []
    stats = {"skipped_mono": 0, "skipped_initial": 0}
    for entry in [*pantheon_entries, *espn_athletes]:
        result = process_name(entry["name"])
        if result is None:
            parts = entry["name"].strip().split()
            if len(parts) < 2:
                stats["skipped_mono"] += 1
            else:
                stats["skipped_initial"] += 1
            continue
        cleaned_name, first_initial, last_initial = result
        candidates.append({
            **entry,
            "name": cleaned_name,
            "firstInitial": first_initial,
            "lastInitial": last_initial,
        })
    return candidates, stats


def rank_and_deduplicate(candidates: list[dict], max_entries: int, stats: dict) -> list[dict]:
    """
    Keep the best-known person for each name and each Wikipedia page, drop
    anyone without page views, and keep the top max_entries by views.
    """
    stats.update({"skipped_dup": 0, "skipped_no_views": 0, "espn": 0, "pantheon": 0})
    # Stable sort: on equal views, earlier (Pantheon) entries win.
    ranked = sorted(candidates, key=lambda e: -e["views"])
    seen_names, seen_pages, kept = set(), set(), []
    for e in ranked:
        if e["views"] <= 0:
            stats["skipped_no_views"] += 1
            continue
        name_key = e["name"].lower()
        if name_key in seen_names or (e.get("pageId") and e["pageId"] in seen_pages):
            stats["skipped_dup"] += 1
            continue
        seen_names.add(name_key)
        if e.get("pageId"):
            seen_pages.add(e["pageId"])
        kept.append(e)
        if len(kept) == max_entries:
            break

    celebrities = []
    for e in kept:
        stats[e["source"]] += 1
        celebrities.append({
            "name": e["name"],
            "firstInitial": e["firstInitial"],
            "lastInitial": e["lastInitial"],
            "occupation": e["occupation"],
            "birthYear": e.get("birthYear"),
            "hpi": e.get("hpi", 0),
            "views": round(e["views"]),
        })
    return celebrities


def hard_letters(celebrities: list[dict]) -> list[str]:
    """
    Letters the game treats as hard (see BoardGenerator.findHardLetters):
    they start under 30% as many first and last names as the median letter.
    """
    counts = defaultdict(int)
    for c in celebrities:
        counts[c["firstInitial"]] += 1
        counts[c["lastInitial"]] += 1
    letters = [l for l in string.ascii_uppercase if l != "X"]
    median = sorted(counts[l] for l in letters)[len(letters) // 2]
    return [l for l in letters if counts[l] < median * 0.3]


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------
def print_report(celebrities: list[dict], stats: dict, file_size: int):
    letters = list(string.ascii_uppercase)

    print("\n" + "=" * 70)
    print("BUILD REPORT")
    print("=" * 70)
    print(f"Total entries: {len(celebrities)}")
    print(f"File size: {file_size / 1024:.1f} KB ({file_size / (1024*1024):.2f} MB)")

    print(f"\n--- Entries by Source ---")
    print(f"  ESPN athletes: {stats['espn']}")
    print(f"  Pantheon: {stats['pantheon']}")
    print(f"  Skipped (mononymous): {stats['skipped_mono']}")
    print(f"  Skipped (non-A-Z initial): {stats['skipped_initial']}")
    print(f"  Skipped (duplicate): {stats['skipped_dup']}")
    print(f"  Skipped (no English Wikipedia views): {stats['skipped_no_views']}")

    if celebrities:
        views = [c["views"] for c in celebrities]
        print(f"\n--- Daily English Wikipedia Views ---")
        print(f"  Most viewed: {celebrities[0]['name']} ({views[0]:,}/day)")
        print(f"  Median: {sorted(views)[len(views) // 2]:,}/day")
        print(f"  Cutoff (least viewed kept): {celebrities[-1]['name']} ({views[-1]:,}/day)")

    # Occupation breakdown
    occ_counts = defaultdict(int)
    for c in celebrities:
        occ_counts[c["occupation"]] += 1
    print(f"\n--- Top 15 Occupations ---")
    for occ, count in sorted(occ_counts.items(), key=lambda x: -x[1])[:15]:
        print(f"  {occ}: {count}")

    # Initial pair coverage
    grid = defaultdict(int)
    for c in celebrities:
        grid[(c["firstInitial"], c["lastInitial"])] += 1

    zero_pairs = []
    for fi in letters:
        for li in letters:
            if grid.get((fi, li), 0) == 0:
                zero_pairs.append(f"{fi}.{li}.")

    first_totals = defaultdict(int)
    last_totals = defaultdict(int)
    for c in celebrities:
        first_totals[c["firstInitial"]] += 1
        last_totals[c["lastInitial"]] += 1

    print(f"\n--- Initial Pair Coverage ---")
    print(f"  Covered pairs: {676 - len(zero_pairs)} / 676")
    print(f"  Empty pairs: {len(zero_pairs)}")
    if zero_pairs:
        print(f"  Missing: {', '.join(zero_pairs[:30])}{'...' if len(zero_pairs) > 30 else ''}")
    print(f"  Best first initials: {', '.join(f'{l}({first_totals[l]})' for l in sorted(first_totals, key=lambda x: -first_totals[x])[:5])}")
    print(f"  Weakest first initials: {', '.join(f'{l}({first_totals[l]})' for l in sorted(first_totals, key=lambda x: first_totals[x])[:5])}")
    print(f"  Hard letters (rarer on boards, never cross each other): {', '.join(hard_letters(celebrities))}")

    # Spot check: find 10 recognizable names across categories
    spot_check_names = [
        "Tom Hanks", "Taylor Swift", "LeBron James", "Albert Einstein",
        "Leonardo DiCaprio", "Patrick Mahomes", "Martin Luther King",
        "Stephen Hawking", "Quentin Tarantino", "Barack Obama",
    ]
    name_set = {c["name"].lower(): c for c in celebrities}
    print(f"\n--- Spot Check (10 recognizable names) ---")
    for target in spot_check_names:
        found = name_set.get(target.lower())
        if found:
            print(f"  FOUND: {found['name']} ({found['occupation']}, {found['firstInitial']}.{found['lastInitial']}.)")
        else:
            # Try partial match
            matches = [c for c in celebrities if target.lower().split()[0] in c["name"].lower() and target.lower().split()[-1] in c["name"].lower()]
            if matches:
                m = matches[0]
                print(f"  FOUND (fuzzy): {m['name']} ({m['occupation']}, {m['firstInitial']}.{m['lastInitial']}.)")
            else:
                print(f"  MISSING: {target}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(argv=None, session=None):
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--output", default=OUTPUT_PATH)
    parser.add_argument("--max-entries", type=int, default=MAX_ENTRIES)
    args = parser.parse_args(argv)

    print("=" * 70)
    print("NameDrop Celebrity Database Builder")
    print(f"Started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # Source 1: ESPN
    espn_athletes = fetch_espn_athletes()

    # Source 2: Pantheon
    pantheon_entries = load_pantheon()

    # Rank everyone by English Wikipedia page views
    print("\nPreparing candidates...")
    candidates, stats = prepare_candidates(espn_athletes, pantheon_entries)
    add_page_views(candidates, session or requests.Session())
    celebrities = rank_and_deduplicate(candidates, args.max_entries, stats)

    # Write output
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(celebrities, f, ensure_ascii=False, separators=(",", ":"))

    file_size = os.path.getsize(args.output)
    print(f"\nWrote {len(celebrities)} entries to {args.output}")

    # Report
    print_report(celebrities, stats, file_size)


if __name__ == "__main__":
    main()
