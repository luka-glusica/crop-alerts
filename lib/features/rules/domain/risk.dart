import 'package:flutter/foundation.dart';

import 'rule.dart';
import 'rule_observation.dart';

/// How worried a grower should be.
enum RiskLevel {
  low,
  moderate,
  high;

  /// Ordering helper, so a list of risks can be sorted worst-first.
  int get severity => index;

  bool operator >(RiskLevel other) => severity > other.severity;
  bool operator >=(RiskLevel other) => severity >= other.severity;
  bool operator <(RiskLevel other) => severity < other.severity;
  bool operator <=(RiskLevel other) => severity <= other.severity;
}

/// A rule that fired, and the readings that made it fire.
@immutable
class RuleMatch {
  const RuleMatch({required this.rule, required this.observations});

  final Rule rule;

  /// What the forecast actually said, for showing the grower why.
  final List<RuleObservation> observations;
}

/// Turns a score into a [RiskLevel].
///
/// Kept as data rather than an `if` chain so the thresholds can be tuned — or
/// eventually supplied per crop — without touching the engine.
@immutable
class RiskScoring {
  const RiskScoring({this.moderateAt = 1, this.highAt = 2})
      : assert(highAt >= moderateAt, 'high must be at least as hard as moderate');

  /// Matches the web version: one favourable factor is moderate, two are high.
  static const RiskScoring standard = RiskScoring();

  final int moderateAt;
  final int highAt;

  RiskLevel levelFor(int score) {
    if (score >= highAt) return RiskLevel.high;
    if (score >= moderateAt) return RiskLevel.moderate;
    return RiskLevel.low;
  }
}

/// The risk from one threat, on one day.
@immutable
class ThreatRisk {
  const ThreatRisk({
    required this.threatId,
    required this.level,
    required this.score,
    required this.matches,
  });

  final String threatId;
  final RiskLevel level;

  /// Total weight of the rules that matched.
  final int score;

  final List<RuleMatch> matches;
}

/// Everything the engine concluded about one day.
@immutable
class DayRisk {
  const DayRisk({
    required this.date,
    required this.level,
    required this.threats,
  });

  final DateTime date;

  /// The worst of [threats]. A crop is as at risk as its most threatened part.
  final RiskLevel level;

  /// Per-threat detail, worst first. Threats scoring [RiskLevel.low] are
  /// omitted — a grower needs the problems, not a clean bill of health for
  /// every disease in the catalogue.
  final List<ThreatRisk> threats;

  bool get hasRisk => level > RiskLevel.low;
}
