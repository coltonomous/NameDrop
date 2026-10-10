import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/services/wikipedia_resolver.dart';

import 'fake_wikimedia.dart';

void main() {
  late FakeWikimedia wiki;
  late WikipediaResolver resolver;

  setUp(() {
    wiki = FakeWikimedia()
      ..addPerson('Tom Hanks', 'American actor (born 1956)', 'Q2263')
      ..addPerson('Catherine, Princess of Wales',
          'Member of the British royal family (born 1982)', 'Q10479')
      ..addPerson('Arnold Schwarzenegger',
          'Austrian and American actor and politician (born 1947)', 'Q2685')
      ..addPerson(
          'Chris Evans (actor)', 'American actor (born 1981)', 'Q178348')
      ..addPerson('Leonardo DiCaprio', 'American actor (born 1974)', 'Q38111')
      ..addPerson('John Lennon', 'English musician (1940–1980)', 'Q1203')
      ..addPerson('Kris Jenner', 'American media personality (born 1955)', 'Q1')
      ..addPerson(
          'Kylie Jenner', 'American media personality (born 1997)', 'Q2')
      ..addPerson("Shaquille O'Neal", 'American basketball player (born 1972)',
          'Q169452');
    wiki.articles['Costa Rica'] =
        (description: 'Country in Central America', qid: 'Q800', p31: 'Q6256');
    wiki.articles['Simon & Garfunkel'] =
        (description: 'American folk rock duo', qid: 'Q4500', p31: 'Q9212979');
    wiki.disambiguations.add('Chris Evans');
    wiki.redirects['Kate Middleton'] =
        (to: 'Catherine, Princess of Wales', fragment: null);
    wiki.redirects['Arnold Swarzenegger'] =
        (to: 'Arnold Schwarzenegger', fragment: null);
    wiki.redirects['Simon Garfunkel'] =
        (to: 'Simon & Garfunkel', fragment: null);
    wiki.redirects['Kylie Cosmetics'] =
        (to: 'Kylie Jenner', fragment: 'Business ventures');
    wiki.search['Chris Evans'] = ['Chris Evans', 'Chris Evans (actor)'];
    wiki.search['leonardo dicaprio'] = ['Leonardo DiCaprio'];
    wiki.prefixSearch['Jon Lenon'] = ['John Lennon', 'Jon Lenon Jr Band'];
    wiki.prefixSearch['Cris Jenner'] = ['Kris Jenner'];

    resolver = WikipediaResolver(client: wiki.client);
  });

  group('resolve', () {
    test('finds an article by its exact title', () async {
      final result = await resolver.resolve('Tom Hanks', 'T', 'H');
      expect(result!.match.isMatch, isTrue);
      expect(result.celebrity.name, 'Tom Hanks');
      expect(result.celebrity.occupation, 'American Actor (born 1956)');
      expect(
          result.celebrity.wikiUrl, 'https://en.wikipedia.org/wiki/Tom_Hanks');
    });

    test('accepts another name that redirects to the person', () async {
      final result = await resolver.resolve('Kate Middleton', 'K', 'M');
      expect(result!.match.isMatch, isTrue);
      expect(result.celebrity.name, 'Kate Middleton');
      expect(result.celebrity.wikiUrl,
          'https://en.wikipedia.org/wiki/Catherine,_Princess_of_Wales');
    });

    test('accepts an alias typed in lowercase', () async {
      final result = await resolver.resolve('kate middleton', 'K', 'M');
      expect(result!.celebrity.name, 'Kate Middleton');
    });

    test('keeps apostrophes, including curly ones from phone keyboards',
        () async {
      final result = await resolver.resolve('Shaquille O’Neal', 'S', 'O');
      expect(result!.match.isMatch, isTrue);
      expect(result.celebrity.name, "Shaquille O'Neal");
    });

    test('treats a redirect from a misspelling as a near miss', () async {
      final result = await resolver.resolve('Arnold Swarzenegger', 'A', 'S');
      expect(result!.match.isClose, isTrue);
      expect(result.celebrity.name, 'Arnold Schwarzenegger');

      expect(
          await resolver.resolve('Arnold Swarzenegger', 'A', 'S',
              allowClose: false),
          isNull);
    });

    test('searches past a disambiguation page', () async {
      final result = await resolver.resolve('Chris Evans', 'C', 'E');
      expect(result!.match.isMatch, isTrue);
      expect(result.celebrity.name, 'Chris Evans');
      expect(result.celebrity.wikiUrl,
          'https://en.wikipedia.org/wiki/Chris_Evans_(actor)');
    });

    test('searches when capitalization differs from the title', () async {
      final result = await resolver.resolve('leonardo dicaprio', 'L', 'D');
      expect(result!.match.isMatch, isTrue);
      expect(result.celebrity.name, 'Leonardo DiCaprio');
    });

    test('suggests a near miss from fuzzy search', () async {
      final result = await resolver.resolve('Jon Lenon', 'J', 'L');
      expect(result!.match.isClose, isTrue);
      expect(result.match.distance, 2);
      expect(result.celebrity.name, 'John Lennon');
    });

    test('ignores near misses with the wrong initials', () async {
      expect(await resolver.resolve('Cris Jenner', 'C', 'J'), isNull);
    });

    test('rejects pages that are not about a human', () async {
      expect(await resolver.resolve('Costa Rica', 'C', 'R'), isNull);
      expect(await resolver.resolve('Simon Garfunkel', 'S', 'G'), isNull);
    });

    test('rejects redirects into a section of a person article', () async {
      expect(await resolver.resolve('Kylie Cosmetics', 'K', 'C'), isNull);
    });

    test('falls back to the description when Wikidata is down', () async {
      wiki.wikidataDown = true;
      expect((await resolver.resolve('Tom Hanks', 'T', 'H'))!.match.isMatch,
          isTrue);
      expect(await resolver.resolve('Costa Rica', 'C', 'R'), isNull);
    });

    test('returns null when offline', () async {
      wiki.offline = true;
      expect(await resolver.resolve('Tom Hanks', 'T', 'H'), isNull);
    });
  });

  group('query helpers', () {
    test('searchQuery straightens quotes and strips title-breaking chars', () {
      expect(
          WikipediaResolver.searchQuery('  Conan  O’Brien '), "Conan O'Brien");
      expect(WikipediaResolver.searchQuery('"Tom" Hanks|#'), 'Tom Hanks');
    });

    test('titleVariants tries as typed and title-cased', () {
      expect(WikipediaResolver.titleVariants('lebron james'),
          ['lebron james', 'Lebron James']);
      expect(WikipediaResolver.titleVariants('LEBRON JAMES'),
          ['LEBRON JAMES', 'Lebron James']);
      expect(WikipediaResolver.titleVariants('Tom Hanks'), ['Tom Hanks']);
    });

    test('titleCase capitalizes after spaces and hyphens', () {
      expect(
          WikipediaResolver.titleCase('jean-paul sartre'), 'Jean-Paul Sartre');
      expect(WikipediaResolver.titleCase('émile zola'), 'Émile Zola');
    });

    test('stripDisambiguator removes a trailing parenthetical', () {
      expect(WikipediaResolver.stripDisambiguator('Chris Evans (actor)'),
          'Chris Evans');
      expect(WikipediaResolver.stripDisambiguator('Tom Hanks'), 'Tom Hanks');
    });
  });
}
