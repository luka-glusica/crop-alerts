import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/flags.dart';
import '../../core/l10n/date_formats.dart';
import '../../core/theme/theme.dart';
import '../../features/crops/domain/crop_assessment.dart';
import '../../features/crops/domain/threat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import '../observation_formatter.dart';
import '../widgets/app_card.dart';
import '../widgets/crop_avatar.dart';
import '../widgets/risk_badge.dart';

/// Everything the app knows about one crop: what is coming, why it thinks so,
/// and what to do about it.
class CropDetailScreen extends StatefulWidget {
  const CropDetailScreen({required this.assessment, super.key});

  final CropAssessment assessment;

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  late int _selectedDay = _defaultDay();

  /// Opens on the worst day rather than today: a grower who taps through from a
  /// high-risk card is asking about the risk, not about this morning.
  int _defaultDay() {
    final days = widget.assessment.days;
    var best = 0;
    var bestSeverity = -1;
    for (var i = 0; i < days.length; i++) {
      final severity = days[i].risk.level.severity;
      if (severity > bestSeverity) {
        bestSeverity = severity;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formats = ForecastDateFormats.of(Localizations.localeOf(context), l10n);
    final assessment = widget.assessment;
    final days = assessment.days;

    return Scaffold(
      appBar: AppBar(title: Text(assessment.crop.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s2,
          AppSpacing.s4,
          AppSpacing.s12,
        ),
        children: [
          _Header(assessment: assessment, formats: formats),
          if (assessment.isDormant) ...[
            const SizedBox(height: AppSpacing.s3),
            _Notice(text: l10n.outOfSeasonNotice, icon: AppIcons.dormant),
          ],
          if (days.isNotEmpty && !assessment.isDormant) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(l10n.selectDay.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.s2),
            _DaySelector(
              days: days,
              formats: formats,
              selected: _selectedDay,
              onSelected: (index) => setState(() => _selectedDay = index),
            ),
            const SizedBox(height: AppSpacing.s4),
            _DayDetail(day: days[_selectedDay], formats: formats),
          ],
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.allThreats.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.s2),
          for (final type in ThreatType.values)
            _ThreatGroup(
              type: type,
              threats: assessment.crop.threatsOfType(type),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.assessment, required this.formats});

  final CropAssessment assessment;
  final ForecastDateFormats formats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final season = assessment.crop.season;

    return AppCard(
      child: Row(
        children: [
          CropAvatar(
            cropId: assessment.crop.id,
            size: 64,
            semanticLabel: assessment.crop.name,
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assessment.crop.name, style: text.titleMedium),
                const SizedBox(height: AppSpacing.s1),
                Row(
                  children: [
                    Icon(AppIcons.season, size: 14, color: context.palette.textMuted),
                    const SizedBox(width: AppSpacing.s1),
                    Expanded(
                      child: Text(
                        l10n.growingSeason(
                          formats.monthName(season.fromMonth),
                          formats.monthName(season.toMonth),
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                RiskBadge(
                  level: assessment.overall,
                  dormant: assessment.isDormant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrollable row of days, coloured by risk.
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.formats,
    required this.selected,
    required this.onSelected,
  });

  final List<CropDayAssessment> days;
  final ForecastDateFormats formats;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final day = days[index];
          final colors = day.inSeason
              ? day.risk.level.colorsFrom(palette)
              : palette.dormant;
          final isSelected = index == selected;

          return Semantics(
            selected: isSelected,
            label: '${formats.dayLabel(day.date)}, '
                '${day.inSeason ? day.risk.level.labelFrom(l10n) : l10n.riskOutOfSeason}',
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: AppRadii.xlAll,
              child: Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: AppRadii.xlAll,
                  border: Border.all(
                    color: isSelected ? colors.foreground : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formats.shortWeekday(day.date),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.foreground),
                    ),
                    Text(
                      '${day.date.day}.',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: colors.foreground),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What is threatening the crop on the selected day, why, and what to do.
class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.formats});

  final CropDayAssessment day;
  final ForecastDateFormats formats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formats.dayLabel(day.date), style: text.titleSmall),
        const SizedBox(height: AppSpacing.s3),
        if (day.threats.isEmpty)
          _Notice(text: l10n.noRiskToday, icon: AppIcons.riskLow)
        else
          for (final threat in day.threats) ...[
            _ThreatDetail(threat: threat),
            const SizedBox(height: AppSpacing.s3),
          ],
      ],
    );
  }
}

class _ThreatDetail extends ConsumerWidget {
  const _ThreatDetail({required this.threat});

  final AssessedThreat threat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final formatter = ObservationFormatter(l10n);
    final colors = threat.level.colorsFrom(palette);

    final observations = [
      for (final match in threat.matches) ...match.observations,
    ];

    return AppCard(
      borderColor: colors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(threat.threat.type.icon, size: 18, color: colors.foreground),
              const SizedBox(width: AppSpacing.s2),
              Expanded(child: Text(threat.threat.name, style: text.titleSmall)),
              RiskBadge(level: threat.level),
            ],
          ),
          if (threat.threat.description != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(threat.threat.description!, style: text.bodyMedium),
          ],

          if (observations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(l10n.whyThisRisk.toUpperCase(), style: text.labelSmall),
            const SizedBox(height: AppSpacing.s1),
            // The readings that actually triggered the rules, so the verdict
            // can be checked rather than taken on faith.
            for (final observation in observations)
              _Bullet(
                icon: formatter.iconOf(observation.metric),
                text: formatter.describe(observation),
                color: colors.foreground,
              ),
          ],

          if (threat.threat.response.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(l10n.response.toUpperCase(), style: text.labelSmall),
            const SizedBox(height: AppSpacing.s1),
            for (final step in threat.threat.response)
              _Bullet(icon: AppIcons.response, text: step),
          ],

          // Rating whether the advice worked is a later release; the code path
          // exists so switching the flag on is a matter of implementing the
          // repository, not reshaping this screen.
          FlagGate(
            flag: FeatureFlag.mitigationRatings,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.ratingPrompt, style: text.bodySmall)),
                  TextButton(onPressed: () {}, child: Text(l10n.ratingHelped)),
                  TextButton(
                    onPressed: () {},
                    child: Text(l10n.ratingDidNotHelp),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The crop's full threat catalogue, grouped by kind, with prevention advice.
class _ThreatGroup extends StatelessWidget {
  const _ThreatGroup({required this.type, required this.threats});

  final ThreatType type;
  final List<Threat> threats;

  @override
  Widget build(BuildContext context) {
    if (threats.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon, size: 16, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text(type.labelFrom(l10n), style: text.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          for (final threat in threats)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(threat.name, style: text.titleSmall),
                    if (threat.description != null) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(threat.description!, style: text.bodySmall),
                    ],
                    if (threat.prevention.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Text(l10n.prevention.toUpperCase(), style: text.labelSmall),
                      const SizedBox(height: AppSpacing.s1),
                      for (final step in threat.prevention)
                        _Bullet(icon: AppIcons.prevention, text: step),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Presentation for a [ThreatType].
extension ThreatTypePresentation on ThreatType {
  IconData get icon {
    return switch (this) {
      ThreatType.fungalDisease => AppIcons.fungalDisease,
      ThreatType.pest => AppIcons.pest,
      ThreatType.other => AppIcons.otherProblem,
    };
  }

  String labelFrom(AppLocalizations l10n) {
    return switch (this) {
      ThreatType.fungalDisease => l10n.threatFungalDisease,
      ThreatType.pest => l10n.threatPest,
      ThreatType.other => l10n.threatOther,
    };
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 14, color: color ?? palette.textMuted),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadii.xlAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
