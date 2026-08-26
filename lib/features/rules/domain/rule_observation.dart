import 'package:flutter/foundation.dart';

import 'weather_metric.dart';

/// What a condition required of a value.
sealed class Requirement {
  const Requirement();
}

/// A comparison against a single number, e.g. `> 85`.
class ThresholdRequirement extends Requirement {
  const ThresholdRequirement(this.comparator, this.value);

  final Comparator comparator;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ThresholdRequirement &&
      other.comparator == comparator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(comparator, value);

  @override
  String toString() => '${comparator.symbol} $value';
}

/// A closed band, e.g. `15–25`.
class BandRequirement extends Requirement {
  const BandRequirement(this.min, this.max);

  final double min;
  final double max;

  @override
  bool operator ==(Object other) =>
      other is BandRequirement && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => '$min–$max';
}

/// One reason a rule matched: what was required, and what was actually forecast.
///
/// The engine produces these instead of finished sentences so that it stays
/// free of language and units — the same match reads as
/// "vlažnost 88% > 85%" or "humidity 88% > 85%" depending on who is looking.
@immutable
class RuleObservation {
  const RuleObservation({
    required this.metric,
    required this.observed,
    required this.requirement,
    this.spanDays = 1,
  });

  final WeatherMetric metric;

  /// The value the forecast actually gave, aggregated over [spanDays].
  final double observed;

  final Requirement requirement;

  /// How many days the observation covers. `1` for a single day.
  final int spanDays;

  @override
  bool operator ==(Object other) =>
      other is RuleObservation &&
      other.metric == metric &&
      other.observed == observed &&
      other.requirement == requirement &&
      other.spanDays == spanDays;

  @override
  int get hashCode => Object.hash(metric, observed, requirement, spanDays);

  @override
  String toString() =>
      '${metric.name} $observed ${spanDays > 1 ? 'over ${spanDays}d ' : ''}'
      '($requirement)';
}
