import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../features/crops/domain/crop_assessment.dart';
import '../../l10n/generated/app_localizations.dart';
import 'risk_badge.dart';

/// A compact ten-day risk timeline for one crop.
///
/// Reading a whole forecast at a glance is the point of the dashboard, so each
/// day is a single bar rather than a row of text.
class RiskStrip extends StatelessWidget {
  const RiskStrip({
    required this.days,
    this.height = 28,
    this.onDayTapped,
    super.key,
  });

  final List<CropDayAssessment> days;
  final double height;
  final void Function(CropDayAssessment day)? onDayTapped;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Semantics(
                  label: day.inSeason
                      ? day.risk.level.labelFrom(l10n)
                      : l10n.riskOutOfSeason,
                  child: GestureDetector(
                    onTap: onDayTapped == null ? null : () => onDayTapped!(day),
                    // SizedBox.expand, because a GestureDetector passes loose
                    // constraints down and a childless DecoratedBox then
                    // collapses to zero height and paints nothing.
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: day.inSeason
                              ? day.risk.level.colorsFrom(palette).accent
                              : palette.dormant.background,
                          borderRadius: AppRadii.lgAll,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
