# NameDrop

A celebrity initials word puzzle game built with Flutter. Fill a grid by naming celebrities whose initials match the required row and column letters.

**Play now:** [coltonomous.github.io/NameDrop](https://coltonomous.github.io/NameDrop/)

## How to Play

- Each cell in the grid has two slots corresponding to the row and column letter pair
- Name a celebrity whose first and last initials match the letters for that cell (e.g., **B**rad **P**itt for a B-row, P-column)
- Fill both slots in every cell to complete the board
- Use **skips** (2 per game) to bypass tough cells or **reroll** a letter (1 per game, practice mode only)
- Close on the spelling? You'll get a hint about which name is off. Fix it yourself, or tap **Autocorrect** to take the suggested name for a +10s time penalty
- Answers are checked against Wikipedia, so nicknames and other names an article goes by count too (e.g., **K**ate **M**iddleton)

### Game Modes

- **Daily Puzzle** — A new 4x4 grid every day, the same for everyone. Track your streak and compete on time.
- **Practice** — Play on 3x3, 4x4, or 5x5 grids with randomized boards.

## Tech Stack

- **Flutter / Dart** — Cross-platform UI
- **SharedPreferences** — Local persistence for stats and streaks
- **Wikipedia API** — Celebrity name validation
- **GitHub Actions** — Automated deployment to GitHub Pages

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.5.4+

### Setup

```bash
cd client
flutter pub get
```

### Run

```bash
flutter run -d chrome    # Web
flutter run -d macos     # macOS
flutter run              # Default device/emulator
```

### Test

```bash
cd client
flutter test
```

GitHub Actions runs `flutter analyze`, `flutter test` and the DB builder tests on every branch push (so results show on pull requests) and before each deploy.

### Build for Web

```bash
cd client
flutter build web --release --base-href /NameDrop/
```

## Project Structure

```
NameDrop/
├── client/                     # Flutter application
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── theme.dart          # Colors, fonts, component styles
│   │   ├── models/             # Data models (celebrity, game cell, game state)
│   │   ├── services/           # Business logic (validation, board gen, stats)
│   │   ├── screens/            # Full-screen pages (home, game, results)
│   │   └── widgets/            # Reusable UI components
│   ├── assets/
│   │   └── celebrities.json    # Celebrity database (~10k+ entries)
│   └── test/                   # Unit tests
├── scripts/
│   ├── build_celebrity_db.py   # Database builder (ESPN + Pantheon datasets)
│   └── requirements.txt
└── .github/
    └── workflows/
        └── deploy.yml          # CI/CD to GitHub Pages
```

## Celebrity Database

The celebrity database is built from ESPN active athletes and Pantheon notable people using the Python script in `scripts/`. Everyone is ranked by English Wikipedia page views (daily average over the last 60 days) and the 5,000 best known are kept. The list is used for skip reveals, offline answers and board generation; online, anyone with a Wikipedia article counts. To rebuild:

```bash
pip install -r scripts/requirements.txt
python scripts/build_celebrity_db.py
python -m unittest discover scripts   # builder tests
```

The Pantheon dataset downloads automatically. ESPN rosters and page views are cached in `scripts/` for a week, so re-runs are quick. The build report lists empty initial pairs and which letters the board generator will treat as hard.
