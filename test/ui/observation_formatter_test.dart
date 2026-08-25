import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/features/rules/domain/rule_observation.dart';
import 'package:crop_alerts/features/rules/domain/weather_metric.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/observation_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ObservationFormatter sr;
  late ObservationFormatter en;

  setUpAll(() async {
    sr = ObservationFormatter(
      await AppLocalizations.delegate.load(LocaleController.serbianLatin),
    );
    en = ObservationFormatter(
      await AppLocalizations.delegate.load(LocaleController.english),
    );
  });

  group('thresholds', () {
    const humidity = RuleObservation(
      metric: WeatherMetric.maxHumidity,
      observed: 88,
      requirement: ThresholdRequirement(Comparator.greaterThan, 85),
    );

    test('reads as a comparison with units in Serbian', () {
      expect(sr.describe(humidity), 'najviša vlažnost 88% > 85%');
    });

    test('and in English', () {
      expect(en.describe(humidity), 'maximum humidity 88% > 85%');
    });

    test('carries the comparator that was actually used', () {
      const atLeast = RuleObservation(
        metric: WeatherMetric.minTemperature,
        observed: 15,
        requirement: ThresholdRequirement(Comparator.atLeast, 15),
      );

      expect(sr.describe(atLeast), contains('>='));
    });
  });

  group('bands', () {
    const temperature = RuleObservation(
      metric: WeatherMetric.minTemperature,
      observed: 16,
      requirement: BandRequirement(15, 21),
    );

    test('reads as a range in Serbian', () {
      expect(sr.describe(temperature), 'najniža temperatura 16°C, u opsegu 15°C – 21°C');
    });

    test('and in English', () {
      expect(
        en.describe(temperature),
        'minimum temperature 16°C, within 15°C – 21°C',
      );
    });
  });

  group('multi-day totals', () {
    const rain = RuleObservation(
      metric: WeatherMetric.precipitation,
      observed: 20,
      requirement: ThresholdRequirement(Comparator.atLeast, 15),
      spanDays: 3,
    );

    test('name the span they cover', () {
      expect(sr.describe(rain), contains('za 3 dana'));
      expect(sr.describe(rain), contains('20 mm'));
      expect(en.describe(rain), contains('over 3 days'));
    });

    test('use the singular for one day', () {
      const single = RuleObservation(
        metric: WeatherMetric.precipitation,
        observed: 8,
        requirement: ThresholdRequirement(Comparator.atLeast, 5),
        spanDays: 1,
      );

      // A one-day span is not a span at all, so it reads as a plain threshold.
      expect(sr.describe(single), isNot(contains('dan')));
      expect(en.describe(single), isNot(contains('day')));
    });
  });

  group('units follow the metric', () {
    test('temperatures in degrees, humidity in percent, rain in millimetres',
        () {
      expect(sr.valueOf(WeatherMetric.maxTemperature, 21), '21°C');
      expect(sr.valueOf(WeatherMetric.averageTemperature, 21), '21°C');
      expect(sr.valueOf(WeatherMetric.minHumidity, 60), '60%');
      expect(sr.valueOf(WeatherMetric.precipitation, 15), '15 mm');
    });

    test('every metric has a name in both languages', () {
      for (final metric in WeatherMetric.values) {
        expect(sr.nameOf(metric), isNotEmpty);
        expect(en.nameOf(metric), isNotEmpty);
        expect(
          sr.nameOf(metric),
          isNot(en.nameOf(metric)),
          reason: '${metric.name} was not translated',
        );
      }
    });
  });

  group('icons', () {
    test('follow the unit, so readings scan by shape', () {
      expect(
        sr.iconOf(WeatherMetric.maxTemperature),
        isNot(sr.iconOf(WeatherMetric.precipitation)),
      );
      expect(
        sr.iconOf(WeatherMetric.minHumidity),
        isNot(sr.iconOf(WeatherMetric.maxTemperature)),
      );
      expect(
        sr.iconOf(WeatherMetric.minTemperature),
        sr.iconOf(WeatherMetric.maxTemperature),
      );
    });
  });

  group('number formatting', () {
    test('drops a pointless decimal', () {
      // "85.0%" reads worse than "85%", and thresholds are usually whole.
      expect(sr.valueOf(WeatherMetric.maxHumidity, 85), '85%');
      expect(sr.valueOf(WeatherMetric.maxHumidity, 85.04), '85%');
    });

    test('keeps a decimal that says something', () {
      expect(sr.valueOf(WeatherMetric.maxTemperature, 31.9), '31.9°C');
      expect(sr.valueOf(WeatherMetric.precipitation, 9.3), '9.3 mm');
    });
  });
}
