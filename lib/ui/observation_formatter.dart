import 'package:flutter/widgets.dart';

import '../features/rules/domain/rule_observation.dart';
import '../features/rules/domain/weather_metric.dart';
import '../l10n/generated/app_localizations.dart';
import 'icons/app_icons.dart';

/// Turns the rule engine's structured observations into readable sentences.
///
/// The engine deliberately produces data rather than text — no language, no
/// units — so this is where "maxHumidity 88 > 85" becomes
/// "najviša vlažnost 88% > 85%" or "maximum humidity 88% > 85%". Keeping the
/// two apart is what lets the same evaluation be shown in either language, and
/// lets the engine be tested without a localization delegate in sight.
class ObservationFormatter {
  const ObservationFormatter(this.l10n);

  final AppLocalizations l10n;

  /// A one-line explanation of why a rule matched.
  String describe(RuleObservation observation) {
    final metric = nameOf(observation.metric);
    final observed = valueOf(observation.metric, observation.observed);

    return switch (observation.requirement) {
      ThresholdRequirement(:final comparator, :final value) =>
        observation.spanDays > 1
            ? l10n.observationOverDays(
                metric,
                observed,
                observation.spanDays,
                comparator.symbol,
                valueOf(observation.metric, value),
              )
            : l10n.observationThreshold(
                metric,
                observed,
                comparator.symbol,
                valueOf(observation.metric, value),
              ),
      BandRequirement(:final min, :final max) => l10n.observationBand(
          metric,
          observed,
          valueOf(observation.metric, min),
          valueOf(observation.metric, max),
        ),
    };
  }

  /// The icon that goes with a metric, so a list of readings can be scanned
  /// by shape rather than read line by line.
  IconData iconOf(WeatherMetric metric) {
    return switch (metric.unit) {
      MetricUnit.celsius => AppIcons.temperature,
      MetricUnit.percent => AppIcons.humidity,
      MetricUnit.millimetres => AppIcons.precipitation,
    };
  }

  /// The localized name of a metric.
  String nameOf(WeatherMetric metric) {
    return switch (metric) {
      WeatherMetric.minTemperature => l10n.metricMinTemperature,
      WeatherMetric.maxTemperature => l10n.metricMaxTemperature,
      WeatherMetric.averageTemperature => l10n.metricAverageTemperature,
      WeatherMetric.minHumidity => l10n.metricMinHumidity,
      WeatherMetric.maxHumidity => l10n.metricMaxHumidity,
      WeatherMetric.averageHumidity => l10n.metricAverageHumidity,
      WeatherMetric.precipitation => l10n.metricPrecipitation,
    };
  }

  /// A value with the unit its metric is measured in.
  String valueOf(WeatherMetric metric, double value) {
    final formatted = _trim(value);
    return switch (metric.unit) {
      MetricUnit.celsius => l10n.degreesCelsius(formatted),
      MetricUnit.percent => l10n.percent(formatted),
      MetricUnit.millimetres => l10n.millimetres(formatted),
    };
  }

  /// One decimal, but only when it says something: thresholds are usually
  /// whole numbers and "85.0%" reads worse than "85%".
  static String _trim(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toStringAsFixed(1);
  }
}
