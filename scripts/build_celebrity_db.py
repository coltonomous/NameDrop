#!/usr/bin/env python3
"""
Build celebrity database for the NameDrop game.

Downloads the Pantheon dataset, filters/processes it, and outputs a JSON file
of top celebrities with their initials, occupation, birth year, and HPI score.
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

# Processing constants
TOP_N = 5000
SUFFIXES_TO_STRIP = {"Jr.", "Sr.", "Jr", "Sr", "II", "III", "IV", "V"}


def download_data():
    """Download the Pantheon CSV if not already cached locally."""
    if os.path.exists(CACHE_PATH):
        print(f"Using cached file: {CACHE_PATH}")
        return
    print(f"Downloading from {DATA_URL} ...")
    urllib.request.urlretrieve(DATA_URL, CACHE_PATH)
    size_mb = os.path.getsize(CACHE_PATH) / (1024 * 1024)
    print(f"Downloaded {size_mb:.1f} MB to {CACHE_PATH}")


def load_and_inspect(path):
    """Load the CSV and print column names for verification."""
    print(f"\nReading CSV from {path} ...")
    df = pd.read_csv(path)
    print(f"Shape: {df.shape}")
    print(f"Columns: {list(df.columns)}")
    print(f"First row sample:\n{df.iloc[0].to_dict()}\n")
    return df


def process_name(name):
    """
    Split name, strip suffixes, return (cleaned_name, first_initial, last_initial).
    Returns None if the name is mononymous or initials are not A-Z.
    """
    parts = name.strip().split()
    if len(parts) < 2:
        return None

    # Strip trailing suffixes
    while len(parts) > 1 and parts[-1] in SUFFIXES_TO_STRIP:
        parts.pop()

    if len(parts) < 2:
        return None

    first_initial = parts[0][0].upper()
    last_initial = parts[-1][0].upper()

    if first_initial not in string.ascii_uppercase or last_initial not in string.ascii_uppercase:
        return None

    cleaned_name = " ".join(parts)
    return cleaned_name, first_initial, last_initial


def build_database(df):
    """Filter, process, and return the celebrity list."""
    # Identify the right column names (case-insensitive matching)
    col_map = {c.lower(): c for c in df.columns}

    name_col = col_map.get("name", col_map.get("en_curid", None))
    hpi_col = col_map.get("hpi", col_map.get("historical popularity index", None))
    occ_col = col_map.get("occupation", col_map.get("occ", None))
    birth_col = col_map.get("birthyear", col_map.get("birth_year", col_map.get("byear", None)))

    print(f"Using columns -> name: {name_col}, hpi: {hpi_col}, occupation: {occ_col}, birthyear: {birth_col}")

    # Sort by HPI descending and take top N
    df_sorted = df.sort_values(by=hpi_col, ascending=False).head(TOP_N).copy()
    print(f"Processing top {len(df_sorted)} entries by HPI...")

    celebrities = []
    skipped_mono = 0
    skipped_initial = 0

    for _, row in df_sorted.iterrows():
        raw_name = str(row[name_col])
        result = process_name(raw_name)
        if result is None:
            if len(raw_name.strip().split()) < 2:
                skipped_mono += 1
            else:
                skipped_initial += 1
            continue

        cleaned_name, first_initial, last_initial = result

        hpi_val = row[hpi_col]
        occ_val = str(row[occ_col]) if pd.notna(row[occ_col]) else "Unknown"
        birth_val = row[birth_col]

        # Clean up occupation: title case
        occ_val = occ_val.strip().title() if occ_val else "Unknown"

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
    """Print a 26x26 coverage grid and summary stats."""
    grid = defaultdict(int)
    for c in celebrities:
        key = (c["firstInitial"], c["lastInitial"])
        grid[key] += 1

    letters = list(string.ascii_uppercase)

    print("\n" + "=" * 80)
    print("COVERAGE REPORT")
    print("=" * 80)
    print(f"Total entries: {len(celebrities)}")
    print()

    # Header row
    header = "     " + "  ".join(f"{l:>3}" for l in letters)
    print("Last Initial ->")
    print(header)
    print("First")
    print("Init.")
    print("  |")

    zero_pairs = []
    for fi in letters:
        row_vals = []
        for li in letters:
            count = grid.get((fi, li), 0)
            row_vals.append(count)
            if count == 0:
                zero_pairs.append(f"{fi}{li}")
        row_str = f"  {fi}  " + "  ".join(f"{v:>3}" for v in row_vals)
        print(row_str)

    # First initial totals
    print("\n--- First Initial Totals ---")
    first_totals = defaultdict(int)
    for c in celebrities:
        first_totals[c["firstInitial"]] += 1
    zero_first = []
    for l in letters:
        count = first_totals.get(l, 0)
        if count == 0:
            zero_first.append(l)
        print(f"  {l}: {count}")

    # Last initial totals
    print("\n--- Last Initial Totals ---")
    last_totals = defaultdict(int)
    for c in celebrities:
        last_totals[c["lastInitial"]] += 1
    zero_last = []
    for l in letters:
        count = last_totals.get(l, 0)
        if count == 0:
            zero_last.append(l)
        print(f"  {l}: {count}")

    print(f"\n--- Summary ---")
    print(f"Total entries: {len(celebrities)}")
    print(f"Initial pairs with 0 celebrities: {len(zero_pairs)} / 676")
    if zero_pairs:
        print(f"Zero-coverage pairs: {', '.join(zero_pairs[:50])}")
        if len(zero_pairs) > 50:
            print(f"  ... and {len(zero_pairs) - 50} more")
    if zero_first:
        print(f"First initials with ZERO coverage: {', '.join(zero_first)}")
    else:
        print("All first initials have coverage.")
    if zero_last:
        print(f"Last initials with ZERO coverage: {', '.join(zero_last)}")
    else:
        print("All last initials have coverage.")


def main():
    download_data()
    df = load_and_inspect(CACHE_PATH)
    celebrities = build_database(df)

    # Ensure output directory exists
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    # Write JSON
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(celebrities, f, ensure_ascii=False, indent=None)
    file_size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    print(f"\nWrote {len(celebrities)} entries to {OUTPUT_PATH} ({file_size_kb:.1f} KB)")

    print_coverage_report(celebrities)


if __name__ == "__main__":
    main()
