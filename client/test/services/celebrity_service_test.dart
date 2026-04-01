import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/services/celebrity_service.dart';

void main() {
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
      expect(CelebrityService.isPerson('american actor', ''), true);
      expect(CelebrityService.isPerson('british singer', ''), true);
      expect(CelebrityService.isPerson('', 'she was born in 1990'), true);
    });

    test('rejects non-person entries', () {
      expect(CelebrityService.isPerson('a city in france', ''), false);
      expect(CelebrityService.isPerson('type of rock', ''), false);
      expect(
          CelebrityService.isPerson('programming language', 'released in 2020'),
          false);
    });

    test('checks both description and extract', () {
      expect(CelebrityService.isPerson('', 'died in 1999'), true);
      expect(CelebrityService.isPerson('quarterback', ''), true);
    });
  });

  group('formatDescription', () {
    test('capitalizes each word', () {
      expect(CelebrityService.formatDescription('american actor'), 'American Actor');
    });

    test('returns Notable Person for empty input', () {
      expect(CelebrityService.formatDescription(''), 'Notable Person');
    });

    test('handles single word', () {
      expect(CelebrityService.formatDescription('singer'), 'Singer');
    });
  });
}
