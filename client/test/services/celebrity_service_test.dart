import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/services/celebrity_service.dart';
import 'package:namedrop/services/wikipedia_resolver.dart';

import 'fake_wikimedia.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validate', () {
    late FakeWikimedia wiki;
    late CelebrityService service;

    setUp(() async {
      wiki = FakeWikimedia()
        ..addPerson('Catherine, Princess of Wales',
            'Member of the British royal family (born 1982)', 'Q10479');
      wiki.redirects['Kate Middleton'] =
          (to: 'Catherine, Princess of Wales', fragment: null);
      service = CelebrityService(client: wiki.client);
      await service.init();
    });

    test('accepts a known name offline', () async {
      wiki.offline = true;
      final result = await service.validate('Tom Hanks', 'T', 'H');
      expect(result.celebrity?.name, 'Tom Hanks');
      expect(result.celebrity?.wikiUrl, 'https://en.wikipedia.org/wiki/Tom_Hanks');
    });

    test('accepts a name without its middle initial offline', () async {
      wiki.offline = true;
      final result = await service.validate('John Kennedy', 'J', 'K');
      expect(result.celebrity?.name, 'John F. Kennedy');
    });

    test('offers a near miss for a misspelled name offline', () async {
      wiki.offline = true;
      final result = await service.validate('Jon Lenon', 'J', 'L');
      expect(result.isSuccess, isFalse);
      expect(result.isNearMiss, isTrue);
      expect(result.suggestion?.name, 'John Lennon');
      expect(result.hint, 'So close! Both names are a little off.');
    });

    test('accepts a name Wikipedia knows under another title', () async {
      final result = await service.validate('Kate Middleton', 'K', 'M');
      expect(result.celebrity?.name, 'Kate Middleton');
    });

    test('rejects names nowhere near anyone', () async {
      wiki.offline = true;
      final result = await service.validate('Tqqqq Hzzzz', 'T', 'H');
      expect(result.isSuccess, isFalse);
      expect(result.isNearMiss, isFalse);
      expect(result.error, "We don't know that one — try someone else");
    });

    test('reads initials past accents', () async {
      wiki.offline = true;
      final result = await service.validate('Émile Zqqqq', 'E', 'Z');
      expect(result.error, "We don't know that one — try someone else");
    });

    test('caches near misses for the session', () async {
      await service.validate('Jon Lenon', 'J', 'L');
      final requests = wiki.requests.length;
      final again = await service.validate('jon lenon', 'J', 'L');
      expect(again.suggestion?.name, 'John Lennon');
      expect(wiki.requests.length, requests);
    });
  });

  group('normalize', () {
    test('lowercases input', () {
      expect(CelebrityService.normalize('John Smith'), 'john smith');
    });

    test('strips diacritics', () {
      expect(CelebrityService.normalize('José García'), 'jose garcia');
      expect(CelebrityService.normalize('François Müller'), 'francois muller');
      expect(CelebrityService.normalize('Ñoño'), 'nono');
      expect(CelebrityService.normalize('Çelik'), 'celik');
    });

    test('strips punctuation but keeps spaces', () {
      expect(CelebrityService.normalize("O'Brien"), 'obrien');
      expect(CelebrityService.normalize('Dr. Smith'), 'dr smith');
    });

    test('collapses whitespace', () {
      expect(CelebrityService.normalize('  John   Doe  '), 'john doe');
    });

    test('handles empty string', () {
      expect(CelebrityService.normalize(''), '');
    });

    test('strips numbers and special chars', () {
      expect(CelebrityService.normalize('Player123'), 'player');
    });
  });

  group('sanitize', () {
    test('strips punctuation marks', () {
      expect(CelebrityService.sanitize('Dr. John!'), 'Dr John');
    });

    test('strips quotes and smart quotes', () {
      expect(CelebrityService.sanitize('"John"'), 'John');
      expect(CelebrityService.sanitize('\u2018John\u2019'), 'John');
    });

    test('collapses whitespace', () {
      expect(CelebrityService.sanitize('John   Smith'), 'John Smith');
    });

    test('preserves hyphens in names', () {
      // Hyphens are NOT in the sanitize strip list
      expect(CelebrityService.sanitize('Mary-Jane Watson'), 'Mary-Jane Watson');
    });

    test('preserves basic letters and numbers', () {
      expect(CelebrityService.sanitize('John Smith Jr'), 'John Smith Jr');
    });
  });

  group('buildSlug', () {
    test('capitalizes first letter of each word', () {
      expect(CelebrityService.buildSlug('john smith'), 'John_Smith');
    });

    test('preserves internal casing (McDonald, DeVito)', () {
      expect(CelebrityService.buildSlug('mcDonald'), 'McDonald');
      expect(CelebrityService.buildSlug('robert de niro'), 'Robert_De_Niro');
    });

    test('joins words with underscores', () {
      expect(
          CelebrityService.buildSlug('martin luther king'),
          'Martin_Luther_King');
    });

    test('handles single word', () {
      expect(CelebrityService.buildSlug('madonna'), 'Madonna');
    });
  });

  group('isPerson', () {
    test('detects person from description keywords', () {
      expect(WikipediaResolver.isPerson('actor', ''), true);
      expect(WikipediaResolver.isPerson('singer', ''), true);
      expect(WikipediaResolver.isPerson('', 'she was born in 1990'), true);
    });

    test('rejects non-person entries', () {
      expect(WikipediaResolver.isPerson('a city in france', ''), false);
      expect(WikipediaResolver.isPerson('type of rock', ''), false);
      expect(
          WikipediaResolver.isPerson('programming language', 'released in 2020'),
          false);
    });

    test('rejects fictional characters', () {
      expect(WikipediaResolver.isPerson('fictional character', ''), false);
      expect(WikipediaResolver.isPerson('video game character', ''), false);
      expect(WikipediaResolver.isPerson('anime character', ''), false);
      expect(WikipediaResolver.isPerson('comic book superhero', ''), false);
      expect(WikipediaResolver.isPerson('cartoon mascot', ''), false);
    });

    test('rejection overrides positive keywords in extract', () {
      // Description says fictional, even if extract mentions "player"
      expect(WikipediaResolver.isPerson('fictional character', 'is a player in the game'), false);
    });

    test('checks both description and extract', () {
      expect(WikipediaResolver.isPerson('', 'died in 1999'), true);
      expect(WikipediaResolver.isPerson('quarterback', ''), true);
    });
  });

  group('formatDescription', () {
    test('capitalizes each word', () {
      expect(WikipediaResolver.formatDescription('american actor'), 'American Actor');
    });

    test('returns Notable Person for empty input', () {
      expect(WikipediaResolver.formatDescription(''), 'Notable Person');
    });

    test('handles single word', () {
      expect(WikipediaResolver.formatDescription('singer'), 'Singer');
    });
  });
}
