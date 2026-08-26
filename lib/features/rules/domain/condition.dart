import 'package:flutter/foundation.dart';

import 'rule_observation.dart';
import 'weather_metric.dart';
import 'weather_window.dart';

/// A test applied to a day of the forecast.
///
/// Conditions compose: `AllOf`, `AnyOf` and `Not` wrap other conditions, and
/// `ConsecutiveDays` and `SumOverDays` reach across days. Every node
/// serializes, which is what lets rules eventually arrive from a server —
/// crowd-sourced or corrected — without shipping a new build.
///
/// All but one leaf ask about the weather. `MonthRange` asks about the
/// calendar, because an insect's flight period is a fact about the year rather
/// than about the sky.
///
/// `evaluate` returns the observations behind a match rather than a bare bool,
/// so the app can show a grower *why* a crop is flagged instead of only that it
/// is.
@immutable
sealed class Condition {
  const Condition();

  /// Evaluates this condition against [window].
  ConditionResult evaluate(WeatherWindow window);

  /// Whether this condition holds. Shorthand for `evaluate(window).matched`.
  bool matches(WeatherWindow window) => evaluate(window).matched;

  /// The discriminator written to JSON.
  String get type;

  Map<String, dynamic> toJson();
}

/// The outcome of evaluating a [Condition].
@immutable
class ConditionResult {
  const ConditionResult({required this.matched, this.observations = const []});

  /// A match with nothing worth explaining.
  static const ConditionResult noMatch = ConditionResult(matched: false);

  final bool matched;

  /// What was observed, populated only when [matched] is true.
  ///
  /// A condition that did not match explains nothing: the interesting question
  /// is why a crop *is* at risk, never why it is not.
  final List<RuleObservation> observations;
}

/// Compares one metric against a threshold, e.g. `maxHumidity > 85`.
class MetricThreshold extends Condition {
  const MetricThreshold({
    required this.metric,
    required this.comparator,
    required this.value,
  });

  final WeatherMetric metric;
  final Comparator comparator;
  final double value;

  @override
  String get type => 'metricThreshold';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final observed = window.read(metric);
    if (!comparator.test(observed, value)) return ConditionResult.noMatch;

