import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/services/name_matcher.dart';

void main() {
  group('tokens', () {
    test('normalizes case, accents and punctuation', () {
      expect(NameMatcher.tokens("Shaquille O'Neal"), ['shaquille', 'oneal']);
      expect(NameMatcher.tokens('Émile Zola'), ['emile', 'zola']);
    });

    test('drops Wikipedia disambiguators and comma clauses', () {
      expect(NameMatcher.tokens('Chris Evans (actor)'), ['chris', 'evans']);
      expect(NameMatcher.tokens('Catherine, Princess of Wales'), ['catherine']);
    });

    test('drops generational suffixes', () {
      expect(NameMatcher.tokens('Martin Luther King Jr.'),
          ['martin', 'luther', 'king']);
      expect(NameMatcher.tokens('Ken Griffey III'), ['ken', 'griffey']);
    });
  });

  group('distance', () {
    test('counts insertions, deletions and substitutions', () {
      expect(NameMatcher.distance('lennon', 'lennon'), 0);
      expect(NameMatcher.distance('lenon', 'lennon'), 1);
      expect(NameMatcher.distance('jon', 'john'), 1);
      expect(NameMatcher.distance('mohammed', 'muhammad'), 2);
      expect(NameMatcher.distance('', 'abc'), 3);
    });

    test('counts a swapped pair of letters as one typo', () {
      expect(NameMatcher.distance('hnaks', 'hanks'), 1);
    });
  });

  group('compare', () {
    test('matches regardless of case, accents and punctuation', () {
      expect(
          NameMatcher.compare('leonardo dicaprio', 'Leonardo DiCaprio').isMatch,
          isTrue);
      expect(NameMatcher.compare('Shaquille ONeal', "Shaquille O'Neal").isMatch,
          isTrue);
      expect(NameMatcher.compare('Beyonce Knowles', 'Beyoncé Knowles').isMatch,
          isTrue);
    });

    test('matches with middle names missing or added', () {
      expect(NameMatcher.compare('John Kennedy', 'John F. Kennedy').isMatch,
          isTrue);
      expect(
          NameMatcher.compare('John Fitzgerald Kennedy', 'John F. Kennedy')
              .isMatch,
          isTrue);
    });

    test('matches with different spacing of initials and hyphens', () {
      expect(
          NameMatcher.compare('JK Rowling', 'J. K. Rowling').isMatch, isTrue);
      expect(
          NameMatcher.compare('Jean Paul Sartre', 'Jean-Paul Sartre').isMatch,
          isTrue);
    });

    test('matches past suffixes and disambiguators', () {
      expect(NameMatcher.compare('Ken Griffey', 'Ken Griffey Jr.').isMatch,
          isTrue);
      expect(NameMatcher.compare('Chris Evans', 'Chris Evans (actor)').isMatch,
          isTrue);
    });

    test('flags a misspelling as close, with per-name distances', () {
      final m = NameMatcher.compare('Jon Lenon', 'John Lennon');
      expect(m.isClose, isTrue);
      expect(m.firstDistance, 1);
      expect(m.lastDistance, 1);

      expect(
          NameMatcher.compare('Arnold Swarzenegger', 'Arnold Schwarzenegger')
              .isClose,
          isTrue);
      expect(
          NameMatcher.compare('Mohammed Ali', 'Muhammad Ali').isClose, isTrue);
    });

    test('rejects names too far apart to be a typo', () {
      expect(NameMatcher.compare('Tom Hardy', 'Tom Hanks').isNone, isTrue);
      expect(
          NameMatcher.compare('Kate Middleton', 'Catherine, Princess of Wales')
              .isNone,
          isTrue);
      // Two-letter names don't get typo tolerance.
      expect(NameMatcher.compare('Ed Gore', 'Al Gore').isNone, isTrue);
    });

    test('needs a first and last name', () {
      expect(NameMatcher.compare('Lennon', 'John Lennon').isNone, isTrue);
      expect(NameMatcher.compare('', 'John Lennon').isNone, isTrue);
    });
  });

  group('hasInitials', () {
    test('checks first and last name initials', () {
      expect(NameMatcher.hasInitials('John F. Kennedy', 'J', 'K'), isTrue);
      expect(NameMatcher.hasInitials('Chris Evans (actor)', 'C', 'E'), isTrue);
      expect(NameMatcher.hasInitials('Kris Jenner', 'C', 'J'), isFalse);
    });
  });

  group('nearMissHint', () {
    test('says which name is off without naming anyone', () {
      expect(NameMatcher.nearMissHint(const NameMatch.close(0, 1)),
          'So close! Last name is 1 letter off.');
      expect(NameMatcher.nearMissHint(const NameMatch.close(2, 0)),
          'So close! First name is 2 letters off.');
      expect(NameMatcher.nearMissHint(const NameMatch.close(1, 1)),
          'So close! Both names are a little off.');
    });
  });
}
