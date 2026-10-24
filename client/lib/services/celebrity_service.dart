import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/celebrity.dart';
import 'name_matcher.dart';
import 'wikipedia_resolver.dart';

class ValidationResult {
  final Celebrity? celebrity;
  final String? error;

  /// For a near miss: who we think the player meant, and a nudge that says
  /// where the typo is without naming them.
  final Celebrity? suggestion;
  final String? hint;

  const ValidationResult.success(this.celebrity)
      : error = null,
        suggestion = null,
        hint = null;
  const ValidationResult.failure(this.error)
      : celebrity = null,
        suggestion = null,
        hint = null;
  const ValidationResult.nearMiss(this.suggestion, this.hint)
      : celebrity = null,
        error = null;

  bool get isSuccess => celebrity != null;
  bool get isNearMiss => suggestion != null;
}

class CelebrityService {
  CelebrityService({http.Client? client})
      : _wiki = WikipediaResolver(client: client);

  final WikipediaResolver _wiki;
  final List<Celebrity> _celebrities = [];
  final Map<String, List<Celebrity>> _index = {};
  final Map<String, ValidationResult> _sessionCache = {};

  bool get isLoaded => _celebrities.isNotEmpty;

  List<Celebrity> get celebrities => List.unmodifiable(_celebrities);

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

  /// Validate a name against Wikipedia (for the wiki link) and the local DB.
  /// Exact names (give or take case, accents, punctuation and middle names)
  /// succeed; names a typo or two away come back as a near miss.
  Future<ValidationResult> validate(
      String name, String firstInitial, String lastInitial) async {
    final sanitized = sanitize(name);
    if (sanitized.isEmpty) {
      return const ValidationResult.failure('Enter a first and last name');
    }

    final parts = sanitized.split(' ');
    if (parts.length < 2) {
      return const ValidationResult.failure(
          'Enter a first and last name');
    }

    // Strip trailing suffixes so "Ken Griffey Jr" matches K.G.
    const suffixes = {'jr', 'sr', 'ii', 'iii', 'iv', 'v'};
    while (parts.length > 2 && suffixes.contains(parts.last.toLowerCase())) {
      parts.removeLast();
    }

    // Check initials match before doing any lookups. "Émile" starts with E.
    final inputFirst = removeDiacritics(parts.first[0]).toUpperCase();
    final inputLast = removeDiacritics(parts.last[0]).toUpperCase();

    if (inputFirst != firstInitial && inputLast != lastInitial) {
      return ValidationResult.failure(
          'Initials are $inputFirst.$inputLast. — need $firstInitial.$lastInitial.');
    }
    if (inputFirst != firstInitial) {
      return ValidationResult.failure(
          'First name starts with $inputFirst, need $firstInitial');
    }
    if (inputLast != lastInitial) {
      return ValidationResult.failure(
          'Last name starts with $inputLast, need $lastInitial');
    }

    // Check session cache before any network calls.
    final cacheKey = normalize(sanitized);
    final cached = _sessionCache[cacheKey];
    if (cached != null) return cached;

    final local = _matchLocal(name, firstInitial, lastInitial);
    final localMatch = local != null && local.match.isMatch;

    // Wikipedia first so we get a wiki link when online. No need to hunt
    // for near misses there if the local DB already knows the name.
    final lookup = await _wiki
        .resolve(name, firstInitial, lastInitial, allowClose: !localMatch)
        .timeout(const Duration(seconds: 10),
            onTimeout: () => const WikiLookup.unavailable());
    final wiki = lookup.person;

    ValidationResult? result;
    if (wiki != null && wiki.match.isMatch) {
      result = ValidationResult.success(wiki.celebrity);
    } else if (localMatch) {
      // Offline, or Wikipedia didn't confirm them. Accept without a link
      // rather than guess one; the game looks it up later (findWikiLink).
      result = ValidationResult.success(local.celebrity);
    } else {
      final nearMisses = [
        if (local != null) local,
        if (wiki != null) wiki,
      ];
      if (nearMisses.isNotEmpty) {
        // Fewest typos wins; on a tie prefer the curated local DB.
        final best = nearMisses.reduce(
            (a, b) => b.match.distance < a.match.distance ? b : a);
        result = ValidationResult.nearMiss(
            best.celebrity, NameMatcher.nearMissHint(best.match));
      }
    }

    if (result != null) {
      // Don't remember offline answers; Wikipedia may know better later.
      if (lookup.conclusive) _sessionCache[cacheKey] = result;
      return result;
    }

    if (parts.length > 2) {
      return ValidationResult.failure(
          "We match first and last name only — try '${parts.first} ${parts.last}'");
    }

    return const ValidationResult.failure(
        "We don't know that one — try someone else");
  }

  /// Look up the Wikipedia page for someone who was accepted without one
  /// (an offline answer or a skip reveal). An inconclusive result means
  /// Wikipedia couldn't be reached and it's worth trying again later.
  Future<WikiLookup> findWikiLink(Celebrity celebrity) {
    return _wiki
        .resolve(celebrity.name, celebrity.firstInitial, celebrity.lastInitial,
            allowClose: false)
        .timeout(const Duration(seconds: 10),
            onTimeout: () => const WikiLookup.unavailable());
  }

  /// Best local DB entry for [name]: a match if there is one, otherwise the
  /// closest near miss (most famous first on a tie).
  PersonMatch? _matchLocal(
      String name, String firstInitial, String lastInitial) {
    PersonMatch? best;
    for (final c in getByInitials(firstInitial, lastInitial)) {
      final m = NameMatcher.compare(name, c.name);
      if (m.isNone) continue;
      final rank = m.isMatch ? -1 : m.distance;
      final bestRank = best == null
          ? null
          : (best.match.isMatch ? -1 : best.match.distance);
      if (bestRank == null ||
          rank < bestRank ||
          (rank == bestRank && Celebrity.byFame(c, best!.celebrity) < 0)) {
        best = PersonMatch(c, m);
      }
    }
    return best;
  }

  /// Strip diacritics, punctuation, and collapse whitespace.
  @visibleForTesting
  static String normalize(String s) {
    return removeDiacritics(s)
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z\s]"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Sanitize input and build a Wikipedia-friendly slug.
  @visibleForTesting
  static String sanitize(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[.,;:!?\x27\x22\u2018\u2019\u201C\u201D`#@&*()[\]{}|\\/<>~^]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> get availablePairs => _index.keys.toSet();
}
