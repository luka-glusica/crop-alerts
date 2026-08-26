import 'package:flutter/material.dart';

import '../../core/l10n/date_formats.dart';
import '../../core/theme/theme.dart';
import '../../features/crops/domain/crop_assessment.dart';
import '../../features/rules/domain/risk.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import 'app_card.dart';
import 'crop_avatar.dart';
import 'risk_badge.dart';
import 'risk_strip.dart';

/// One crop's standing on the dashboard: what it is, how worried to be, what
/// the threat is, and how the next ten days look.
class CropRiskCard extends StatelessWidget {
  const CropRiskCard({
    required this.assessment,
    required this.formats,
    this.onTap,
    super.key,
  });

  final CropAssessment assessment;
  final ForecastDateFormats formats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final dormant = assessment.isDormant;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s3),
      borderColor: assessment.hasRisk && !dormant
          ? assessment.overall.colorsFrom(palette).accent
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: dormant ? 0.5 : 1,
                child: CropAvatar(
                  cropId: assessment.crop.id,
                  semanticLabel: assessment.crop.name,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assessment.crop.name, style: text.titleSmall),
                    const SizedBox(height: AppSpacing.sHalf),
                    Text(
                      dormant
                          ? l10n.growingSeason(
                              formats.monthName(assessment.crop.season.fromMonth),
                              formats.monthName(assessment.crop.season.toMonth),
                            )
                          : _summary(l10n),
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              RiskBadge(level: assessment.overall, dormant: dormant),
            ],
          ),
          if (!dormant) ...[
            const SizedBox(height: AppSpacing.s3),
            RiskStrip(days: assessment.days),
            const SizedBox(height: AppSpacing.s1),
            Row(
              children: [
                Text(
                  assessment.days.isEmpty
                      ? ''
                      : formats.shortWeekday(assessment.days.first.date),
                  style: text.labelMedium,
                ),
                const Spacer(),
                // Both ends, so the strip reads as a range rather than leaving
                // a single label stranded under it.
                Text(
                  assessment.days.isEmpty
                      ? ''
                      : formats.shortWeekday(assessment.days.last.date),
                  style: text.labelMedium,
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.s1),
                  Icon(AppIcons.chevron, size: 14, color: palette.textMuted),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Names the threats actually driving the risk, rather than restating the
  /// level the badge already shows.
  String _summary(AppLocalizations l10n) {
    if (!assessment.hasRisk) return l10n.noRiskToday;

    final worst = assessment.daysAtRisk.first;
    final names = <String>[];
    for (final threat in worst.threats) {
      if (threat.level == RiskLevel.low) continue;
      if (!names.contains(threat.threat.name)) names.add(threat.threat.name);
    }
    if (names.isEmpty) return l10n.noRiskToday;

    final when = formats.dayLabel(worst.date).toLowerCase();
    return '${names.join(', ')} · $when';
  }
}
