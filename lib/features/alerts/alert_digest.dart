import 'package:flutter/foundation.dart';

import '../crops/domain/crop_assessment.dart';
import '../rules/domain/risk.dart';
import 'notification_preferences.dart';

/// A summary of what is coming, ready to become one notification.
@immutable
class AlertDigest {
  const AlertDigest({
    required this.level,
    required this.highCount,
    required this.moderateCount,
    required this.cropNames,
    required this.horizonEnd,
  });

  /// The worst level in the digest.
  final RiskLevel level;

  /// How many crop-days reached high and moderate risk in the horizon.
  final int highCount;
  final int moderateCount;

  /// The crops involved, worst first, without repeats.
  final List<String> cropNames;

  /// The last day the digest covers.
  final DateTime horizonEnd;

  /// Identifies this alert, so the same news is not delivered twice.
  ///
  /// Built from the content rather than only the date: if the forecast worsens
  /// during the day, that is new information and worth a second notification,
  /// whereas the same outlook re-evaluated six hours later is not.
  String get dedupeKey =>
      '${level.name}|$highCount|$moderateCount|${cropNames.join(",")}';

  /// Builds the digest for the next [horizonDays] days.
  ///
  /// Only days from [today] onward count: a forecast that starts yesterday
  /// should not raise an alarm about weather that has already passed.
  static AlertDigest? build({
    required List<CropAssessment> assessments,
    required NotificationPreferences preferences,
    required DateTime today,
    int horizonDays = 5,
  }) {
    if (!preferences.anyEnabled) return null;

    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: horizonDays - 1));

    var high = 0;
    var moderate = 0;
    final byCrop = <String, RiskLevel>{};

    for (final assessment in assessments) {
      for (final day in assessment.days) {
        if (day.date.isBefore(start) || day.date.isAfter(end)) continue;
        if (!day.inSeason) continue;

        final level = day.risk.level;
        if (!preferences.wants(level)) continue;

        if (level == RiskLevel.high) {
          high++;
        } else if (level == RiskLevel.moderate) {
          moderate++;
        }

        final existing = byCrop[assessment.crop.name];
        if (existing == null || level > existing) {
          byCrop[assessment.crop.name] = level;
        }
      }
    }

    if (byCrop.isEmpty) return null;

    final names = byCrop.keys.toList()
      ..sort((a, b) {
        final bySeverity = byCrop[b]!.severity.compareTo(byCrop[a]!.severity);
        return bySeverity != 0 ? bySeverity : a.compareTo(b);
      });

    return AlertDigest(
      level: high > 0 ? RiskLevel.high : RiskLevel.moderate,
      highCount: high,
      moderateCount: moderate,
      cropNames: names,
      horizonEnd: end,
    );
  }
}
