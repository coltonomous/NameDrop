import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/celebrity.dart';
import 'name_matcher.dart';

/// A Wikipedia page that might be the person the player meant.
class _Candidate {
  final String displayName;
  final String? description;
  final String? wikidataId;
  final String url;
  final NameMatch match;

  const _Candidate({
    required this.displayName,
    required this.description,
    required this.wikidataId,
    required this.url,
    required this.match,
  });
}

/// Resolves a typed name to a person on Wikipedia.
///
/// Typed names often aren't article titles: wrong capitalization
/// ("Leonardo Dicaprio"), missing middle names ("John Kennedy"), ambiguous
/// names ("Chris Evans"), or a name the article lives under a different
/// title for ("Kate Middleton"). This looks the name up directly (following
/// redirects), falls back to Wikipedia search, and confirms the page is
/// about a real human via Wikidata (instance of Q5).
class WikipediaResolver {
  WikipediaResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, bool> _humanCache = {};

  static final _wikipediaApi = Uri.https('en.wikipedia.org', '/w/api.php');
  static final _wikidataApi = Uri.https('www.wikidata.org', '/w/api.php');
  static const _requestTimeout = Duration(seconds: 4);
  static const _maxSearchCandidates = 8;
  static const _maxHumanChecks = 4;

  // Browsers won't let us set User-Agent; elsewhere Wikimedia asks for one.
  static const Map<String, String> _headers = kIsWeb
      ? {}
      : {
          'User-Agent': 'NameDrop/1.0 (https://github.com/coltonomous/NameDrop)'
        };

  /// Find the person [input] refers to. Returns a [NameMatchKind.match] when
  /// the name is right, a [NameMatchKind.close] near miss when it looks like a
  /// misspelling (only if [allowClose]), or null when nothing fits.
  Future<PersonMatch?> resolve(
    String input,
    String firstInitial,
    String lastInitial, {
    bool allowClose = true,
  }) async {
    final query = searchQuery(input);
    if (query.isEmpty) return null;
    final variants = titleVariants(query);

    final results = await Future.wait([
      _queryPages(variants),
      _get(_wikipediaApi, {
        'action': 'query',
        'list': 'search|prefixsearch',
        'srsearch': query,
        'srlimit': '10',
        'srprop': '',
        'srinfo': 'suggestion',
        'srenablerewrites': '1',
        'pssearch': query,
        'pslimit': '10',
      }),
    ]);

    final direct =
        _candidates(results[0], variants, input, firstInitial, lastInitial);
    final directMatch = await _firstHuman(direct.where((c) => c.match.isMatch));
    if (directMatch != null) {
      return _toPersonMatch(directMatch, firstInitial, lastInitial);
    }

    // Shortlist search hits whose titles look like the typed name.
    final lists = results[1]?['query'] as Map<String, dynamic>? ?? const {};
    final searchTitles = <String>{
      for (final hit in [
        ...(lists['search'] as List? ?? const []),
        ...(lists['prefixsearch'] as List? ?? const []),
      ])
        if (hit is Map && hit['title'] is String) hit['title'] as String,
      if (lists['searchinfo']?['suggestion'] is String)
        titleCase(lists['searchinfo']['suggestion'] as String),
    }
        .where((t) => !variants.contains(t))
        .where((t) => !NameMatcher.compare(input, t).isNone)
        .take(_maxSearchCandidates)
        .toList();

    var searched = const <_Candidate>[];
    if (searchTitles.isNotEmpty) {
      searched = _candidates(await _queryPages(searchTitles), searchTitles,
          input, firstInitial, lastInitial);
      final searchMatch =
          await _firstHuman(searched.where((c) => c.match.isMatch));
      if (searchMatch != null) {
        return _toPersonMatch(searchMatch, firstInitial, lastInitial);
      }
    }

    if (!allowClose) return null;
    final seenUrls = <String>{};
    final close = [...direct, ...searched]
        .where((c) => c.match.isClose && seenUrls.add(c.url))
        .toList()
      ..sort((a, b) => a.match.distance.compareTo(b.match.distance));
    final nearMiss = await _firstHuman(close);
    return nearMiss == null
        ? null
        : _toPersonMatch(nearMiss, firstInitial, lastInitial);
  }

  PersonMatch _toPersonMatch(
      _Candidate c, String firstInitial, String lastInitial) {
    return PersonMatch(
      Celebrity(
        name: c.displayName,
        firstInitial: firstInitial,
        lastInitial: lastInitial,
        occupation: formatDescription(c.description ?? ''),
        hpi: 0,
        wikiUrl: c.url,
      ),
      c.match,
    );
  }

