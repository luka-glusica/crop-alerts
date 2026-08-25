import 'package:crop_alerts/features/alerts/alert_digest.dart';
import 'package:crop_alerts/features/alerts/notification_preferences.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_assessment.dart';
import 'package:crop_alerts/features/crops/domain/growing_season.dart';
import 'package:crop_alerts/features/rules/domain/risk.dart';
import 'package:flutter_test/flutter_test.dart';

CropAssessment assessment(
  String name,
  List<RiskLevel> levels, {
  DateTime? from,
  bool inSeason = true,
}) {
  final start = from ?? DateTime(2026, 8, 25);
  final days = [
    for (var i = 0; i < levels.length; i++)
      CropDayAssessment(
        date: start.add(Duration(days: i)),
        inSeason: inSeason,
        risk: DayRisk(
          date: start.add(Duration(days: i)),
          level: inSeason ? levels[i] : RiskLevel.low,
          threats: const [],
        ),
        threats: const [],
      ),
  ];

  var worst = RiskLevel.low;
  for (final day in days) {
    if (day.risk.level > worst) worst = day.risk.level;
  }

  return CropAssessment(
    crop: Crop(
      id: name.toLowerCase(),
      name: name,
      season: GrowingSeason.yearRound,
      threats: const [],
    ),
    days: days,
    overall: worst,
  );
}

void main() {
  final today = DateTime(2026, 8, 25);
  const high = NotificationPreferences(high: true);
  const both = NotificationPreferences(high: true, moderate: true);

  group('what counts', () {
    test('only the levels the grower asked about', () {
      final moderateOnly = [
        assessment('Paradajz', [RiskLevel.moderate, RiskLevel.moderate]),
      ];

      expect(
        AlertDigest.build(
          assessments: moderateOnly,
          preferences: high,
          today: today,
        ),
        isNull,
      );
      expect(
        AlertDigest.build(
          assessments: moderateOnly,
          preferences: both,
          today: today,
        ),
        isNotNull,
      );
    });

    test('nothing at all when notifications are off', () {
      expect(
        AlertDigest.build(
          assessments: [assessment('Paradajz', [RiskLevel.high])],
          preferences: const NotificationPreferences(),
          today: today,
        ),
        isNull,
      );
    });

    test('only days inside the horizon', () {
      final later = assessment(
        'Paradajz',
        [RiskLevel.high],
        from: today.add(const Duration(days: 8)),
      );

      expect(
        AlertDigest.build(assessments: [later], preferences: high, today: today),
        isNull,
      );
    });

    test('not days that have already passed', () {
      // A cached forecast can start yesterday; raising an alarm about weather
      // that has already happened is worse than saying nothing.
      final yesterday = assessment(
        'Paradajz',
        [RiskLevel.high, RiskLevel.low],
        from: today.subtract(const Duration(days: 1)),
      );

      expect(
        AlertDigest.build(
          assessments: [yesterday],
          preferences: high,
          today: today,
        ),
        isNull,
      );
    });

    test('not crops that are out of season', () {
      expect(
        AlertDigest.build(
          assessments: [
            assessment('Paradajz', [RiskLevel.high], inSeason: false),
          ],
          preferences: high,
          today: today,
        ),
        isNull,
      );
    });
  });

  group('the summary', () {
    test('counts crop-days at each level', () {
      final digest = AlertDigest.build(
        assessments: [
          assessment('Paradajz', [RiskLevel.high, RiskLevel.moderate]),
          assessment('Krompir', [RiskLevel.high, RiskLevel.low]),
        ],
        preferences: both,
        today: today,
      )!;

      expect(digest.highCount, 2);
      expect(digest.moderateCount, 1);
      expect(digest.level, RiskLevel.high);
    });

    test('lists each crop once, worst first', () {
      final digest = AlertDigest.build(
        assessments: [
          assessment('Umeren', [RiskLevel.moderate, RiskLevel.moderate]),
          assessment('Visok', [RiskLevel.high, RiskLevel.high]),
        ],
        preferences: both,
        today: today,
      )!;

      expect(digest.cropNames, ['Visok', 'Umeren']);
    });

    test('is moderate overall when nothing reached high', () {
      final digest = AlertDigest.build(
        assessments: [assessment('Paradajz', [RiskLevel.moderate])],
        preferences: both,
        today: today,
      )!;

      expect(digest.level, RiskLevel.moderate);
    });
  });

  group('the de-duplication key', () {
    AlertDigest digestOf(List<CropAssessment> assessments) =>
        AlertDigest.build(
          assessments: assessments,
          preferences: both,
          today: today,
        )!;

    test('is stable for the same outlook', () {
      final a = digestOf([assessment('Paradajz', [RiskLevel.high])]);
      final b = digestOf([assessment('Paradajz', [RiskLevel.high])]);

      expect(a.dedupeKey, b.dedupeKey);
    });

    test('changes when the risk worsens', () {
      final before = digestOf([assessment('Paradajz', [RiskLevel.moderate])]);
      final after = digestOf([assessment('Paradajz', [RiskLevel.high])]);

      expect(after.dedupeKey, isNot(before.dedupeKey));
    });

    test('changes when another crop joins', () {
      final one = digestOf([assessment('Paradajz', [RiskLevel.high])]);
      final two = digestOf([
        assessment('Paradajz', [RiskLevel.high]),
        assessment('Krompir', [RiskLevel.high]),
      ]);

      expect(two.dedupeKey, isNot(one.dedupeKey));
    });
  });

  group('NotificationPreferences', () {
    test('default to off, so the app does not notify before being asked', () {
      const defaults = NotificationPreferences();

      expect(defaults.high, isFalse);
      expect(defaults.moderate, isFalse);
      expect(defaults.anyEnabled, isFalse);
      expect(defaults.threshold, isNull);
    });

    test('wants() follows the settings', () {
      expect(high.wants(RiskLevel.high), isTrue);
      expect(high.wants(RiskLevel.moderate), isFalse);
      expect(both.wants(RiskLevel.moderate), isTrue);
      expect(both.wants(RiskLevel.low), isFalse);
    });

    test('the threshold is the least severe level asked for', () {
      expect(high.threshold, RiskLevel.high);
      expect(both.threshold, RiskLevel.moderate);
    });
  });
}
