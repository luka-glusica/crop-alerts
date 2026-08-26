import 'package:crop_alerts/features/rules/domain/condition.dart';
import 'package:crop_alerts/features/rules/domain/rule_observation.dart';
import 'package:crop_alerts/features/rules/domain/weather_metric.dart';
import 'package:crop_alerts/features/rules/domain/weather_window.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

DailyForecast day({
  int dayOfMonth = 1,
  int month = 8,
  double minTemperature = 10,
  double maxTemperature = 20,
  double minHumidity = 40,
  double maxHumidity = 60,
  double precipitation = 0,
}) {
  return DailyForecast(
    date: DateTime(2026, month, dayOfMonth),
    minTemperature: minTemperature,
    maxTemperature: maxTemperature,
    minHumidity: minHumidity,
    maxHumidity: maxHumidity,
    precipitation: precipitation,
    sampleCount: 24,
  );
}

WeatherWindow windowOf(List<DailyForecast> days, [int index = 0]) =>
    WeatherWindow(days: days, index: index);

WeatherWindow single(DailyForecast forecast) => windowOf([forecast]);

void main() {
  group('MetricThreshold', () {
    const humid = MetricThreshold(
      metric: WeatherMetric.maxHumidity,
      comparator: Comparator.greaterThan,
      value: 85,
    );

    test('matches above the threshold', () {
      expect(humid.matches(single(day(maxHumidity: 88))), isTrue);
    });

    test('does not match below', () {
      expect(humid.matches(single(day(maxHumidity: 80))), isFalse);
    });

    test('greaterThan excludes the boundary, atLeast includes it', () {
      expect(humid.matches(single(day(maxHumidity: 85))), isFalse);

      const atLeast = MetricThreshold(
        metric: WeatherMetric.maxHumidity,
        comparator: Comparator.atLeast,
        value: 85,
      );
      expect(atLeast.matches(single(day(maxHumidity: 85))), isTrue);
    });

    test('lessThan and atMost mirror that at the other end', () {
      const below = MetricThreshold(
        metric: WeatherMetric.minTemperature,
        comparator: Comparator.lessThan,
        value: 15,
      );
      const atMost = MetricThreshold(
        metric: WeatherMetric.minTemperature,
        comparator: Comparator.atMost,
        value: 15,
      );

      expect(below.matches(single(day(minTemperature: 15))), isFalse);
      expect(atMost.matches(single(day(minTemperature: 15))), isTrue);
      expect(below.matches(single(day(minTemperature: 14.9))), isTrue);
    });

    test('reports what was observed and what was required', () {
      final result = humid.evaluate(single(day(maxHumidity: 88)));

      expect(
        result.observations,
        [
          const RuleObservation(
            metric: WeatherMetric.maxHumidity,
            observed: 88,
            requirement: ThresholdRequirement(Comparator.greaterThan, 85),
          ),
        ],
      );
    });

    test('explains nothing when it does not match', () {
      expect(humid.evaluate(single(day(maxHumidity: 40))).observations, isEmpty);
    });

    test('reads every metric it is pointed at', () {
      final forecast = day(
        minTemperature: 5,
        maxTemperature: 25,
        minHumidity: 30,
        maxHumidity: 90,
        precipitation: 4,
      );

      expect(WeatherMetric.minTemperature.read(forecast), 5);
      expect(WeatherMetric.maxTemperature.read(forecast), 25);
      expect(WeatherMetric.averageTemperature.read(forecast), 15);
      expect(WeatherMetric.minHumidity.read(forecast), 30);
      expect(WeatherMetric.maxHumidity.read(forecast), 90);
      expect(WeatherMetric.averageHumidity.read(forecast), 60);
      expect(WeatherMetric.precipitation.read(forecast), 4);
    });
  });

  group('MetricBand', () {
    const band = MetricBand(
      metric: WeatherMetric.averageTemperature,
      min: 15,
      max: 25,
    );

    test('matches inside the band', () {
      expect(
        band.matches(single(day(minTemperature: 18, maxTemperature: 22))),
        isTrue,
      );
    });

    test('includes both edges', () {
      expect(
        band.matches(single(day(minTemperature: 15, maxTemperature: 15))),
        isTrue,
      );
      expect(
        band.matches(single(day(minTemperature: 25, maxTemperature: 25))),
        isTrue,
      );
    });

    test('excludes just outside either edge', () {
      expect(
        band.matches(single(day(minTemperature: 14.9, maxTemperature: 14.9))),
        isFalse,
      );
      expect(
        band.matches(single(day(minTemperature: 25.1, maxTemperature: 25.1))),
        isFalse,
      );
    });
  });

  group('RangeOverlap', () {
    // "15–25°C favours late blight" means the day passed through that band,
    // not that it sat there all day.
    const favourable = RangeOverlap.temperature(min: 15, max: 25);

    test('matches when the day sits entirely inside the band', () {
      expect(
        favourable.matches(single(day(minTemperature: 17, maxTemperature: 23))),
        isTrue,
      );
    });

    test('matches when the day merely passes through the band', () {
      expect(
        favourable.matches(single(day(minTemperature: 8, maxTemperature: 31))),
        isTrue,
      );
    });

    test('matches when the day overlaps only at the top', () {
      expect(
        favourable.matches(single(day(minTemperature: 24, maxTemperature: 33))),
        isTrue,
      );
    });

    test('matches when the day overlaps only at the bottom', () {
      expect(
        favourable.matches(single(day(minTemperature: 2, maxTemperature: 16))),
        isTrue,
      );
    });

    test('does not match a day entirely below or above', () {
      expect(
        favourable.matches(single(day(minTemperature: 2, maxTemperature: 12))),
        isFalse,
      );
      expect(
        favourable.matches(single(day(minTemperature: 27, maxTemperature: 35))),
        isFalse,
      );
    });

    test('touching the band at a single degree counts', () {
      expect(
        favourable.matches(single(day(minTemperature: 25, maxTemperature: 33))),
        isTrue,
      );
      expect(
        favourable.matches(single(day(minTemperature: 2, maxTemperature: 15))),
        isTrue,
      );
    });

    test('agrees with the web version on its own crop data', () {
      // Krompir: 15–21°C. These are the comparisons the web app makes.
      const potato = RangeOverlap.temperature(min: 15, max: 21);

      bool webApp(double dayMin, double dayMax) => dayMin <= 21 && dayMax >= 15;

      for (final pair in [
        [10.0, 14.0],
        [10.0, 16.0],
        [16.0, 20.0],
        [20.0, 30.0],
        [22.0, 30.0],
        [15.0, 21.0],
      ]) {
        expect(
          potato.matches(single(day(minTemperature: pair[0], maxTemperature: pair[1]))),
          webApp(pair[0], pair[1]),
          reason: 'disagreed for ${pair[0]}–${pair[1]}°C',
        );
      }
    });

    test('reports the end of the range that lies in the band', () {
      final result = favourable.evaluate(
        single(day(minTemperature: 8, maxTemperature: 16)),
      );

      final observation = result.observations.single;
      expect(observation.metric, WeatherMetric.maxTemperature);
      expect(observation.observed, 16);
      expect(observation.requirement, const BandRequirement(15, 25));
    });

    test('works for humidity too', () {
      const humid = RangeOverlap.humidity(min: 80, max: 100);

      expect(
        humid.matches(single(day(minHumidity: 40, maxHumidity: 88))),
        isTrue,
      );
      expect(
        humid.matches(single(day(minHumidity: 40, maxHumidity: 70))),
        isFalse,
      );
    });
  });

  group('SumOverDays', () {
    const wetSpell = SumOverDays(
      metric: WeatherMetric.precipitation,
      days: 3,
      comparator: Comparator.atLeast,
      value: 15,
    );

    test('totals across the span', () {
      final forecast = [
        day(dayOfMonth: 1, precipitation: 6),
        day(dayOfMonth: 2, precipitation: 5),
        day(dayOfMonth: 3, precipitation: 4),
      ];

      expect(wetSpell.matches(windowOf(forecast)), isTrue);
    });

    test('does not match when the total falls short', () {
      final forecast = [
        day(dayOfMonth: 1, precipitation: 4),
        day(dayOfMonth: 2, precipitation: 4),
        day(dayOfMonth: 3, precipitation: 4),
      ];

      expect(wetSpell.matches(windowOf(forecast)), isFalse);
    });

    test('counts forward from the day being evaluated, not from the start', () {
      final forecast = [
        day(dayOfMonth: 1, precipitation: 0),
        day(dayOfMonth: 2, precipitation: 5),
        day(dayOfMonth: 3, precipitation: 5),
        day(dayOfMonth: 4, precipitation: 8),
      ];

      // From day 1: 0 + 5 + 5 = 10, short of 15.
      expect(wetSpell.matches(windowOf(forecast, 0)), isFalse);
      // From day 2: 5 + 5 + 8 = 18.
      expect(wetSpell.matches(windowOf(forecast, 1)), isTrue);
    });

    test('does not apply when the forecast is shorter than the span', () {
      // Comparing a two-day total against a three-day threshold would make the
      // last days of every forecast quietly safer than they are.
      final forecast = [
        day(dayOfMonth: 1, precipitation: 20),
        day(dayOfMonth: 2, precipitation: 20),
      ];

      expect(wetSpell.matches(windowOf(forecast, 0)), isFalse);
      expect(wetSpell.matches(windowOf(forecast, 1)), isFalse);
    });

    test('reports the total and the span it covers', () {
      final forecast = [
        day(dayOfMonth: 1, precipitation: 6),
        day(dayOfMonth: 2, precipitation: 5),
        day(dayOfMonth: 3, precipitation: 9),
      ];

      final observation = wetSpell.evaluate(windowOf(forecast)).observations.single;
      expect(observation.observed, 20);
      expect(observation.spanDays, 3);
    });

    test('a single-day span is just a threshold', () {
      const oneDay = SumOverDays(
        metric: WeatherMetric.precipitation,
        days: 1,
        comparator: Comparator.greaterThan,
        value: 5,
      );

      expect(oneDay.matches(single(day(precipitation: 6))), isTrue);
      expect(oneDay.matches(single(day(precipitation: 5))), isFalse);
    });
  });

  group('ConsecutiveDays', () {
    const threeHumidDays = ConsecutiveDays(
      days: 3,
      condition: MetricThreshold(
        metric: WeatherMetric.maxHumidity,
        comparator: Comparator.greaterThan,
        value: 85,
      ),
    );

    test('matches an unbroken run', () {
      final forecast = [
        for (var i = 1; i <= 3; i++) day(dayOfMonth: i, maxHumidity: 90),
      ];

      expect(threeHumidDays.matches(windowOf(forecast)), isTrue);
    });

    test('a single dry day in the middle breaks the run', () {
      final forecast = [
        day(dayOfMonth: 1, maxHumidity: 90),
        day(dayOfMonth: 2, maxHumidity: 50),
        day(dayOfMonth: 3, maxHumidity: 90),
      ];

      expect(threeHumidDays.matches(windowOf(forecast)), isFalse);
    });

    test('finds the run wherever it starts', () {
      final forecast = [
        day(dayOfMonth: 1, maxHumidity: 50),
        for (var i = 2; i <= 4; i++) day(dayOfMonth: i, maxHumidity: 90),
      ];

      expect(threeHumidDays.matches(windowOf(forecast, 0)), isFalse);
      expect(threeHumidDays.matches(windowOf(forecast, 1)), isTrue);
    });

    test('does not apply when too few days remain', () {
      final forecast = [
        for (var i = 1; i <= 3; i++) day(dayOfMonth: i, maxHumidity: 95),
      ];

      expect(threeHumidDays.matches(windowOf(forecast, 1)), isFalse);
      expect(threeHumidDays.matches(windowOf(forecast, 2)), isFalse);
    });

    test('collects an observation from every day of the run', () {
      final forecast = [
        day(dayOfMonth: 1, maxHumidity: 90),
        day(dayOfMonth: 2, maxHumidity: 91),
        day(dayOfMonth: 3, maxHumidity: 92),
      ];

      final result = threeHumidDays.evaluate(windowOf(forecast));

      expect(result.observations.map((o) => o.observed), [90, 91, 92]);
    });
  });

  group('AllOf', () {
    const both = AllOf([
      RangeOverlap.temperature(min: 15, max: 21),
      MetricThreshold(
        metric: WeatherMetric.maxHumidity,
        comparator: Comparator.greaterThan,
        value: 90,
      ),
    ]);

    test('needs every branch', () {
      expect(
        both.matches(single(day(
          minTemperature: 16,
          maxTemperature: 20,
          maxHumidity: 95,
        ))),
        isTrue,
      );
      expect(
        both.matches(single(day(
          minTemperature: 16,
          maxTemperature: 20,
          maxHumidity: 60,
        ))),
        isFalse,
      );
      expect(
        both.matches(single(day(
          minTemperature: 30,
          maxTemperature: 35,
          maxHumidity: 95,
        ))),
        isFalse,
      );
    });

    test('gathers observations from every branch', () {
      final result = both.evaluate(single(day(
        minTemperature: 16,
        maxTemperature: 20,
        maxHumidity: 95,
      )));

      expect(result.observations, hasLength(2));
    });

    test('explains nothing when one branch fails', () {
      final result = both.evaluate(single(day(
        minTemperature: 16,
        maxTemperature: 20,
        maxHumidity: 60,
      )));

      expect(result.observations, isEmpty);
    });
  });

  group('AnyOf', () {
    const either = AnyOf([
      MetricThreshold(
        metric: WeatherMetric.maxHumidity,
        comparator: Comparator.greaterThan,
        value: 90,
      ),
      MetricThreshold(
        metric: WeatherMetric.precipitation,
        comparator: Comparator.atLeast,
        value: 10,
      ),
    ]);

    test('one branch is enough', () {
      expect(either.matches(single(day(maxHumidity: 95))), isTrue);
      expect(either.matches(single(day(precipitation: 12))), isTrue);
    });

    test('no branch means no match', () {
      expect(
        either.matches(single(day(maxHumidity: 50, precipitation: 0))),
        isFalse,
      );
    });

    test('reports every branch that held, not just the first', () {
      final result = either.evaluate(
        single(day(maxHumidity: 95, precipitation: 12)),
      );

      expect(result.observations, hasLength(2));
    });
  });

  group('Not', () {
    const noRain = Not(
      MetricThreshold(
        metric: WeatherMetric.precipitation,
        comparator: Comparator.greaterThan,
        value: 0,
      ),
    );

    test('inverts its inner condition', () {
      expect(noRain.matches(single(day(precipitation: 0))), isTrue);
      expect(noRain.matches(single(day(precipitation: 3))), isFalse);
    });

    test('contributes no explanation', () {
      // "It did not rain" is not something a grower can act on.
      expect(noRain.evaluate(single(day(precipitation: 0))).observations, isEmpty);
    });

    test('double negation returns to the original', () {
      const twice = Not(noRain);

      expect(twice.matches(single(day(precipitation: 3))), isTrue);
      expect(twice.matches(single(day(precipitation: 0))), isFalse);
    });
  });

  group('MonthRange', () {
    const springFlight = MonthRange(fromMonth: 5, toMonth: 6);

    test('matches inside the range', () {
      expect(springFlight.matches(single(day(month: 5))), isTrue);
      expect(springFlight.matches(single(day(month: 6))), isTrue);
    });

    test('does not match outside it', () {
      expect(springFlight.matches(single(day(month: 4))), isFalse);
      expect(springFlight.matches(single(day(month: 7))), isFalse);
      expect(springFlight.matches(single(day(month: 9))), isFalse);
    });

    test('a range that wraps the year covers the turn of it', () {
      // Overwintering pests do not respect January the way a for-loop does.
      const overwinter = MonthRange(fromMonth: 10, toMonth: 3);

      expect(overwinter.wrapsYear, isTrue);
      for (final month in [10, 11, 12, 1, 2, 3]) {
        expect(overwinter.matches(single(day(month: month))), isTrue,
            reason: 'month $month should be inside 10–3');
      }
      for (final month in [4, 5, 6, 7, 8, 9]) {
        expect(overwinter.matches(single(day(month: month))), isFalse,
            reason: 'month $month should be outside 10–3');
      }
    });

    test('a single-month range matches only that month', () {
      const july = MonthRange(fromMonth: 7, toMonth: 7);

      expect(july.matches(single(day(month: 7))), isTrue);
      expect(july.matches(single(day(month: 6))), isFalse);
      expect(july.matches(single(day(month: 8))), isFalse);
    });

    test('reports no observation, because a month is not evidence', () {
      // The grower is shown *why* a crop is flagged. "It is May" explains
      // nothing on its own, so the calendar contributes no line to that list.
      final result = springFlight.evaluate(single(day(month: 5)));

      expect(result.matched, isTrue);
      expect(result.observations, isEmpty);
    });

    test('gates a weather condition to the season it belongs in', () {
      // The reason this condition exists: the same mild day means one thing in
      // May, when the fly is flying, and nothing at all in September.
      const flightWeather = AllOf([
        MonthRange(fromMonth: 5, toMonth: 6),
        MetricBand(
          metric: WeatherMetric.averageTemperature,
          min: 12,
          max: 22,
        ),
      ]);

      final mildDay = day(minTemperature: 12, maxTemperature: 20);
      expect(
        flightWeather.matches(single(day(
          month: 5,
          minTemperature: mildDay.minTemperature,
          maxTemperature: mildDay.maxTemperature,
        ))),
        isTrue,
      );
      expect(
        flightWeather.matches(single(day(
          month: 9,
          minTemperature: mildDay.minTemperature,
          maxTemperature: mildDay.maxTemperature,
        ))),
        isFalse,
      );
    });

    test('still explains itself through the weather it is paired with', () {
      const flightWeather = AllOf([
        MonthRange(fromMonth: 5, toMonth: 6),
        MetricBand(
          metric: WeatherMetric.averageTemperature,
          min: 12,
          max: 22,
        ),
      ]);

      final result = flightWeather.evaluate(
        single(day(month: 5, minTemperature: 12, maxTemperature: 20)),
      );

      expect(result.matched, isTrue);
      expect(result.observations, hasLength(1));
      expect(result.observations.single.metric,
          WeatherMetric.averageTemperature);
    });

    test('serializes', () {
      expect(springFlight.toJson(), {
        'type': 'monthRange',
        'fromMonth': 5,
        'toMonth': 6,
      });
    });
  });

  group('nesting', () {
    test('composes to arbitrary depth', () {
      const complex = AllOf([
        AnyOf([
          RangeOverlap.temperature(min: 15, max: 21),
          RangeOverlap.temperature(min: 26, max: 30),
        ]),
        Not(
          MetricThreshold(
            metric: WeatherMetric.precipitation,
            comparator: Comparator.greaterThan,
            value: 20,
          ),
        ),
        ConsecutiveDays(
          days: 2,
          condition: MetricThreshold(
            metric: WeatherMetric.maxHumidity,
            comparator: Comparator.atLeast,
            value: 80,
          ),
        ),
      ]);

      final favourable = [
        day(dayOfMonth: 1, minTemperature: 16, maxTemperature: 20, maxHumidity: 85),
        day(dayOfMonth: 2, minTemperature: 16, maxTemperature: 20, maxHumidity: 82),
      ];
      expect(complex.matches(windowOf(favourable)), isTrue);

      final tooWet = [
        day(
          dayOfMonth: 1,
          minTemperature: 16,
          maxTemperature: 20,
          maxHumidity: 85,
          precipitation: 25,
        ),
        day(dayOfMonth: 2, minTemperature: 16, maxTemperature: 20, maxHumidity: 82),
      ];
      expect(complex.matches(windowOf(tooWet)), isFalse);
    });
  });

  group('WeatherWindow', () {
    final forecast = [for (var i = 1; i <= 5; i++) day(dayOfMonth: i)];

    test('forward returns what exists rather than padding', () {
      expect(windowOf(forecast, 0).forward(3), hasLength(3));
      expect(windowOf(forecast, 3).forward(3), hasLength(2));
      expect(windowOf(forecast, 4).forward(3), hasLength(1));
    });

    test('remaining counts this day and the rest', () {
      expect(windowOf(forecast, 0).remaining, 5);
      expect(windowOf(forecast, 4).remaining, 1);
    });

    test('shifted returns null past either end', () {
      expect(windowOf(forecast, 0).shifted(-1), isNull);
      expect(windowOf(forecast, 4).shifted(1), isNull);
      expect(windowOf(forecast, 0).shifted(4)!.date, DateTime(2026, 8, 5));
    });

    test('over builds one window per day', () {
      final windows = WeatherWindow.over(forecast);

      expect(windows, hasLength(5));
      expect(windows.map((w) => w.index), [0, 1, 2, 3, 4]);
      expect(windows.first.date, DateTime(2026, 8));
    });
  });
}
