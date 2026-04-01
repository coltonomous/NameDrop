import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

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
    if (candidates.isEmpty || name.trim().isEmpty) return null;

    final names = candidates.map((c) => c.name).toList();
    final result = extractOne(
      query: name.trim(),
      choices: names,
      cutoff: 75,
    );

    if (result.score >= 75) {
      return candidates[result.index];
    }
    return null;
  }

  Set<String> get availablePairs => _index.keys.toSet();
}
