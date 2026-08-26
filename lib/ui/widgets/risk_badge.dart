import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../features/rules/domain/risk.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';

/// Presentation for a [RiskLevel].
extension RiskLevelPresentation on RiskLevel {
  /// The colours this level is drawn in.
  RiskColors colorsFrom(AppPalette palette) {
    return switch (this) {
      RiskLevel.high => palette.riskHigh,
      RiskLevel.moderate => palette.riskModerate,
      RiskLevel.low => palette.riskLow,
    };
  }

  /// The localized name of this level.
  String labelFrom(AppLocalizations l10n) {
    return switch (this) {
      RiskLevel.high => l10n.riskHigh,
      RiskLevel.moderate => l10n.riskModerate,
      RiskLevel.low => l10n.riskLow,
    };
  }

  /// An icon, so the level does not rely on colour alone.
  IconData get icon {
    return switch (this) {
      RiskLevel.high => AppIcons.riskHigh,
      RiskLevel.moderate => AppIcons.riskModerate,
      RiskLevel.low => AppIcons.riskLow,
    };
  }
}

/// A pill showing a risk level, in the web version's style.
///
/// Carries an icon as well as a colour: roughly one man in twelve cannot
/// reliably separate the red and green these levels are drawn in.
class RiskBadge extends StatelessWidget {
  const RiskBadge({required this.level, this.dormant = false, super.key});

  final RiskLevel level;

  /// Overrides the level entirely, for a crop that is out of season.
  final bool dormant;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    final colors = dormant ? palette.dormant : level.colorsFrom(palette);
    final label = dormant ? l10n.riskOutOfSeason : level.labelFrom(l10n);
    final icon = dormant ? AppIcons.dormant : level.icon;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.foreground),
          const SizedBox(width: AppSpacing.s1),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}
