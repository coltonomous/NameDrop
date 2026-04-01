#!/usr/bin/env python3
"""
Build celebrity database for the NameDrop game.

Downloads the Pantheon dataset, filters/processes it, and outputs a JSON file
weighted toward pop-culturally recognizable names.
"""

import json
import os
import string
import urllib.request
from collections import defaultdict

import pandas as pd

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_PATH = os.path.join(SCRIPT_DIR, "person_2025_update.csv.bz2")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "client", "assets", "celebrities.json")
DATA_URL = "https://storage.googleapis.com/pantheon-public-data/person_2025_update.csv.bz2"

SUFFIXES_TO_STRIP = {"Jr.", "Sr.", "Jr", "Sr", "II", "III", "IV", "V"}

# Pop culture occupations — take generously from these.
POP_CULTURE = {
    "ACTOR", "SINGER", "MUSICIAN", "FILM DIRECTOR", "COMEDIAN", "PRESENTER",
    "CELEBRITY", "MODEL", "PRODUCER", "DANCER", "YOUTUBER", "COMIC ARTIST",
    "PORNOGRAPHIC ACTOR",
}

# Sports — recognizable athletes.
SPORTS = {
    "SOCCER PLAYER", "BASKETBALL PLAYER", "TENNIS PLAYER", "ATHLETE",
    "BOXER", "WRESTLER", "RACING DRIVER", "HOCKEY PLAYER",
    "BASEBALL PLAYER", "AMERICAN FOOTBALL PLAYER", "GOLFER", "SWIMMER",
    "GYMNAST", "SKIER", "SKATER", "CYCLIST", "RUGBY PLAYER",
    "MARTIAL ARTS", "CRICKETER",
}

# Public figures people might know.
PUBLIC_FIGURES = {
    "POLITICIAN", "SOCIAL ACTIVIST", "ASTRONAUT", "BUSINESSPERSON",
    "WRITER", "JOURNALIST", "CHEF", "FASHION DESIGNER", "GAME DESIGNER",
    "MAGICIAN",
}


def download_data():
    if os.path.exists(CACHE_PATH):
        print(f"Using cached file: {CACHE_PATH}")
        return
    print(f"Downloading from {DATA_URL} ...")
    urllib.request.urlretrieve(DATA_URL, CACHE_PATH)
    size_mb = os.path.getsize(CACHE_PATH) / (1024 * 1024)
    print(f"Downloaded {size_mb:.1f} MB to {CACHE_PATH}")


def load_data(path):
    print(f"\nReading CSV from {path} ...")
    df = pd.read_csv(path)
    print(f"Shape: {df.shape}")
    return df


def process_name(name):
    parts = name.strip().split()
    if len(parts) < 2:
        return None
    while len(parts) > 1 and parts[-1] in SUFFIXES_TO_STRIP:
        parts.pop()
    if len(parts) < 2:
        return None
    first_initial = parts[0][0].upper()
    last_initial = parts[-1][0].upper()
    if first_initial not in string.ascii_uppercase or last_initial not in string.ascii_uppercase:
        return None
    return " ".join(parts), first_initial, last_initial


