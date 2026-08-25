import 'package:flutter/foundation.dart';

import '../../rules/domain/risk.dart';
import 'crop.dart';
import 'threat.dart';

/// What the rule engine concluded about one crop, over the forecast.
@immutable
class CropAssessment {
  const CropAssessment({
    required this.crop,
    required this.days,
    required this.overall,
  });

  final Crop crop;

  /// One entry per forecast day, in order. Days outside the growing season are
  /// present but carry no risk, so the timeline stays continuous.
  final List<CropDayAssessment> days;

  /// The worst level across the days that are in season.
  final RiskLevel overall;

  /// Whether the crop is out of season for the whole forecast.
  ///
  /// The dashboard collapses these rather than listing a page of crops with
  /// nothing to say.
  bool get isDormant => days.isNotEmpty && days.every((d) => !d.inSeason);

  /// Whether the crop is in season today, the first day of the forecast.
  bool get isInSeasonNow => days.isNotEmpty && days.first.inSeason;

  bool get hasRisk => overall > RiskLevel.low;

  /// Days worth a grower's attention, worst first.
  List<CropDayAssessment> get daysAtRisk {
    final risky = days.where((d) => d.risk.hasRisk).toList()
      ..sort((a, b) {
        final bySeverity = b.risk.level.severity.compareTo(a.risk.level.severity);
        return bySeverity != 0 ? bySeverity : a.date.compareTo(b.date);
      });
    return risky;
  }
}

/// One crop on one day.
@immutable
class CropDayAssessment {
  const CropDayAssessment({
    required this.date,
    required this.inSeason,
    required this.risk,
    required this.threats,
  });

  final DateTime date;

  /// Whether the crop is in the ground on this date.
  final bool inSeason;

  final DayRisk risk;

  /// The threats behind [risk], resolved from ids to the real thing so the UI
  /// has names and advice to hand.
  final List<AssessedThreat> threats;
}

/// A threat that fired, with its definition attached.
@immutable
class AssessedThreat {
  const AssessedThreat({
    required this.threat,
    required this.level,
    required this.score,
    required this.matches,
  });

  final Threat threat;
  final RiskLevel level;
  final int score;

  /// The rules that fired, carrying the readings behind them.
  final List<RuleMatch> matches;
}
