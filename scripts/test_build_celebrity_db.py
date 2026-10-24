"""Tests for the DB builder's page view lookups and ranking.

Run from the repo root:  python -m unittest discover scripts
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_celebrity_db as b  # noqa: E402


class FakeResponse:
    def __init__(self, data):
        self._data = data

    def raise_for_status(self):
        pass

    def json(self):
        return self._data


class FakeWikipedia:
    """Answers prop=pageviews queries like the real API (formatversion=2)."""

    def __init__(self, pages, redirects=None, disambiguations=(), split_views=False):
        # pages: {title: (page id, {date: views})}
        self.pages = pages
        self.redirects = redirects or {}
        self.disambiguations = set(disambiguations)
        self.split_views = split_views
        self.requests = []

    def get(self, url, params, headers, timeout):
        self.requests.append(params)
        by_id = {pid: title for title, (pid, _) in self.pages.items()}
        query = {"pages": [], "normalized": [], "redirects": []}
        if "pageids" in params:
            titles = [by_id.get(int(p), f"#{p}") for p in params["pageids"].split("|")]
        else:
            titles = []
            for t in params["titles"].split("|"):
                normal = t[0].upper() + t[1:]
                if normal != t:
                    query["normalized"].append({"from": t, "to": normal})
                if normal in self.redirects:
                    query["redirects"].append({"from": normal, "to": self.redirects[normal]})
                    normal = self.redirects[normal]
                titles.append(normal)

        # Optionally return each page's views in two halves, via continuation.
        second_half = params.get("pvipcontinue") == "more"
        for title in titles:
            if title not in self.pages:
                query["pages"].append({"ns": 0, "title": title, "missing": True})
                continue
            pid, views = self.pages[title]
            days = sorted(views)
            if self.split_views:
                half = len(days) // 2
                days = days[half:] if second_half else days[:half]
            page = {"pageid": pid, "ns": 0, "title": title,
                    "pageviews": {d: views[d] for d in days}}
            if title in self.disambiguations:
                page["pageprops"] = {"disambiguation": ""}
            query["pages"].append(page)

        data = {"batchcomplete": True, "query": query}
        if self.split_views and not second_half:
            data["continue"] = {"pvipcontinue": "more", "continue": "||"}
        return FakeResponse(data)


def views(*daily):
    return {f"2026-09-{i + 1:02d}": v for i, v in enumerate(daily)}


class BuilderTest(unittest.TestCase):
    def setUp(self):
        self._sleep = b.time.sleep
        b.time.sleep = lambda _: None
        self._cache = b.PAGEVIEWS_CACHE_PATH
        self.tmp = tempfile.TemporaryDirectory()
        b.PAGEVIEWS_CACHE_PATH = os.path.join(self.tmp.name, "pageviews_cache.json")

    def tearDown(self):
        b.time.sleep = self._sleep
        b.PAGEVIEWS_CACHE_PATH = self._cache
        self.tmp.cleanup()

    def test_process_name_keeps_titles_that_are_the_name(self):
        self.assertEqual(b.process_name("Queen of Sheba"), ("Queen of Sheba", "Q", "S"))
        self.assertEqual(b.process_name("Saint Francis of Assisi"), ("Francis of Assisi", "F", "A"))
        self.assertIsNone(b.process_name("Pope Francis"))

    def test_views_by_page_id_averages_days_with_data(self):
        wiki = FakeWikipedia({"Tom Hanks": (1, views(100, None, 300))})
        self.assertEqual(b.views_by_page_id(wiki, [1]), {1: 200})

    def test_views_by_page_id_batches_requests(self):
        pages = {f"Person {i}": (i, views(i)) for i in range(1, 121)}
        wiki = FakeWikipedia(pages)
        result = b.views_by_page_id(wiki, list(range(1, 121)))
        self.assertEqual(len(wiki.requests), 3)
        self.assertEqual(result[120], 120)

    def test_follows_continuation(self):
        wiki = FakeWikipedia({"Tom Hanks": (1, views(100, 200, 300, 400))}, split_views=True)
        self.assertEqual(b.views_by_page_id(wiki, [1]), {1: 250})
        self.assertEqual(len(wiki.requests), 2)

    def test_views_by_title_follows_redirects_and_skips_disambiguations(self):
        wiki = FakeWikipedia(
            {"Odell Beckham Jr.": (5, views(900)), "Josh Allen": (6, views(50))},
            redirects={"Odell Beckham": "Odell Beckham Jr."},
            disambiguations={"Josh Allen"},
        )
        found = b.views_by_title(wiki, ["odell Beckham", "Josh Allen", "Nobody Here"])
        self.assertEqual(found, {"odell Beckham": (5, 900)})

    def test_add_page_views_retries_athletes_with_sport_qualifier(self):
        wiki = FakeWikipedia(
            {
                "Josh Allen": (6, views(50)),
                "Josh Allen (American football)": (7, views(4000)),
                "Tom Hanks": (1, views(9000)),
            },
            disambiguations={"Josh Allen"},
        )
        entries = [
            {"name": "Tom Hanks", "pageId": 1, "source": "pantheon"},
            {"name": "Josh Allen", "occupation": "NFL Player", "source": "espn"},
            {"name": "Ann Nobody", "occupation": "NBA Player", "source": "espn"},
        ]
        b.add_page_views(entries, wiki)
        self.assertEqual([(e["pageId"], e["views"]) for e in entries],
                         [(1, 9000), (7, 4000), (None, 0.0)])

        # A second run uses the cache instead of asking again.
        requests = len(wiki.requests)
        b.add_page_views([dict(e, pageId=None if e["source"] == "espn" else e["pageId"])
                          for e in entries], wiki)
        self.assertEqual(len(wiki.requests), requests)

    def test_rank_keeps_best_known_per_name_and_page(self):
        def entry(name, views, source, page_id=None):
            first, last = name.split()[0][0], name.split()[-1][0]
            return {"name": name, "firstInitial": first, "lastInitial": last,
                    "occupation": "X", "views": views, "pageId": page_id, "source": source}

        candidates = [
            entry("Michael Jordan", 20000, "pantheon", page_id=20455),
            entry("Michael Jordan", 20000, "espn", page_id=20455),  # same page
            entry("Josh Allen", 4000, "espn", page_id=7),
            entry("Josh Allen", 300, "pantheon", page_id=8),  # same name, less known
            entry("Backup Lineman", 0, "espn"),
            entry("Somewhat Known", 100, "pantheon", page_id=9),
        ]
        stats = {}
        result = b.rank_and_deduplicate(candidates, max_entries=2, stats=stats)
        self.assertEqual([(c["name"], c["views"]) for c in result],
                         [("Michael Jordan", 20000), ("Josh Allen", 4000)])
        self.assertEqual(stats["pantheon"], 1)
        self.assertEqual(stats["espn"], 1)
        self.assertEqual(stats["skipped_dup"], 1)

    def test_hard_letters_matches_the_game_rule(self):
        # Each person here counts for both initials. Most letters start 20
        # names; Z starts 4 (20% of the median, hard), Y 8 (40%, not hard).
        names = {l: 10 for l in "ABCDEFGHIJKLMNOPQRSTUVW"} | {"Y": 4, "Z": 2}
        celebrities = [
            {"firstInitial": l, "lastInitial": l}
            for l, n in names.items() for _ in range(n)
        ]
        self.assertEqual(b.hard_letters(celebrities), ["Z"])


if __name__ == "__main__":
    unittest.main()
