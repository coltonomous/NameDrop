import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the Wikipedia and Wikidata APIs, returning
/// `formatversion=2` shaped responses for the queries the resolver makes.
class FakeWikimedia {
  /// Article title -> description, Wikidata id, and instance-of (P31).
  final Map<String, ({String description, String qid, String p31})> articles =
      {};
  final Set<String> disambiguations = {};

  /// Redirect title -> target title (and optional section).
  final Map<String, ({String to, String? fragment})> redirects = {};

  /// Search query -> result titles.
  final Map<String, List<String>> search = {};
  final Map<String, List<String>> prefixSearch = {};

  bool wikidataDown = false;
  bool searchDown = false;
  bool offline = false;
  final List<Uri> requests = [];

  void addPerson(String title, String description, String qid) =>
      articles[title] = (description: description, qid: qid, p31: 'Q5');

  late final http.Client client = MockClient((request) async {
    requests.add(request.url);
    if (offline) throw http.ClientException('offline');

    final params = request.url.queryParameters;
    if (request.url.host == 'www.wikidata.org') {
      if (wikidataDown) return http.Response('Service Unavailable', 503);
      final entity = params['entity'];
      final article = articles.values.where((a) => a.qid == entity).firstOrNull;
      if (article == null) {
        return _json({
          'error': {'code': 'no-such-entity'}
        });
      }
      return _json({
        'claims': {
          'P31': [
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'entity-type': 'item', 'id': article.p31},
                  'type': 'wikibase-entityid',
                },
              },
            },
          ],
        },
      });
    }

    if (params.containsKey('titles')) return _json(_pages(params['titles']!));
    if (params.containsKey('list')) {
      if (searchDown) return http.Response('Service Unavailable', 503);
      return _json({
        'batchcomplete': true,
        'query': {
          'search': [
            for (final t in search[params['srsearch']] ?? const <String>[])
              {'ns': 0, 'title': t},
          ],
          'prefixsearch': [
            for (final t
                in prefixSearch[params['pssearch']] ?? const <String>[])
              {'ns': 0, 'title': t},
          ],
        },
      });
    }
    return http.Response('bad request', 400);
  });

  Map<String, dynamic> _pages(String titles) {
    final normalized = <Map<String, dynamic>>[];
    final redirectList = <Map<String, dynamic>>[];
    final pages = <String, Map<String, dynamic>>{};

    for (final requested in titles.split('|')) {
      // MediaWiki capitalizes the first letter; the rest is case-sensitive.
      var title = requested[0].toUpperCase() + requested.substring(1);
      if (title != requested) {
        normalized.add({'fromencoded': false, 'from': requested, 'to': title});
      }
      final redirect = redirects[title];
      if (redirect != null) {
        redirectList.add({
          'from': title,
          'to': redirect.to,
          if (redirect.fragment != null) 'tofragment': redirect.fragment,
        });
        title = redirect.to;
      }
      final article = articles[title];
      pages[title] = article == null && !disambiguations.contains(title)
          ? {'ns': 0, 'title': title, 'missing': true}
          : {
              'pageid': title.hashCode.abs(),
              'ns': 0,
              'title': title,
              'pageprops': {
                if (disambiguations.contains(title)) 'disambiguation': '',
                if (article != null) 'wikibase_item': article.qid,
              },
              if (article != null) 'description': article.description,
              'fullurl':
                  'https://en.wikipedia.org/wiki/${title.replaceAll(' ', '_')}',
            };
    }

    return {
      'batchcomplete': true,
      'query': {
        if (normalized.isNotEmpty) 'normalized': normalized,
        if (redirectList.isNotEmpty) 'redirects': redirectList,
        'pages': pages.values.toList(),
      },
    };
  }

  static http.Response _json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
