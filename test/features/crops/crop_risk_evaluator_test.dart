import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_risk_evaluator.dart';
import 'package:crop_alerts/features/crops/domain/growing_season.dart';
import 'package:crop_alerts/features/crops/domain/threat.dart';
import 'package:crop_alerts/features/rules/domain/condition.dart';
import 'package:crop_alerts/features/rules/domain/risk.dart';
import 'package:crop_alerts/features/rules/domain/rule.dart';
import 'package:crop_alerts/features/rules/domain/weather_metric.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

DailyForecast day(
  DateTime date, {
  double minTemperature = 16,
  double maxTemperature = 20,
  double maxHumidity = 95,
}) {
  return DailyForecast(
    date: date,
    minTemperature: minTemperature,
    maxTemperature: maxTemperature,
    minHumidity: 40,
    maxHumidity: maxHumidity,
    precipitation: 0,
    sampleCount: 24,
  );
}

/// Weather that fires both potato blight rules.
List<DailyForecast> favourableWeek(DateTime start) => [
      for (var i = 0; i < 7; i++) day(start.add(Duration(days: i))),
    ];

const blightRules = [
  Rule(
    id: 'krompir.plamenjaca.temperatura',
    threatId: 'plamenjaca',
    condition: RangeOverlap.temperature(min: 15, max: 21),
  ),
  Rule(
    id: 'krompir.plamenjaca.vlaznost',
    threatId: 'plamenjaca',
    condition: MetricThreshold(
      metric: WeatherMetric.maxHumidity,
      comparator: Comparator.greaterThan,
      value: 90,
    ),
  ),
];

Crop potato({GrowingSeason season = const GrowingSeason(fromMonth: 3, toMonth: 9)}) {
  return Crop(
    id: 'krompir',
    name: 'Krompir',
    season: season,
    threats: const [
      Threat(
        id: 'plamenjaca',
        type: ThreatType.fungalDisease,
        name: 'Plamenjača',
        prevention: ['Sertifikovano seme.'],
        response: ['Prskanje bakarnim preparatima.'],
        rules: blightRules,
      ),
    ],
  );
}

