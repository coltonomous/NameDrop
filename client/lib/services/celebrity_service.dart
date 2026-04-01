import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/celebrity.dart';

class CelebrityService {
  final List<Celebrity> _celebrities = [];
  final Map<String, List<Celebrity>> _index = {};

  bool get isLoaded => _celebrities.isNotEmpty;

  Future<void> init() async {
    if (isLoaded) return;

    final jsonString = await rootBundle.loadString('assets/celebrities.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);

    for (final json in jsonList) {
      final celebrity = Celebrity.fromJson(json as Map<String, dynamic>);
      _celebrities.add(celebrity);
      _index.putIfAbsent(celebrity.pairKey, () => []).add(celebrity);
    }
  }

  List<Celebrity> getByInitials(String firstInitial, String lastInitial) {
    return _index['$firstInitial$lastInitial'] ?? [];
  }

  bool hasCelebrities(String firstInitial, String lastInitial) {
    return getByInitials(firstInitial, lastInitial).isNotEmpty;
  }

  List<Celebrity> search(
    String query,
    String firstInitial,
    String lastInitial, {
    int limit = 10,
  }) {
    final candidates = getByInitials(firstInitial, lastInitial);
    if (query.isEmpty) return candidates.take(limit).toList();
    final lowerQuery = query.toLowerCase();
    return candidates
        .where((c) => c.name.toLowerCase().contains(lowerQuery))
        .take(limit)
        .toList();
  }

  Celebrity? validate(String name, String firstInitial, String lastInitial) {
    final candidates = getByInitials(firstInitial, lastInitial);
    final normalized = _normalize(name);
    if (normalized.isEmpty) return null;

    // Exact match on normalized form.
    for (final c in candidates) {
      if (_normalize(c.name) == normalized) return c;
    }

    // Fuzzy match: pick the best candidate under a reasonable edit distance.
    Celebrity? best;
    int bestDistance = 999;
    final maxAllowed = (normalized.length / 4).ceil().clamp(1, 3);

    for (final c in candidates) {
      final d = _editDistance(_normalize(c.name), normalized);
      if (d < bestDistance && d <= maxAllowed) {
        bestDistance = d;
        best = c;
      }
    }

    return best;
  }

  /// Strip diacritics, punctuation, and collapse whitespace for comparison.
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Levenshtein edit distance.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two-row optimization to avoid allocating a full matrix.
    var prev = List.generate(b.length + 1, (i) => i);
    var curr = List.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,      // deletion
          curr[j - 1] + 1,  // insertion
          prev[j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  Set<String> get availablePairs => _index.keys.toSet();
}
