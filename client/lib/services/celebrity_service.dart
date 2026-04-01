import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

  /// Validate a name: try Wikipedia first (for wiki link), then local DB.
  Future<Celebrity?> validate(
      String name, String firstInitial, String lastInitial) async {
    if (name.trim().isEmpty) return null;

    // Try Wikipedia first so we always get a wiki link when online.
    final wiki = await _validateWikipedia(name, firstInitial, lastInitial);
    if (wiki != null) return wiki;

    // Fall back to local DB, with an optimistic wiki URL.
    final local = _validateLocal(name, firstInitial, lastInitial);
    if (local != null) {
      final slug = _buildSlug(local.name);
      return Celebrity(
        name: local.name,
        firstInitial: local.firstInitial,
        lastInitial: local.lastInitial,
        occupation: local.occupation,
        birthYear: local.birthYear,
        hpi: local.hpi,
        wikiUrl: 'https://en.wikipedia.org/wiki/$slug',
      );
    }
    return null;
  }

  /// Normalized exact match: lowercase, strip diacritics and punctuation.
  Celebrity? _validateLocal(
      String name, String firstInitial, String lastInitial) {
    final candidates = getByInitials(firstInitial, lastInitial);
    if (candidates.isEmpty) return null;

    final normalized = _normalize(name.trim());
    for (final c in candidates) {
      if (_normalize(c.name) == normalized) return c;
    }
    return null;
  }

  /// Strip diacritics, punctuation, and collapse whitespace.
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
        .replaceAll(RegExp(r"[^a-z\s]"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Sanitize input and build a Wikipedia-friendly slug.
  static String _sanitize(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[.,;:!?\'"""''`#@&*()[\]{}|\\/<>~^]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Build a Wikipedia URL slug. Capitalize first letter of each word,
  /// leave the rest as-is (preserves McDonald, DeVito, etc.).
  static String _buildSlug(String name) {
    return name.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join('_');
  }

  /// Check Wikipedia: verify the page exists and is about a person.
  Future<Celebrity?> _validateWikipedia(
      String name, String firstInitial, String lastInitial) async {
    final sanitized = _sanitize(name);

    // Verify initials match before hitting the network.
    final parts = sanitized.split(' ');
    if (parts.length < 2) return null;
    if (parts.first[0].toUpperCase() != firstInitial ||
        parts.last[0].toUpperCase() != lastInitial) {
      return null;
    }

    final slug = _buildSlug(sanitized);
    final url = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/$slug');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description =
            (data['description'] as String? ?? '').toLowerCase();
        final extract = (data['extract'] as String? ?? '').toLowerCase();
        final title = data['title'] as String? ?? sanitized;
        final pageUrl =
            data['content_urls']?['desktop']?['page'] as String?;

        if (!_isPerson(description, extract)) return null;

        return Celebrity(
          name: title,
          firstInitial: firstInitial,
          lastInitial: lastInitial,
          occupation: _formatDescription(
              data['description'] as String? ?? ''),
          hpi: 0,
          wikiUrl: pageUrl,
        );
      }
    } catch (_) {
      // Network error or timeout — offline, fall through to local.
    }

    return null;
  }

  static bool _isPerson(String description, String extract) {
    const personIndicators = [
      'born', 'died', 'was a', 'is a', 'are a',
      'actor', 'actress', 'singer', 'musician', 'player', 'coach',
      'politician', 'president', 'writer', 'author', 'director',
      'artist', 'athlete', 'scientist', 'engineer', 'comedian',
      'rapper', 'model', 'activist', 'journalist', 'businessman',
      'businesswoman', 'entrepreneur', 'composer', 'producer',
      'filmmaker', 'photographer', 'designer', 'chef', 'host',
      'personality', 'influencer', 'youtuber', 'streamer',
      'quarterback', 'pitcher', 'goalkeeper', 'midfielder',
      'wrestler', 'boxer', 'fighter', 'swimmer', 'gymnast',
      'skater', 'golfer', 'racer', 'driver', 'cyclist',
      'astronaut', 'philosopher', 'historian', 'painter',
      'sculptor', 'dancer', 'choreographer', 'magician',
      'american', 'british', 'canadian', 'australian', 'french',
      'german', 'italian', 'spanish', 'japanese', 'brazilian',
    ];

    final combined = '$description $extract';
    return personIndicators.any((indicator) => combined.contains(indicator));
  }

  static String _formatDescription(String desc) {
    if (desc.isEmpty) return 'Notable Person';
    return desc
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  Set<String> get availablePairs => _index.keys.toSet();
}