void main() {
  const evaluator = CropRiskEvaluator();

  group('season gating', () {
    test('reports risk inside the season', () {
      final assessment = evaluator.assess(
        crop: potato(),
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      expect(assessment.overall, RiskLevel.high);
      expect(assessment.isDormant, isFalse);
      expect(assessment.isInSeasonNow, isTrue);
    });

    test('stays silent outside it, however favourable the weather', () {
      // January weather can perfectly well suit blight. Saying so about a crop
      // that is not in the ground trains a grower to ignore the app.
      final assessment = evaluator.assess(
        crop: potato(),
        forecast: favourableWeek(DateTime(2026)),
      );

      expect(assessment.overall, RiskLevel.low);
      expect(assessment.hasRisk, isFalse);
      expect(assessment.isDormant, isTrue);
      expect(assessment.days.every((d) => d.threats.isEmpty), isTrue);
    });

    test('keeps out-of-season days in the timeline rather than dropping them', () {
      final forecast = favourableWeek(DateTime(2026));

      final assessment = evaluator.assess(crop: potato(), forecast: forecast);

      expect(assessment.days, hasLength(forecast.length));
      expect(assessment.days.every((d) => !d.inSeason), isTrue);
    });

    test('gates day by day across a season boundary', () {
      // The season ends on 30 September; the forecast runs into October.
      final forecast = [
        for (var i = 0; i < 6; i++) day(DateTime(2026, 9, 28).add(Duration(days: i))),
      ];

      final assessment = evaluator.assess(crop: potato(), forecast: forecast);

      expect(
        assessment.days.map((d) => d.inSeason),
        [true, true, true, false, false, false],
      );
      expect(
        assessment.days.take(3).every((d) => d.risk.level == RiskLevel.high),
        isTrue,
      );
      expect(
        assessment.days.skip(3).every((d) => d.risk.level == RiskLevel.low),
        isTrue,
      );
      // Some of the forecast is in season, so the crop is not dormant.
      expect(assessment.isDormant, isFalse);
      expect(assessment.overall, RiskLevel.high);
    });

    test('handles a season that wraps the new year', () {
      final garlic = potato(season: const GrowingSeason(fromMonth: 10, toMonth: 6));

      final december = evaluator.assess(
        crop: garlic,
        forecast: favourableWeek(DateTime(2026, 12)),
      );
      final august = evaluator.assess(
        crop: garlic,
        forecast: favourableWeek(DateTime(2026, 8)),
      );

      expect(december.isDormant, isFalse);
      expect(december.overall, RiskLevel.high);
      expect(august.isDormant, isTrue);
      expect(august.overall, RiskLevel.low);
    });
  });

  group('resolving threats', () {
    test('puts names and advice back onto the engine output', () {
      final assessment = evaluator.assess(
        crop: potato(),
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      final threat = assessment.days.first.threats.single;
      expect(threat.threat.name, 'Plamenjača');
      expect(threat.threat.type, ThreatType.fungalDisease);
      expect(threat.threat.response, ['Prskanje bakarnim preparatima.']);
      expect(threat.level, RiskLevel.high);
      expect(threat.score, 2);
      expect(threat.matches, hasLength(2));
    });

    test('carries the readings that triggered each rule', () {
      final assessment = evaluator.assess(
        crop: potato(),
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      final observations = assessment.days.first.threats.single.matches
          .expand((m) => m.observations)
          .toList();

      expect(observations, hasLength(2));
      expect(
        observations.map((o) => o.metric),
        containsAll([WeatherMetric.minTemperature, WeatherMetric.maxHumidity]),
      );
    });

    test('skips a threat id the crop does not define', () {
      // The catalogue validator rejects this, but a remote source might not.
      const broken = Crop(
        id: 'krompir',
        name: 'Krompir',
        season: GrowingSeason.yearRound,
        threats: [
          Threat(
            id: 'plamenjaca',
            type: ThreatType.fungalDisease,
            name: 'Plamenjača',
            rules: [
              Rule(
                id: 'orphan',
                threatId: 'nepostojeca',
                condition: MetricThreshold(
                  metric: WeatherMetric.maxHumidity,
                  comparator: Comparator.greaterThan,
                  value: 90,
                ),
              ),
            ],
          ),
        ],
      );

      final assessment = evaluator.assess(
        crop: broken,
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      expect(assessment.days.first.threats, isEmpty);
      expect(assessment.overall, RiskLevel.moderate);
    });
  });

  group('summarising', () {
    test('daysAtRisk lists only the days worth attention, worst first', () {
      final forecast = [
        day(DateTime(2026, 7), maxHumidity: 40),
        day(DateTime(2026, 7, 2), maxHumidity: 40, minTemperature: 16),
        day(DateTime(2026, 7, 3), maxHumidity: 95),
        day(DateTime(2026, 7, 4), minTemperature: 30, maxTemperature: 38, maxHumidity: 20),
      ];

      final assessment = evaluator.assess(crop: potato(), forecast: forecast);

      expect(assessment.daysAtRisk.first.risk.level, RiskLevel.high);
      expect(assessment.daysAtRisk.first.date, DateTime(2026, 7, 3));
      expect(assessment.daysAtRisk, hasLength(3));
      expect(
        assessment.daysAtRisk.last.risk.level,
        RiskLevel.moderate,
      );
    });

    test('an empty forecast is neither risky nor dormant', () {
      final assessment = evaluator.assess(crop: potato(), forecast: const []);

      expect(assessment.days, isEmpty);
      expect(assessment.overall, RiskLevel.low);
      expect(assessment.isDormant, isFalse);
      expect(assessment.isInSeasonNow, isFalse);
    });
  });

  group('assessAll', () {
    Crop cropNamed(String id, String name, {required List<Rule> rules, GrowingSeason? season}) {
      return Crop(
        id: id,
        name: name,
        season: season ?? const GrowingSeason(fromMonth: 3, toMonth: 9),
        threats: [
          Threat(
            id: 'plamenjaca',
            type: ThreatType.fungalDisease,
            name: 'Plamenjača',
            rules: rules,
          ),
        ],
      );
    }

    test('sorts by risk, worst first', () {
      final crops = [
        cropNamed('nizak', 'Nizak', rules: const [
          Rule(
            id: 'r',
            threatId: 'plamenjaca',
            condition: MetricThreshold(
              metric: WeatherMetric.maxHumidity,
              comparator: Comparator.greaterThan,
              value: 99,
            ),
          ),
        ]),
        cropNamed('visok', 'Visok', rules: blightRules),
        cropNamed('umeren', 'Umeren', rules: [blightRules.first]),
      ];

      final assessments = evaluator.assessAll(
        crops: crops,
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      expect(
        assessments.map((a) => a.crop.id),
        ['visok', 'umeren', 'nizak'],
      );
    });

    test('dormant crops sink below everything', () {
      final crops = [
        cropNamed(
          'dormantan',
          'Dormantan',
          rules: blightRules,
          season: const GrowingSeason(fromMonth: 1, toMonth: 2),
        ),
        cropNamed('nizak', 'Nizak', rules: const [
          Rule(
            id: 'r',
            threatId: 'plamenjaca',
            condition: MetricThreshold(
              metric: WeatherMetric.maxHumidity,
              comparator: Comparator.greaterThan,
              value: 99,
            ),
          ),
        ]),
      ];

      final assessments = evaluator.assessAll(
        crops: crops,
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      expect(assessments.first.crop.id, 'nizak');
      expect(assessments.last.crop.id, 'dormantan');
      expect(assessments.last.isDormant, isTrue);
    });

    test('crops at the same level are ordered by name', () {
      final crops = [
        cropNamed('b', 'Bela', rules: blightRules),
        cropNamed('a', 'Ana', rules: blightRules),
      ];

      final assessments = evaluator.assessAll(
        crops: crops,
        forecast: favourableWeek(DateTime(2026, 7)),
      );

      expect(assessments.map((a) => a.crop.name), ['Ana', 'Bela']);
    });
  });
}
