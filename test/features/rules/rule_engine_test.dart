import 'package:crop_alerts/features/rules/domain/condition.dart';
import 'package:crop_alerts/features/rules/domain/risk.dart';
import 'package:crop_alerts/features/rules/domain/rule.dart';
import 'package:crop_alerts/features/rules/domain/rule_engine.dart';
import 'package:crop_alerts/features/rules/domain/weather_metric.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

DailyForecast day({
  int dayOfMonth = 1,
  double minTemperature = 10,
  double maxTemperature = 20,
  double minHumidity = 40,
  double maxHumidity = 60,
  double precipitation = 0,
}) {
  return DailyForecast(
    date: DateTime(2026, 8, dayOfMonth),
    minTemperature: minTemperature,
    maxTemperature: maxTemperature,
    minHumidity: minHumidity,
    maxHumidity: maxHumidity,
    precipitation: precipitation,
    sampleCount: 24,
  );
}

/// The two rules the web version effectively has for potato late blight.
const blightTemperature = Rule(
  id: 'krompir.plamenjaca.temperatura',
  threatId: 'plamenjaca',
  condition: RangeOverlap.temperature(min: 15, max: 21),
);

const blightHumidity = Rule(
  id: 'krompir.plamenjaca.vlaznost',
  threatId: 'plamenjaca',
  condition: MetricThreshold(
    metric: WeatherMetric.maxHumidity,
    comparator: Comparator.greaterThan,
    value: 90,
  ),
);