def build_database(df):
    col_map = {c.lower(): c for c in df.columns}
    name_col = col_map.get("name")
    hpi_col = col_map.get("hpi")
    occ_col = col_map.get("occupation")
    birth_col = col_map.get("birthyear", col_map.get("birth_year", col_map.get("byear")))

    print(f"Using columns -> name: {name_col}, hpi: {hpi_col}, occupation: {occ_col}, birthyear: {birth_col}")

    df = df.dropna(subset=[name_col, hpi_col, occ_col]).copy()
    df["_occ_upper"] = df[occ_col].str.strip().str.upper()
    df["_birth"] = pd.to_numeric(df[birth_col], errors="coerce")

    selected = set()

    # --- Tier 1: Pop culture, post-1900, top 12000 by HPI ---
    pop = df[(df["_occ_upper"].isin(POP_CULTURE)) & (df["_birth"] >= 1900)]
    pop = pop.sort_values(by=hpi_col, ascending=False).head(12000)
    selected.update(pop.index)
    print(f"Tier 1 (pop culture): {len(pop)}")

    # --- Tier 2: Sports, post-1900, top 3000 by HPI ---
    sports = df[(df["_occ_upper"].isin(SPORTS)) & (df["_birth"] >= 1900)]
    sports = sports.sort_values(by=hpi_col, ascending=False).head(3000)
    selected.update(sports.index)
    print(f"Tier 2 (sports): {len(sports)}")

    # --- Tier 3: Public figures, post-1900, top 2000 by HPI ---
    public = df[(df["_occ_upper"].isin(PUBLIC_FIGURES)) & (df["_birth"] >= 1900)]
    public = public.sort_values(by=hpi_col, ascending=False).head(2000)
    selected.update(public.index)
    print(f"Tier 3 (public figures): {len(public)}")

    # --- Tier 4: All-time legends regardless of category, top 750 by HPI ---
    legends = df.sort_values(by=hpi_col, ascending=False).head(750)
    selected.update(legends.index)
    print(f"Tier 4 (all-time legends): {len(legends)}")

    combined = df.loc[list(selected)].sort_values(by=hpi_col, ascending=False)
    print(f"Combined unique entries: {len(combined)}")

    celebrities = []
    skipped_mono = 0
    skipped_initial = 0
    seen_names = set()

    for _, row in combined.iterrows():
        raw_name = str(row[name_col])
        result = process_name(raw_name)
        if result is None:
            if len(raw_name.strip().split()) < 2:
                skipped_mono += 1
            else:
                skipped_initial += 1
            continue

        cleaned_name, first_initial, last_initial = result

        # Deduplicate by normalized name.
        name_key = cleaned_name.lower()
        if name_key in seen_names:
            continue
        seen_names.add(name_key)

        occ_val = str(row[occ_col]).strip().title() if pd.notna(row[occ_col]) else "Unknown"
        hpi_val = row[hpi_col]
        birth_val = row["_birth"]

        entry = {
            "name": cleaned_name,
            "firstInitial": first_initial,
            "lastInitial": last_initial,
            "occupation": occ_val,
            "birthYear": int(birth_val) if pd.notna(birth_val) else None,
            "hpi": round(float(hpi_val), 2) if pd.notna(hpi_val) else 0.0,
        }
        celebrities.append(entry)

    print(f"\nResults: {len(celebrities)} celebrities kept")
    print(f"Skipped: {skipped_mono} mononymous, {skipped_initial} non-A-Z initials")
    return celebrities


def print_coverage_report(celebrities):
    grid = defaultdict(int)
    for c in celebrities:
        grid[(c["firstInitial"], c["lastInitial"])] += 1

    letters = list(string.ascii_uppercase)

    print("\n" + "=" * 60)
    print("COVERAGE REPORT")
    print("=" * 60)
    print(f"Total entries: {len(celebrities)}")

    # Occupation breakdown
    occ_counts = defaultdict(int)
    for c in celebrities:
        occ_counts[c["occupation"]] += 1
    print("\n--- Top Occupations ---")
    for occ, count in sorted(occ_counts.items(), key=lambda x: -x[1])[:15]:
        print(f"  {occ}: {count}")

    # Initial coverage
    zero_pairs = []
    for fi in letters:
        for li in letters:
            if grid.get((fi, li), 0) == 0:
                zero_pairs.append(f"{fi}{li}")

    first_totals = defaultdict(int)
    last_totals = defaultdict(int)
    for c in celebrities:
        first_totals[c["firstInitial"]] += 1
        last_totals[c["lastInitial"]] += 1

    print(f"\n--- Initial Coverage ---")
    print(f"Pairs with 0 celebrities: {len(zero_pairs)} / 676")
    print(f"Best first initials: {', '.join(f'{l}({first_totals[l]})' for l in sorted(first_totals, key=lambda x: -first_totals[x])[:5])}")
    print(f"Weakest first initials: {', '.join(f'{l}({first_totals[l]})' for l in sorted(first_totals, key=lambda x: first_totals[x])[:5])}")
    print(f"Best last initials: {', '.join(f'{l}({last_totals[l]})' for l in sorted(last_totals, key=lambda x: -last_totals[x])[:5])}")
    print(f"Weakest last initials: {', '.join(f'{l}({last_totals[l]})' for l in sorted(last_totals, key=lambda x: last_totals[x])[:5])}")

    # Sample entries by era
    modern = [c for c in celebrities if c.get("birthYear") and c["birthYear"] >= 1960]
    print(f"\nPost-1960 entries: {len(modern)} ({100*len(modern)//len(celebrities)}%)")


def main():
    download_data()
    df = load_data(CACHE_PATH)
    celebrities = build_database(df)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(celebrities, f, ensure_ascii=False, indent=None)
    file_size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    print(f"\nWrote {len(celebrities)} entries to {OUTPUT_PATH} ({file_size_kb:.1f} KB)")

    print_coverage_report(celebrities)


if __name__ == "__main__":
    main()
