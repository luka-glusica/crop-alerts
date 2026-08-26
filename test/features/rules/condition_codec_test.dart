import 'dart:convert';

import 'package:crop_alerts/features/rules/data/condition_codec.dart';
import 'package:crop_alerts/features/rules/domain/condition.dart';
import 'package:crop_alerts/features/rules/domain/rule.dart';
import 'package:crop_alerts/features/rules/domain/weather_metric.dart';
import 'package:crop_alerts/features/rules/domain/weather_window.dart';
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

void main() {
  /// Sends a condition through JSON and back, then checks the two agree on
  /// every day of a varied forecast — the property that actually matters for
  /// rules arriving from a server.
  void expectRoundTrip(Condition original) {
    final encoded = jsonEncode(original.toJson());
    final restored = ConditionCodec.conditionFromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    expect(
      jsonEncode(restored.toJson()),
      encoded,
      reason: 're-encoding must be identical',
    );

    final forecast = [
      day(dayOfMonth: 1, minTemperature: 2, maxTemperature: 9, maxHumidity: 30),
      day(dayOfMonth: 2, minTemperature: 16, maxTemperature: 20, maxHumidity: 95, precipitation: 8),
      day(dayOfMonth: 3, minTemperature: 22, maxTemperature: 29, maxHumidity: 88, precipitation: 12),
      day(dayOfMonth: 4, minTemperature: 15, maxTemperature: 21, maxHumidity: 91, precipitation: 0),
      day(dayOfMonth: 5, minTemperature: 31, maxTemperature: 39, maxHumidity: 15),
    ];

    for (final window in WeatherWindow.over(forecast)) {
      expect(
        restored.matches(window),
        original.matches(window),
        reason: 'behaviour diverged on ${window.date}',
      );
    }
  }

  group('round trips', () {
    test('metricThreshold', () {
      expectRoundTrip(
        const MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 85,
        ),
      );
    });

    test('metricBand', () {
      expectRoundTrip(
        const MetricBand(
          metric: WeatherMetric.averageTemperature,
          min: 15,
          max: 25,
        ),
      );
    });

    test('rangeOverlap', () {
      expectRoundTrip(const RangeOverlap.temperature(min: 15, max: 21));
      expectRoundTrip(const RangeOverlap.humidity(min: 80, max: 100));
    });

    test('sumOverDays', () {
      expectRoundTrip(
        const SumOverDays(
          metric: WeatherMetric.precipitation,
          days: 3,
          comparator: Comparator.atLeast,
          value: 15,
        ),
      );
    });

    test('consecutiveDays', () {
      expectRoundTrip(
        const ConsecutiveDays(
          days: 2,
          condition: MetricThreshold(
            metric: WeatherMetric.maxHumidity,
            comparator: Comparator.atLeast,
            value: 80,
          ),
        ),
      );
    });

    test('monthRange', () {
      expectRoundTrip(const MonthRange(fromMonth: 5, toMonth: 6));
    });

    test('monthRange that wraps the year', () {
      expectRoundTrip(const MonthRange(fromMonth: 10, toMonth: 3));
    });

    test('allOf, anyOf and not', () {
      expectRoundTrip(
        const AllOf([
          RangeOverlap.temperature(min: 15, max: 21),
          MetricThreshold(
            metric: WeatherMetric.maxHumidity,
            comparator: Comparator.greaterThan,
            value: 90,
          ),
        ]),
      );
      expectRoundTrip(
        const AnyOf([
          MetricThreshold(
            metric: WeatherMetric.precipitation,
            comparator: Comparator.atLeast,
            value: 10,
          ),
          MetricThreshold(
            metric: WeatherMetric.maxHumidity,
            comparator: Comparator.greaterThan,
            value: 95,
          ),
        ]),
      );
      expectRoundTrip(
        const Not(
          MetricThreshold(
            metric: WeatherMetric.precipitation,
            comparator: Comparator.greaterThan,
            value: 0,
          ),
        ),
      );
    });

    test('a deeply nested tree', () {
      expectRoundTrip(
        const AllOf([
          AnyOf([
            RangeOverlap.temperature(min: 15, max: 21),
            AllOf([
              MetricBand(metric: WeatherMetric.averageTemperature, min: 26, max: 30),
              Not(
                MetricThreshold(
                  metric: WeatherMetric.precipitation,
                  comparator: Comparator.greaterThan,
                  value: 20,
                ),
              ),
            ]),
          ]),
          ConsecutiveDays(
            days: 2,
            condition: SumOverDays(
              metric: WeatherMetric.precipitation,
              days: 2,
              comparator: Comparator.atLeast,
              value: 5,
            ),
          ),
        ]),
      );
    });

    test('every condition type declares a distinct discriminator', () {
      const conditions = <Condition>[
        MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 1,
        ),
        MetricBand(metric: WeatherMetric.maxHumidity, min: 1, max: 2),
        RangeOverlap.temperature(min: 1, max: 2),
        SumOverDays(
          metric: WeatherMetric.precipitation,
          days: 1,
          comparator: Comparator.atLeast,
          value: 1,
        ),
        ConsecutiveDays(
          days: 1,
          condition: MetricBand(metric: WeatherMetric.maxHumidity, min: 1, max: 2),
        ),
        MonthRange(fromMonth: 1, toMonth: 2),
        AllOf([MetricBand(metric: WeatherMetric.maxHumidity, min: 1, max: 2)]),
        AnyOf([MetricBand(metric: WeatherMetric.maxHumidity, min: 1, max: 2)]),
        Not(MetricBand(metric: WeatherMetric.maxHumidity, min: 1, max: 2)),
      ];

      final types = conditions.map((c) => c.type).toSet();
      expect(types, hasLength(conditions.length));
    });
  });

  group('rules', () {
    test('round-trip with their metadata', () {
      const original = Rule(
        id: 'krompir.plamenjaca.vlaznost',
        threatId: 'plamenjaca',
        weight: 2,
        source: RuleSource.community,
        authorId: 'user-42',
        condition: MetricThreshold(
          metric: WeatherMetric.maxHumidity,
          comparator: Comparator.greaterThan,
          value: 90,
        ),
      );

      final restored = ConditionCodec.ruleFromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.threatId, original.threatId);
      expect(restored.weight, 2);
      expect(restored.source, RuleSource.community);
      expect(restored.authorId, 'user-42');
      expect(restored.condition.toJson(), original.condition.toJson());
    });

    test('default to built-in with weight one', () {
      final rule = ConditionCodec.ruleFromJson({
        'id': 'r1',
        'threatId': 't1',
        'condition': {
          'type': 'metricThreshold',
          'metric': 'maxHumidity',
          'comparator': 'greaterThan',
          'value': 85,
        },
      });

      expect(rule.weight, 1);
      expect(rule.source, RuleSource.builtIn);
      expect(rule.authorId, isNull);
    });

    test('an unknown source falls back to built-in rather than failing', () {
      final rule = ConditionCodec.ruleFromJson({
        'id': 'r1',
        'threatId': 't1',
        'source': 'somethingNew',
        'condition': {
          'type': 'metricBand',
          'metric': 'maxHumidity',
          'min': 1,
          'max': 2,
        },
      });

      expect(rule.source, RuleSource.builtIn);
    });

    test('a list of rules parses', () {
      final rules = ConditionCodec.rulesFromJson([
        {
          'id': 'r1',
          'threatId': 't1',
          'condition': {
            'type': 'metricBand',
            'metric': 'maxHumidity',
            'min': 1,
            'max': 2,
          },
        },
        {
          'id': 'r2',
          'threatId': 't2',
          'condition': {
            'type': 'metricBand',
            'metric': 'maxHumidity',
            'min': 1,
            'max': 2,
          },
        },
      ]);

      expect(rules.map((r) => r.id), ['r1', 'r2']);
    });
  });

  group('bad input fails loudly', () {
    // A rule that silently never matches is worse than one that fails to load:
    // the grower would simply never be warned, with nothing to show for it.
    void expectRejected(Object json, {String? because}) {
      expect(
        () => ConditionCodec.conditionFromJson(json as Map<String, dynamic>),
        throwsA(isA<RuleFormatException>()),
        reason: because,
      );
    }

    test('unknown condition type', () {
      expectRejected({'type': 'wetLeafHours'});
    });

    test('missing type', () {
      expectRejected({'metric': 'maxHumidity'});
    });

    test('unknown metric', () {
      expectRejected({
        'type': 'metricThreshold',
        'metric': 'leafWetness',
        'comparator': 'greaterThan',
        'value': 5,
      });
    });

    test('unknown comparator', () {
      expectRejected({
        'type': 'metricThreshold',
        'metric': 'maxHumidity',
        'comparator': 'approximately',
        'value': 5,
      });
    });

    test('a non-numeric threshold', () {
      expectRejected({
        'type': 'metricThreshold',
        'metric': 'maxHumidity',
        'comparator': 'greaterThan',
        'value': 'quite high',
      });
    });

    test('a month outside 1–12', () {
      // Month 0 is the classic off-by-one from a zero-indexed calendar, and it
      // would produce a rule that never fires.
      expectRejected({'type': 'monthRange', 'fromMonth': 0, 'toMonth': 6});
      expectRejected({'type': 'monthRange', 'fromMonth': 5, 'toMonth': 13});
      expectRejected({'type': 'monthRange', 'fromMonth': -1, 'toMonth': 6});
    });

    test('a fractional or non-numeric month', () {
      expectRejected({'type': 'monthRange', 'fromMonth': 5.5, 'toMonth': 6});
      expectRejected({'type': 'monthRange', 'fromMonth': 'maj', 'toMonth': 6});
    });

    test('a monthRange missing a bound', () {
      expectRejected({'type': 'monthRange', 'fromMonth': 5});
    });

    test('a zero or fractional day span', () {
      expectRejected({
        'type': 'sumOverDays',
        'metric': 'precipitation',
        'days': 0,
        'comparator': 'atLeast',
        'value': 5,
      });
      expectRejected({
        'type': 'sumOverDays',
        'metric': 'precipitation',
        'days': 2.5,
        'comparator': 'atLeast',
        'value': 5,
      });
    });

    test('an empty conditions list', () {
      expectRejected({'type': 'allOf', 'conditions': <dynamic>[]});
      expectRejected({'type': 'anyOf', 'conditions': <dynamic>[]});
    });

    test('a malformed nested condition', () {
      expectRejected({
        'type': 'allOf',
        'conditions': [
          {'type': 'metricBand', 'metric': 'maxHumidity', 'min': 1, 'max': 2},
          {'type': 'nonsense'},
        ],
      });
    });

    test('a rule without an id or threat', () {
      expect(
        () => ConditionCodec.ruleFromJson({'threatId': 't'}),
        throwsA(isA<RuleFormatException>()),
      );
      expect(
        () => ConditionCodec.ruleFromJson({'id': 'r'}),
        throwsA(isA<RuleFormatException>()),
      );
    });

    test('a rule with a non-positive weight', () {
      expect(
        () => ConditionCodec.ruleFromJson({
          'id': 'r',
          'threatId': 't',
          'weight': 0,
          'condition': {
            'type': 'metricBand',
            'metric': 'maxHumidity',
            'min': 1,
            'max': 2,
          },
        }),
        throwsA(isA<RuleFormatException>()),
      );
    });
  });
}
