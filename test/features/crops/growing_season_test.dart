import 'package:crop_alerts/features/crops/domain/growing_season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a season within one year', () {
    // Tomato: March through October.
    const tomato = GrowingSeason(fromMonth: 3, toMonth: 10);

    test('includes both end months', () {
      expect(tomato.contains(3), isTrue);
      expect(tomato.contains(10), isTrue);
    });

    test('includes the months between', () {
      for (var month = 3; month <= 10; month++) {
        expect(tomato.contains(month), isTrue, reason: 'month $month');
      }
    });

    test('excludes the months outside', () {
      for (final month in [1, 2, 11, 12]) {
        expect(tomato.contains(month), isFalse, reason: 'month $month');
      }
    });

    test('does not wrap', () {
      expect(tomato.wrapsYear, isFalse);
    });

    test('lists its months in order', () {
      expect(tomato.months, [3, 4, 5, 6, 7, 8, 9, 10]);
      expect(tomato.length, 8);
    });
  });

  group('a season that wraps the new year', () {
    // Garlic: planted in October, lifted in June.
    const garlic = GrowingSeason(fromMonth: 10, toMonth: 6);

    test('covers the months on both sides of the turn', () {
      for (final month in [10, 11, 12, 1, 2, 3, 4, 5, 6]) {
        expect(garlic.contains(month), isTrue, reason: 'month $month');
      }
    });

    test('excludes the summer gap', () {
      for (final month in [7, 8, 9]) {
        expect(garlic.contains(month), isFalse, reason: 'month $month');
      }
    });

    test('includes both end months', () {
      expect(garlic.contains(10), isTrue);
      expect(garlic.contains(6), isTrue);
    });

    test('knows it wraps', () {
      expect(garlic.wrapsYear, isTrue);
    });

    test('lists its months across the boundary in order', () {
      expect(garlic.months, [10, 11, 12, 1, 2, 3, 4, 5, 6]);
      expect(garlic.length, 9);
    });

    test('a naive from <= m <= to would report the exact opposite', () {
      // The trap this class exists to avoid.
      for (final month in [11, 12, 1]) {
        final naive = month >= garlic.fromMonth && month <= garlic.toMonth;
        expect(naive, isFalse);
        expect(garlic.contains(month), isTrue);
      }
    });
  });

  group('edge cases', () {
    test('a single-month season', () {
      const single = GrowingSeason(fromMonth: 7, toMonth: 7);

      expect(single.contains(7), isTrue);
      expect(single.contains(6), isFalse);
      expect(single.contains(8), isFalse);
      expect(single.months, [7]);
      expect(single.wrapsYear, isFalse);
    });

    test('year-round covers everything', () {
      for (var month = 1; month <= 12; month++) {
        expect(GrowingSeason.yearRound.contains(month), isTrue);
      }
      expect(GrowingSeason.yearRound.length, 12);
    });

    test('December to January wraps by the shortest possible margin', () {
      const winter = GrowingSeason(fromMonth: 12, toMonth: 1);

      expect(winter.contains(12), isTrue);
      expect(winter.contains(1), isTrue);
      expect(winter.contains(2), isFalse);
      expect(winter.contains(11), isFalse);
      expect(winter.months, [12, 1]);
    });

    test('rejects months outside 1–12', () {
      const tomato = GrowingSeason(fromMonth: 3, toMonth: 10);

      expect(tomato.contains(0), isFalse);
      expect(tomato.contains(13), isFalse);
      expect(tomato.contains(-1), isFalse);
    });
  });

  group('dates', () {
    const tomato = GrowingSeason(fromMonth: 3, toMonth: 10);

    test('reads the month from a date', () {
      expect(tomato.containsDate(DateTime(2026, 6, 15)), isTrue);
      expect(tomato.containsDate(DateTime(2026, 12, 15)), isFalse);
    });

    test('the day of the month does not matter', () {
      expect(tomato.containsDate(DateTime(2026, 3)), isTrue);
      expect(tomato.containsDate(DateTime(2026, 3, 31)), isTrue);
      expect(tomato.containsDate(DateTime(2026, 2, 28)), isFalse);
    });

    test('works across a year boundary in real dates', () {
      const garlic = GrowingSeason(fromMonth: 10, toMonth: 6);

      expect(garlic.containsDate(DateTime(2026, 12, 31)), isTrue);
      expect(garlic.containsDate(DateTime(2027, 1)), isTrue);
    });
  });

  test('value equality and serialization', () {
    const a = GrowingSeason(fromMonth: 3, toMonth: 10);
    const b = GrowingSeason(fromMonth: 3, toMonth: 10);
    const c = GrowingSeason(fromMonth: 10, toMonth: 3);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.toJson(), {'fromMonth': 3, 'toMonth': 10});
  });
}