  /// Look up [titles], following redirects, with what we need to judge them.
  Future<Map<String, dynamic>?> _queryPages(List<String> titles) {
    return _get(_wikipediaApi, {
      'action': 'query',
      'titles': titles.join('|'),
      'redirects': '1',
      'prop': 'pageprops|description|info',
      'ppprop': 'disambiguation|wikibase_item',
      'inprop': 'url',
    });
  }

  /// Turn a page lookup response into candidates, in the order of [requested].
  List<_Candidate> _candidates(
    Map<String, dynamic>? data,
    List<String> requested,
    String input,
    String firstInitial,
    String lastInitial,
  ) {
    final query = data?['query'] as Map<String, dynamic>?;
    if (query == null) return const [];

    final normalized = <String, String>{
      for (final n in query['normalized'] as List? ?? const [])
        n['from'] as String: n['to'] as String,
    };
    final redirects = <String, Map<String, dynamic>>{
      for (final r in query['redirects'] as List? ?? const [])
        r['from'] as String: r as Map<String, dynamic>,
    };
    final pages = <String, Map<String, dynamic>>{
      for (final p in query['pages'] as List? ?? const [])
        p['title'] as String: p as Map<String, dynamic>,
    };

    final seen = <String>{};
    final candidates = <_Candidate>[];
    for (final requestedTitle in requested) {
      var title = normalized[requestedTitle] ?? requestedTitle;
      final redirect = redirects[title];
      final redirectFrom = redirect != null ? title : null;
      if (redirect != null) title = redirect['to'] as String;

      final page = pages[title];
      if (page == null ||
          page['missing'] == true ||
          page['invalid'] == true ||
          page['ns'] != 0) {
        continue;
      }
      final props = page['pageprops'] as Map<String, dynamic>? ?? const {};
      if (props.containsKey('disambiguation')) continue;
      if (!seen.add(title)) continue;

      var match = NameMatcher.compare(input, title);
      var displayName = stripDisambiguator(title);

      // A redirect from a different name for the same person ("Kate
      // Middleton", "Cassius Clay") counts under the name the player used.
      // Redirects into a section ("Kylie Cosmetics" -> "Kylie Jenner#...")
      // are about something the person did, not the person.
      if (match.isNone &&
          redirectFrom != null &&
          redirect!['tofragment'] == null &&
          NameMatcher.compare(input, redirectFrom).isMatch) {
        match = NameMatch.match;
        displayName = stripDisambiguator(redirectFrom);
      }

      if (match.isNone) continue;
      if (match.isClose &&
          !NameMatcher.hasInitials(displayName, firstInitial, lastInitial)) {
        continue;
      }

      candidates.add(_Candidate(
        displayName: displayName,
        description: page['description'] as String?,
        wikidataId: props['wikibase_item'] as String?,
        url: page['fullurl'] as String? ??
            'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
        match: match,
      ));
    }
    return candidates;
  }

  /// The first candidate (in priority order) that is a real human.
  Future<_Candidate?> _firstHuman(Iterable<_Candidate> candidates) async {
    final top = candidates.take(_maxHumanChecks).toList();
    if (top.isEmpty) return null;
    final verdicts = await Future.wait(top.map(_isHuman));
    for (var i = 0; i < top.length; i++) {
      if (verdicts[i]) return top[i];
    }
    return null;
  }

  /// Ask Wikidata whether the page is about a human (P31 = Q5). This rejects
  /// places, bands, fictional characters and the like. If Wikidata can't be
  /// reached, fall back to a keyword check on the page description.
  Future<bool> _isHuman(_Candidate c) async {
    final id = c.wikidataId;
    if (id == null) return isPerson(c.description?.toLowerCase() ?? '', '');
    final cached = _humanCache[id];
    if (cached != null) return cached;

    final data = await _get(_wikidataApi, {
      'action': 'wbgetclaims',
      'entity': id,
      'property': 'P31',
    });
    final claims = data?['claims'] as Map<String, dynamic>?;
    if (claims == null) {
      return isPerson(c.description?.toLowerCase() ?? '', '');
    }
    final human = (claims['P31'] as List? ?? const []).any((claim) =>
        claim is Map &&
        claim['mainsnak']?['datavalue']?['value']?['id'] == 'Q5');
    _humanCache[id] = human;
    return human;
  }

