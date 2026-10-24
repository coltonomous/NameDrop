import 'dart:math';

import 'package:diacritic/diacritic.dart';

import '../models/celebrity.dart';

enum NameMatchKind { match, close, none }

/// How a typed name compares to a known person's name.
class NameMatch {
  final NameMatchKind kind;

  /// Edits needed to fix the first / last name (only set for [close]).
  final int firstDistance;
  final int lastDistance;

  const NameMatch._(this.kind, this.firstDistance, this.lastDistance);

  static const match = NameMatch._(NameMatchKind.match, 0, 0);
  static const none = NameMatch._(NameMatchKind.none, 0, 0);

  const NameMatch.close(this.firstDistance, this.lastDistance)
      : kind = NameMatchKind.close;

  bool get isMatch => kind == NameMatchKind.match;
  bool get isClose => kind == NameMatchKind.close;
  bool get isNone => kind == NameMatchKind.none;
  int get distance => firstDistance + lastDistance;
}

/// A person paired with how well the player's input matched their name.
class PersonMatch {
  final Celebrity celebrity;
  final NameMatch match;

  const PersonMatch(this.celebrity, this.match);
}

class NameMatcher {
  static const _suffixes = {'jr', 'sr', 'ii', 'iii', 'iv', 'v'};

  /// Normalized name tokens. Drops diacritics, case, punctuation, Wikipedia
  /// disambiguators ("Chris Evans (actor)"), anything after a comma
  /// ("Catherine, Princess of Wales") and generational suffixes.
  static List<String> tokens(String name) {
    var s = name.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final comma = s.indexOf(',');
    if (comma >= 0) s = s.substring(0, comma);
    final parts = removeDiacritics(s)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    while (parts.length > 2 && _suffixes.contains(parts.last)) {
      parts.removeLast();
    }
    return parts;
  }

  /// Compare what the player typed against a known name.
  ///
  /// A [NameMatch.match] ignores case, accents, punctuation, suffixes and
  /// middle names ("John Kennedy" names John F. Kennedy). A [NameMatch.close]
  /// is a near miss: first and last names are each within a few typos.
  static NameMatch compare(String input, String candidate) {
    final a = tokens(input);
    final b = tokens(candidate);
    if (a.isEmpty || b.isEmpty) return NameMatch.none;

    // Spacing differences: "JK Rowling" vs "J. K. Rowling".
    if (a.join() == b.join()) return NameMatch.match;
    if (a.length < 2 || b.length < 2) return NameMatch.none;
    if (a.first == b.first && a.last == b.last) return NameMatch.match;

    final firstDistance = distance(a.first, b.first);
    final lastDistance = distance(a.last, b.last);
    if (firstDistance <= typoBudget(b.first) &&
        lastDistance <= typoBudget(b.last)) {
      return NameMatch.close(firstDistance, lastDistance);
    }
    return NameMatch.none;
  }

  /// How many typos a name part tolerates before it stops being a near miss.
  static int typoBudget(String token) {
    if (token.length <= 2) return 0;
    if (token.length <= 5) return 1;
    if (token.length <= 9) return 2;
    return 3;
  }

  /// Damerau-Levenshtein distance (optimal string alignment), so a swapped
  /// pair of letters counts as one typo.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var prevPrev = List<int>.filled(b.length + 1, 0);
    var prev = List<int>.generate(b.length + 1, (j) => j);
    var curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var d = min(min(prev[j] + 1, curr[j - 1] + 1), prev[j - 1] + cost);
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          d = min(d, prevPrev[j - 2] + 1);
        }
        curr[j] = d;
      }
      final recycled = prevPrev;
      prevPrev = prev;
      prev = curr;
      curr = recycled;
    }
    return prev[b.length];
  }

  /// Whether [name]'s first and last names start with the given initials.
  static bool hasInitials(
      String name, String firstInitial, String lastInitial) {
    final t = tokens(name);
    if (t.length < 2) return false;
    return t.first[0] == firstInitial.toLowerCase() &&
        t.last[0] == lastInitial.toLowerCase();
  }

  /// Player-facing nudge for a near miss. Says where the typo is without
  /// giving the answer away.
  static String nearMissHint(NameMatch m) {
    String letters(int n) => n == 1 ? '1 letter' : '$n letters';
    if (m.firstDistance > 0 && m.lastDistance > 0) {
      return 'So close! Both names are a little off.';
    }
    if (m.firstDistance > 0) {
      return 'So close! First name is ${letters(m.firstDistance)} off.';
    }
    return 'So close! Last name is ${letters(m.lastDistance)} off.';
  }
}