    return ConditionResult(
      matched: true,
      observations: [
        RuleObservation(
          metric: metric,
          observed: observed,
          requirement: ThresholdRequirement(comparator, value),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'metric': metric.name,
        'comparator': comparator.name,
        'value': value,
      };
}

/// Whether one metric falls inside a closed band, e.g. `averageTemperature`
/// between 15 and 25.
class MetricBand extends Condition {
  const MetricBand({
    required this.metric,
    required this.min,
    required this.max,
  });

  final WeatherMetric metric;
  final double min;
  final double max;

  @override
  String get type => 'metricBand';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final observed = window.read(metric);
    if (observed < min || observed > max) return ConditionResult.noMatch;

    return ConditionResult(
      matched: true,
      observations: [
        RuleObservation(
          metric: metric,
          observed: observed,
          requirement: BandRequirement(min, max),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'metric': metric.name,
        'min': min,
        'max': max,
      };
}

/// Whether the day's own range overlaps a favourable band.
///
/// This is the semantics a grower means by "15–25°C suits late blight": not
/// that the whole day sat in that band, but that the temperature passed through
/// it at some point. The web version of this app tests exactly this, comparing
/// the day's min and max against the band's edges.
class RangeOverlap extends Condition {
  const RangeOverlap({
    required this.lower,
    required this.upper,
    required this.min,
    required this.max,
  });

  /// The metric giving the low end of the day's own range.
  final WeatherMetric lower;

  /// The metric giving the high end of the day's own range.
  final WeatherMetric upper;

  /// The favourable band.
  final double min;
  final double max;

  /// Convenience for the common temperature case.
  const RangeOverlap.temperature({required double min, required double max})
      : this(
          lower: WeatherMetric.minTemperature,
          upper: WeatherMetric.maxTemperature,
          min: min,
          max: max,
        );

  /// Convenience for the common humidity case.
  const RangeOverlap.humidity({required double min, required double max})
      : this(
          lower: WeatherMetric.minHumidity,
          upper: WeatherMetric.maxHumidity,
          min: min,
          max: max,
        );

  @override
  String get type => 'rangeOverlap';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final low = window.read(lower);
    final high = window.read(upper);
    if (low > max || high < min) return ConditionResult.noMatch;

    // Report the end of the day's range that actually sits in the band, since
    // that is the number a grower would look for.
    final observed = low >= min ? low : (high <= max ? high : min);

    return ConditionResult(
      matched: true,
      observations: [
        RuleObservation(
          metric: low >= min ? lower : upper,
          observed: observed,
          requirement: BandRequirement(min, max),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'lower': lower.name,
        'upper': upper.name,
        'min': min,
        'max': max,
      };
}

/// Totals a metric across several days, e.g. 15 mm of rain over three days.
class SumOverDays extends Condition {
  const SumOverDays({
    required this.metric,
    required this.days,
    required this.comparator,
    required this.value,
  }) : assert(days >= 1, 'a span must cover at least one day');

  final WeatherMetric metric;

  /// How many days to total, starting with the day being evaluated.
  final int days;

  final Comparator comparator;
  final double value;

  @override
  String get type => 'sumOverDays';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final span = window.forward(days);
    // Near the end of the forecast there may be fewer days than asked for.
    // Totalling what exists would compare a partial sum against a threshold
    // meant for a full span, so the condition simply does not apply.
    if (span.length < days) return ConditionResult.noMatch;

    final total = span.fold<double>(0, (sum, day) => sum + metric.read(day));
    if (!comparator.test(total, value)) return ConditionResult.noMatch;

    return ConditionResult(
      matched: true,
      observations: [
        RuleObservation(
          metric: metric,
          observed: total,
          requirement: ThresholdRequirement(comparator, value),
          spanDays: days,
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'metric': metric.name,
        'days': days,
        'comparator': comparator.name,
        'value': value,
      };
}

/// Whether [condition] holds on this day and the [days] - 1 that follow.
class ConsecutiveDays extends Condition {
  const ConsecutiveDays({required this.days, required this.condition})
      : assert(days >= 1, 'a run must cover at least one day');

  final int days;
  final Condition condition;

  @override
  String get type => 'consecutiveDays';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    if (window.remaining < days) return ConditionResult.noMatch;

    final observations = <RuleObservation>[];
    for (var offset = 0; offset < days; offset++) {
      final shifted = window.shifted(offset);
      if (shifted == null) return ConditionResult.noMatch;

      final result = condition.evaluate(shifted);
      if (!result.matched) return ConditionResult.noMatch;
      observations.addAll(result.observations);
    }

    return ConditionResult(matched: true, observations: observations);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'days': days,
        'condition': condition.toJson(),
      };
}

/// Whether the day falls inside a range of months.
///
/// Insect rules need this. "Carrot fly's first generation flies in May and
/// June" is not a statement about temperature, and a rule that fires whenever
/// the weather merely resembles May will warn about a pest that is still a pupa
/// in the soil.
///
/// Ranges wrap the year exactly as `GrowingSeason` does, so `fromMonth: 10,
/// toMonth: 3` covers October through March rather than nothing at all. The
/// logic is duplicated rather than shared because `GrowingSeason` belongs to
/// the crops feature, which already depends on this one.
///
/// A match reports no observations. `RuleObservation` describes a measurement
/// against a requirement, and a month is neither; more to the point, "it is
/// May" is not evidence a grower can weigh — the weather that came with May is.
/// So a `MonthRange` must never be a rule's only condition, or the rule would
/// flag a crop with nothing to show for it. Compose it inside an [AllOf]
/// alongside the weather that matters.
class MonthRange extends Condition {
  const MonthRange({required this.fromMonth, required this.toMonth})
      : assert(fromMonth >= 1 && fromMonth <= 12, 'fromMonth must be 1–12'),
        assert(toMonth >= 1 && toMonth <= 12, 'toMonth must be 1–12');

  /// First month of the range, 1–12.
  final int fromMonth;

  /// Last month of the range, inclusive, 1–12.
  final int toMonth;

  /// Whether the range runs across the turn of the year.
  bool get wrapsYear => fromMonth > toMonth;

  @override
  String get type => 'monthRange';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final month = window.date.month;
    final inRange = wrapsYear
        ? month >= fromMonth || month <= toMonth
        : month >= fromMonth && month <= toMonth;

    return inRange
        ? const ConditionResult(matched: true)
        : ConditionResult.noMatch;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'fromMonth': fromMonth,
        'toMonth': toMonth,
      };
}

/// Every condition must hold.
class AllOf extends Condition {
  const AllOf(this.conditions);

  final List<Condition> conditions;

  @override
  String get type => 'allOf';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final observations = <RuleObservation>[];
    for (final condition in conditions) {
      final result = condition.evaluate(window);
      if (!result.matched) return ConditionResult.noMatch;
      observations.addAll(result.observations);
    }
    return ConditionResult(matched: true, observations: observations);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };
}

/// At least one condition must hold.
class AnyOf extends Condition {
  const AnyOf(this.conditions);

  final List<Condition> conditions;

  @override
  String get type => 'anyOf';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    final observations = <RuleObservation>[];
    var matched = false;
    for (final condition in conditions) {
      final result = condition.evaluate(window);
      if (result.matched) {
        matched = true;
        // Every branch that held is worth reporting, not just the first.
        observations.addAll(result.observations);
      }
    }
    return matched
        ? ConditionResult(matched: true, observations: observations)
        : ConditionResult.noMatch;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'conditions': conditions.map((c) => c.toJson()).toList(),
      };
}

/// The condition must not hold.
///
/// A negation has nothing to report — "it did not rain" is not an observation a
/// grower can act on — so it contributes no explanation.
class Not extends Condition {
  const Not(this.condition);

  final Condition condition;

  @override
  String get type => 'not';

  @override
  ConditionResult evaluate(WeatherWindow window) {
    return condition.matches(window)
        ? ConditionResult.noMatch
        : const ConditionResult(matched: true);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'condition': condition.toJson(),
      };
}