  Future<Map<String, dynamic>?> _get(
      Uri endpoint, Map<String, String> params) async {
    final uri = endpoint.replace(queryParameters: {
      ...params,
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
    });
    try {
      final response =
          await _client.get(uri, headers: _headers).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body.containsKey('error')) {
        return null;
      }
      return body;
    } catch (e) {
      debugPrint('Wikimedia request failed (${endpoint.host}): $e');
      return null;
    }
  }

  /// Clean up typed input for Wikipedia without losing characters that
  /// matter in titles (apostrophes, periods, hyphens). Phone keyboards
  /// often insert curly apostrophes, which no article title uses.
  @visibleForTesting
  static String searchQuery(String input) {
    return input
        .replaceAll(RegExp('[‘’ʼ`]'), "'")
        .replaceAll(RegExp('["“”]'), '')
        .replaceAll(RegExp(r'[#<>\[\]|{}_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Titles to try directly. Wikipedia titles are case-sensitive after the
  /// first letter, so try the input as typed plus title-cased forms.
  @visibleForTesting
  static List<String> titleVariants(String query) {
    return {query, titleCase(query), titleCase(query.toLowerCase())}.toList();
  }

  /// Capitalize the first letter of each word, including after hyphens.
  @visibleForTesting
  static String titleCase(String s) {
    return s.replaceAllMapped(RegExp(r"(^|[\s-])(\p{L})", unicode: true),
        (m) => '${m[1]}${m[2]!.toUpperCase()}');
  }

  /// "Chris Evans (actor)" -> "Chris Evans".
  @visibleForTesting
  static String stripDisambiguator(String title) {
    return title.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  /// Keyword fallback for when Wikidata can't tell us. Only used if the page
  /// has no Wikidata item or Wikidata is unreachable.
  @visibleForTesting
  static bool isPerson(String description, String extract) {
    const rejectionKeywords = [
      'fictional',
      'character',
      'video game',
      'anime',
      'manga',
      'cartoon',
      'comic book',
      'superhero',
      'supervillain',
      'mythological',
      'mythology',
      'legendary creature',
      'mascot',
      'puppet',
      'muppet',
    ];

    // Check description (short summary) for fictional/non-person markers.
    if (rejectionKeywords.any((kw) => description.contains(kw))) {
      return false;
    }

    // Biography short descriptions usually carry dates: "(born 1974)",
    // "(1917–1963)".
    if (RegExp(r'\((born |died |c\. )?\d{3,4}').hasMatch(description)) {
      return true;
    }

    const personIndicators = [
      'born',
      'died',
      'actor',
      'actress',
      'singer',
      'musician',
      'player',
      'coach',
      'politician',
      'president',
      'writer',
      'author',
      'director',
      'artist',
      'athlete',
      'scientist',
      'engineer',
      'comedian',
      'rapper',
      'model',
      'activist',
      'journalist',
      'businessman',
      'businesswoman',
      'entrepreneur',
      'composer',
      'producer',
      'filmmaker',
      'photographer',
      'designer',
      'chef',
      'host',
      'personality',
      'influencer',
      'youtuber',
      'streamer',
      'quarterback',
      'pitcher',
      'goalkeeper',
      'midfielder',
      'footballer',
      'cricketer',
      'wrestler',
      'boxer',
      'fighter',
      'swimmer',
      'gymnast',
      'skater',
      'golfer',
      'racer',
      'driver',
      'cyclist',
      'astronaut',
      'philosopher',
      'historian',
      'painter',
      'sculptor',
      'dancer',
      'choreographer',
      'magician',
      'researcher',
      'professor',
      'inventor',
      'nobel',
      'laureate',
      'physician',
      'surgeon',
      'general',
      'admiral',
      'olympian',
      'chancellor',
      'governor',
      'senator',
      'minister',
      'monarch',
      'emperor',
      'king',
      'queen',
      'prince',
      'princess',
      'explorer',
      'missionary',
      'theologian',
      'mathematician',
      'biologist',
      'chemist',
      'physicist',
      'economist',
      'psychologist',
      'sociologist',
      'architect',
      'pilot',
    ];

    final combined = '$description $extract';
    return personIndicators.any((indicator) => combined.contains(indicator));
  }

  @visibleForTesting
  static String formatDescription(String desc) {
    if (desc.isEmpty) return 'Notable Person';
    return desc
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }
}
