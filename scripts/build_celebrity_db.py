#!/usr/bin/env python3
"""
Build celebrity database for the NameDrop game.

Sources:
  1. ESPN Active Athletes (NFL, NBA, MLB, NHL) via public API
  2. Pantheon dataset (cached locally as bz2)

Outputs a minified JSON array to client/assets/celebrities.json.
ESPN results are cached locally to avoid re-fetching on re-runs.
"""

import json
import os
import string
import time
from collections import defaultdict
from datetime import datetime

import pandas as pd
import requests

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PANTHEON_PATH = os.path.join(SCRIPT_DIR, "person_2025_update.csv.bz2")
ESPN_CACHE_PATH = os.path.join(SCRIPT_DIR, "espn_athletes_cache.json")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "client", "assets", "celebrities.json")

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

    # Strip title prefixes (longest first to catch multi-word titles).
    for prefix in PREFIXES_TO_STRIP:
        if cleaned.startswith(prefix + " "):
            cleaned = cleaned[len(prefix):].strip()
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
def load_pantheon() -> list[dict]:
    """
    Load and filter the Pantheon dataset per tier rules.
    Returns a list of celebrity dicts.
    """
    print(f"\nReading Pantheon CSV from {PANTHEON_PATH} ...")
    df = pd.read_csv(PANTHEON_PATH, compression="bz2")
    print(f"  Total rows: {len(df)}")

    df = df.dropna(subset=["name", "hpi", "occupation"]).copy()
    df["_occ_upper"] = df["occupation"].str.strip().str.upper()
    df["_birth"] = pd.to_numeric(df["birthyear"], errors="coerce")

    selected_indices = set()

    # Tier 1: Pop culture, born after 1900, top 5000 by HPI
    pop = df[(df["_occ_upper"].isin(POP_CULTURE)) & (df["_birth"] > 1900)]
    pop = pop.sort_values(by="hpi", ascending=False).head(5000)
    selected_indices.update(pop.index)
    print(f"  Tier 1 (pop culture, born>1900, top 5000): {len(pop)}")

    # Tier 2: Public figures, born after 1900, top 1000 by HPI
    pub = df[(df["_occ_upper"].isin(PUBLIC_FIGURES)) & (df["_birth"] > 1900)]
    pub = pub.sort_values(by="hpi", ascending=False).head(1000)
    selected_indices.update(pub.index)
    print(f"  Tier 2 (public figures, born>1900, top 1000): {len(pub)}")

    # Tier 3: Retired sports legends, born after 1900, top 1500 by HPI
    # (Current athletes come from ESPN; this catches retired greats)
    sports = df[(df["_occ_upper"].isin(SPORTS)) & (df["_birth"] > 1900)]
    sports = sports.sort_values(by="hpi", ascending=False).head(3000)
    selected_indices.update(sports.index)
    print(f"  Tier 3 (sports legends, born>1900, top 3000): {len(sports)}")

    # Tier 4: All-time legends, top 500 regardless of category
    legends = df.sort_values(by="hpi", ascending=False).head(500)
    selected_indices.update(legends.index)
    print(f"  Tier 4 (all-time legends, top 500): {len(legends)}")

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
            "source": "pantheon",
        })

    return results


# ---------------------------------------------------------------------------
# Merging & deduplication
# ---------------------------------------------------------------------------
def merge_and_deduplicate(espn_athletes: list[dict], pantheon_entries: list[dict]) -> list[dict]:
    """
    Merge ESPN and Pantheon sources, deduplicate by lowercase name,
    apply name processing rules, and build final output records.
    ESPN entries take priority (added first).
    """
    seen_names = set()
    celebrities = []
    stats = {"espn": 0, "pantheon": 0, "skipped_mono": 0, "skipped_initial": 0, "skipped_dup": 0}

    # Process ESPN first (higher priority for dedup)
    for entry in espn_athletes:
        result = process_name(entry["name"])
        if result is None:
            parts = entry["name"].strip().split()
            if len(parts) < 2:
                stats["skipped_mono"] += 1
            else:
                stats["skipped_initial"] += 1
            continue

        cleaned_name, first_initial, last_initial = result
        name_key = cleaned_name.lower()
        if name_key in seen_names:
            stats["skipped_dup"] += 1
            continue
        seen_names.add(name_key)

        celebrities.append({
            "name": cleaned_name,
            "firstInitial": first_initial,
            "lastInitial": last_initial,
            "occupation": entry["occupation"],
            "birthYear": entry.get("birthYear"),
            "hpi": 0,
        })
        stats["espn"] += 1

    # Process Pantheon second
    for entry in pantheon_entries:
        result = process_name(entry["name"])
        if result is None:
            parts = entry["name"].strip().split()
            if len(parts) < 2:
                stats["skipped_mono"] += 1
            else:
                stats["skipped_initial"] += 1
            continue

        cleaned_name, first_initial, last_initial = result
        name_key = cleaned_name.lower()
        if name_key in seen_names:
            stats["skipped_dup"] += 1
            continue
        seen_names.add(name_key)

        celebrities.append({
            "name": cleaned_name,
            "firstInitial": first_initial,
            "lastInitial": last_initial,
            "occupation": entry["occupation"],
            "birthYear": entry.get("birthYear"),
            "hpi": entry.get("hpi", 0),
        })
        stats["pantheon"] += 1

    return celebrities, stats


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
def main():
    print("=" * 70)
    print("NameDrop Celebrity Database Builder")
    print(f"Started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # Source 1: ESPN
    espn_athletes = fetch_espn_athletes()

    # Source 2: Pantheon
    pantheon_entries = load_pantheon()

    # Merge and deduplicate
    print("\nMerging and deduplicating...")
    celebrities, stats = merge_and_deduplicate(espn_athletes, pantheon_entries)

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(celebrities, f, ensure_ascii=False, separators=(",", ":"))

    file_size = os.path.getsize(OUTPUT_PATH)
    print(f"\nWrote {len(celebrities)} entries to {OUTPUT_PATH}")

    # Report
    print_report(celebrities, stats, file_size)


if __name__ == "__main__":
    main()