void main() {
  const engine = RuleEngine();

  group('scoring, matching the web version', () {
    test('neither factor is low risk', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: [day(minTemperature: 30, maxTemperature: 38, maxHumidity: 20)],
      ).single;

      expect(risk.level, RiskLevel.low);
      expect(risk.hasRisk, isFalse);
      expect(risk.threats, isEmpty);
    });

    test('one factor is moderate risk', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: [day(minTemperature: 16, maxTemperature: 20, maxHumidity: 40)],
      ).single;

      expect(risk.level, RiskLevel.moderate);
      expect(risk.threats.single.score, 1);
      expect(risk.threats.single.matches, hasLength(1));
    });

    test('both factors are high risk', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: [day(minTemperature: 16, maxTemperature: 20, maxHumidity: 95)],
      ).single;

      expect(risk.level, RiskLevel.high);
      expect(risk.threats.single.score, 2);
      expect(risk.threats.single.matches, hasLength(2));
    });

    test('a heavier rule can reach high on its own', () {
      const decisive = Rule(
        id: 'decisive',
        threatId: 'plamenjaca',
        weight: 2,
        condition: MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 90,
        ),
      );

      final risk = engine.evaluate(
        rules: const [decisive],
        forecast: [day(maxHumidity: 95)],
      ).single;

      expect(risk.level, RiskLevel.high);
    });

    test('thresholds are configurable', () {
      const strict = RuleEngine(scoring: RiskScoring(moderateAt: 2, highAt: 3));

      final risk = strict.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: [day(minTemperature: 16, maxTemperature: 20, maxHumidity: 40)],
      ).single;

      // One matching rule no longer clears the bar.
      expect(risk.level, RiskLevel.low);
    });

    test('scoring boundaries are exact', () {
      const scoring = RiskScoring();

      expect(scoring.levelFor(0), RiskLevel.low);
      expect(scoring.levelFor(1), RiskLevel.moderate);
      expect(scoring.levelFor(2), RiskLevel.high);
      expect(scoring.levelFor(99), RiskLevel.high);
    });
  });

  group('several threats', () {
    const powderyMildew = Rule(
      id: 'pepelnica.temperatura',
      threatId: 'pepelnica',
      condition: RangeOverlap.temperature(min: 20, max: 27),
    );

    test('are scored separately, not pooled', () {
      // Both threats match once. Pooling would give a score of 2 and read as
      // high risk, when in truth each threat is only moderately favoured.
      final risk = engine.evaluate(
        rules: const [blightTemperature, powderyMildew],
        forecast: [day(minTemperature: 19, maxTemperature: 21, maxHumidity: 40)],
      ).single;

      expect(risk.threats, hasLength(2));
      expect(risk.threats.every((t) => t.level == RiskLevel.moderate), isTrue);
      expect(risk.level, RiskLevel.moderate);
    });

    test('the day takes the worst threat', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity, powderyMildew],
        forecast: [day(minTemperature: 20, maxTemperature: 21, maxHumidity: 95)],
      ).single;

      expect(risk.level, RiskLevel.high);
      expect(risk.threats.first.threatId, 'plamenjaca');
      expect(risk.threats.first.level, RiskLevel.high);
    });

    test('are ordered worst first', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity, powderyMildew],
        forecast: [day(minTemperature: 20, maxTemperature: 21, maxHumidity: 95)],
      ).single;

      expect(
        risk.threats.map((t) => t.level),
        [RiskLevel.high, RiskLevel.moderate],
      );
    });

    test('ordering is stable rather than dependent on map iteration', () {
      const a = Rule(
        id: 'a',
        threatId: 'aaa',
        condition: MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 10,
        ),
      );
      const z = Rule(
        id: 'z',
        threatId: 'zzz',
        condition: MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 10,
        ),
      );

      final forward = engine.evaluate(rules: const [a, z], forecast: [day()]);
      final reversed = engine.evaluate(rules: const [z, a], forecast: [day()]);

      expect(
        forward.single.threats.map((t) => t.threatId),
        reversed.single.threats.map((t) => t.threatId),
      );
    });

    test('threats scoring below moderate are left out entirely', () {
      const strict = RuleEngine(scoring: RiskScoring(moderateAt: 2, highAt: 3));

      final risk = strict.evaluate(
        rules: const [blightTemperature, powderyMildew],
        forecast: [day(minTemperature: 19, maxTemperature: 21)],
      ).single;

      expect(risk.threats, isEmpty);
    });
  });

  group('across a forecast', () {
    test('produces one result per day, in order', () {
      final forecast = [for (var i = 1; i <= 10; i++) day(dayOfMonth: i)];

      final risks = engine.evaluate(rules: const [blightTemperature], forecast: forecast);

      expect(risks, hasLength(10));
      expect(risks.map((r) => r.date.day), List.generate(10, (i) => i + 1));
    });

    test('each day is judged on its own weather', () {
      final forecast = [
        day(dayOfMonth: 1, minTemperature: 30, maxTemperature: 38, maxHumidity: 20),
        day(dayOfMonth: 2, minTemperature: 16, maxTemperature: 20, maxHumidity: 95),
        day(dayOfMonth: 3, minTemperature: 16, maxTemperature: 20, maxHumidity: 40),
      ];

      final risks = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: forecast,
      );

      expect(
        risks.map((r) => r.level),
        [RiskLevel.low, RiskLevel.high, RiskLevel.moderate],
      );
    });

    test('worstOf summarises a run of days', () {
      final forecast = [
        day(dayOfMonth: 1, minTemperature: 30, maxTemperature: 38, maxHumidity: 20),
        day(dayOfMonth: 2, minTemperature: 16, maxTemperature: 20, maxHumidity: 40),
        day(dayOfMonth: 3, minTemperature: 16, maxTemperature: 20, maxHumidity: 95),
      ];

      final risks = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: forecast,
      );

      expect(RuleEngine.worstOf(risks), RiskLevel.high);
      expect(RuleEngine.worstOf(risks.take(2)), RiskLevel.moderate);
      expect(RuleEngine.worstOf(risks.take(1)), RiskLevel.low);
      expect(RuleEngine.worstOf(const []), RiskLevel.low);
    });

    test('an empty forecast produces no days', () {
      expect(
        engine.evaluate(rules: const [blightTemperature], forecast: const []),
        isEmpty,
      );
    });

    test('no rules means no risk anywhere', () {
      final risks = engine.evaluate(
        rules: const [],
        forecast: [day(maxHumidity: 100)],
      );

      expect(risks.single.level, RiskLevel.low);
      expect(risks.single.threats, isEmpty);
    });
  });

  group('explanations', () {
    test('carry the readings that triggered each rule', () {
      final risk = engine.evaluate(
        rules: const [blightTemperature, blightHumidity],
        forecast: [day(minTemperature: 16, maxTemperature: 20, maxHumidity: 95)],
      ).single;

      final observations =
          risk.threats.single.matches.expand((m) => m.observations).toList();

      expect(observations, hasLength(2));
      expect(
        observations.map((o) => o.metric),
        containsAll([WeatherMetric.minTemperature, WeatherMetric.maxHumidity]),
      );
      expect(
        observations.firstWhere((o) => o.metric == WeatherMetric.maxHumidity).observed,
        95,
      );
    });

    test('name the rule they came from', () {
      final risk = engine.evaluate(
        rules: const [blightHumidity],
        forecast: [day(maxHumidity: 95)],
      ).single;

      expect(
        risk.threats.single.matches.single.rule.id,
        'krompir.plamenjaca.vlaznost',
      );
    });
  });

  group('RiskLevel ordering', () {
    test('compares by severity', () {
      expect(RiskLevel.high > RiskLevel.moderate, isTrue);
      expect(RiskLevel.moderate > RiskLevel.low, isTrue);
      expect(RiskLevel.low < RiskLevel.high, isTrue);
      expect(RiskLevel.high >= RiskLevel.high, isTrue);
      expect(RiskLevel.low <= RiskLevel.low, isTrue);
    });
  });
}
