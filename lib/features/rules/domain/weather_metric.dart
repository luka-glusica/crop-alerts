import '../../weather/domain/daily_forecast.dart';

/// A value a rule can be written against.
///
/// Deliberately a closed set rather than free-form field names: rules may
/// eventually arrive from a server as JSON, and an unknown metric must be
/// rejected at parse time rather than silently evaluating to nothing.
enum WeatherMetric {
  minTemperature,
  maxTemperature,
  averageTemperature,
  minHumidity,
  maxHumidity,
  averageHumidity,
  precipitation;

  /// Reads this metric from a day's forecast.
  double read(DailyForecast day) {
    return switch (this) {
      WeatherMetric.minTemperature => day.minTemperature,
      WeatherMetric.maxTemperature => day.maxTemperature,
      WeatherMetric.averageTemperature => day.averageTemperature,
      WeatherMetric.minHumidity => day.minHumidity,
      WeatherMetric.maxHumidity => day.maxHumidity,
      WeatherMetric.averageHumidity => day.averageHumidity,
      WeatherMetric.precipitation => day.precipitation,
    };
  }

  /// The unit the metric is measured in, for formatting explanations.
  MetricUnit get unit {
    return switch (this) {
      WeatherMetric.minTemperature ||
      WeatherMetric.maxTemperature ||
      WeatherMetric.averageTemperature =>
        MetricUnit.celsius,
      WeatherMetric.minHumidity ||
      WeatherMetric.maxHumidity ||
      WeatherMetric.averageHumidity =>
        MetricUnit.percent,
      WeatherMetric.precipitation => MetricUnit.millimetres,
    };
  }

  /// Resolves a metric by its serialized name, or `null` if unknown.
  static WeatherMetric? byName(String name) {
    for (final metric in values) {
      if (metric.name == name) return metric;
    }
    return null;
  }
}

/// The unit a [WeatherMetric] is expressed in.
enum MetricUnit { celsius, percent, millimetres }

/// How an observed value is compared against a threshold.
enum Comparator {
  lessThan('<'),
  atMost('<='),
  greaterThan('>'),
  atLeast('>=');

  const Comparator(this.symbol);

  /// Rendered in explanations, e.g. `> 85`.
  final String symbol;

  bool test(double observed, double threshold) {
    return switch (this) {
      Comparator.lessThan => observed < threshold,
      Comparator.atMost => observed <= threshold,
      Comparator.greaterThan => observed > threshold,
      Comparator.atLeast => observed >= threshold,
    };
  }

  static Comparator? byName(String name) {
    for (final comparator in values) {
      if (comparator.name == name) return comparator;
    }
    return null;
  }
}
