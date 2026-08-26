import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/l10n/date_formats.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/crop_artwork.dart';
import '../widgets/crop_avatar.dart';
import 'locations_screen.dart';

/// A debug-only catalogue of every design token.
///
/// This exists so the palette, type scale, spacing and elevation can be checked
/// against the web app before any real screen is built on top of them. It is
/// not reachable from the shipped UI.
class StyleGalleryScreen extends StatelessWidget {
  const StyleGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design tokens'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.location),
            tooltip: 'Plots',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LocationsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          0,
          AppSpacing.s4,
          AppSpacing.s16,
        ),
        children: const [
          _Section(title: 'Language', child: _Language()),
          _Section(title: 'Logo and crops', child: _Artwork()),
          _Section(title: 'Icons', child: _Icons()),
          _Section(title: 'Colour ramps', child: _ColorRamps()),
          _Section(title: 'Risk states', child: _RiskStates()),
          _Section(title: 'Type scale', child: _TypeScale()),
          _Section(title: 'Spacing', child: _SpacingScale()),
          _Section(title: 'Radii', child: _RadiiScale()),
          _Section(title: 'Elevation', child: _ShadowScale()),
          _Section(title: 'Controls', child: _Controls()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.s3),
          child,
        ],
      ),
    );
  }
}

class _Language extends ConsumerWidget {
  const _Language();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider);
    final formats = ForecastDateFormats.of(
      Localizations.localeOf(context),
      l10n,
    );
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'sr', label: Text(l10n.languageSerbian)),
            ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
          ],
          selected: {selected.languageCode == 'sr' ? 'sr' : 'en'},
          onSelectionChanged: (values) {
            ref.read(localeProvider.notifier).setLocale(
                  values.first == 'sr'
                      ? LocaleController.serbianLatin
                      : LocaleController.english,
                );
          },
        ),
        const SizedBox(height: AppSpacing.s4),
        _Line(label: 'appTitle', value: l10n.appTitle),
        _Line(label: 'appTagline', value: l10n.appTagline),
        _Line(label: 'cropsAtRisk(0)', value: l10n.cropsAtRisk(0)),
        _Line(label: 'cropsAtRisk(1)', value: l10n.cropsAtRisk(1)),
        _Line(label: 'cropsAtRisk(3)', value: l10n.cropsAtRisk(3)),
        _Line(label: 'cropsAtRisk(7)', value: l10n.cropsAtRisk(7)),
        _Line(
          label: 'growingSeason',
          value: l10n.growingSeason(formats.monthName(3), formats.monthName(10)),
        ),
        _Line(label: 'dayLabel(today)', value: formats.dayLabel(now)),
        _Line(
          label: 'dayLabel(+3d)',
          value: formats.dayLabel(now.add(const Duration(days: 3))),
        ),
        _Line(label: 'timestamp', value: formats.timestamp(now)),
        _Line(label: 'attributionMet', value: l10n.attributionMet),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork();

  @override
  Widget build(BuildContext context) {
    // A crop with SVG artwork, a crop with an emoji, and an unknown crop that
    // falls back — so all three paths are visible side by side.
    const cropIds = [
      'paradajz',
      'krompir',
      'krastavac',
      'kupus',
      'luk',
      'zelena-salata',
      'praziluk',
      'nepoznato',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset('assets/logo.svg', width: 96, height: 96),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s3,
          runSpacing: AppSpacing.s3,
          children: [
            for (final id in cropIds)
              Column(
                children: [
                  CropAvatar(cropId: id, semanticLabel: id),
                  const SizedBox(height: AppSpacing.s1),
                  SizedBox(
                    width: 56,
                    child: Text(
                      id,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          '${CropArtwork.knownCropIds.length} crops have artwork; '
          'unknown ids fall back to a seedling.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Icons extends StatelessWidget {
  const _Icons();

  @override
  Widget build(BuildContext context) {
    const icons = <String, PhosphorIconData>{
      'temperature': AppIcons.temperature,
      'humidity': AppIcons.humidity,
      'precipitation': AppIcons.precipitation,
      'crop': AppIcons.crop,
      'fungalDisease': AppIcons.fungalDisease,
      'pest': AppIcons.pest,
      'prevention': AppIcons.prevention,
      'response': AppIcons.response,
      'season': AppIcons.season,
      'location': AppIcons.location,
      'refresh': AppIcons.refresh,
      'notifications': AppIcons.notifications,
      'settings': AppIcons.settings,
      'offline': AppIcons.offline,
    };
    final palette = context.palette;

    return Wrap(
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s3,
      children: [
        for (final entry in icons.entries)
          SizedBox(
            width: 72,
            child: Column(
              children: [
                Icon(entry.value, size: 28, color: palette.brand),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  entry.key,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ColorRamps extends StatelessWidget {
  const _ColorRamps();

  @override
  Widget build(BuildContext context) {
    const ramps = <String, ColorScale>{
      'emerald': AppColors.emerald,
      'green': AppColors.green,
      'amber': AppColors.amber,
      'red': AppColors.red,
      'stone': AppColors.stone,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in ramps.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.s1),
                ClipRRect(
                  borderRadius: AppRadii.lgAll,
                  child: Row(
                    children: [
                      for (final step in ColorScale.steps)
                        Expanded(
                          child: Container(
                            height: 40,
                            color: entry.value[step],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RiskStates extends StatelessWidget {
  const _RiskStates();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final states = <String, RiskColors>{
      'Visok rizik': palette.riskHigh,
      'Umeren rizik': palette.riskModerate,
      'Nizak rizik': palette.riskLow,
      'Van sezone': palette.dormant,
    };

    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final entry in states.entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: entry.value.background,
              borderRadius: AppRadii.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.value.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  entry.key,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: entry.value.foreground),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final samples = <String, TextStyle?>{
      'displaySmall / 36': text.displaySmall,
      'headlineMedium / 30': text.headlineMedium,
      'headlineSmall / 24': text.headlineSmall,
      'titleLarge / 20': text.titleLarge,
      'titleMedium / 18': text.titleMedium,
      'bodyLarge / 16': text.bodyLarge,
      'bodyMedium / 14': text.bodyMedium,
      'bodySmall / 12': text.bodySmall,
      'LABELSMALL / 12 WIDEST': text.labelSmall,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in samples.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: Text(entry.key, style: entry.value),
          ),
      ],
    );
  }
}

class _SpacingScale extends StatelessWidget {
  const _SpacingScale();

  @override
  Widget build(BuildContext context) {
    const steps = <String, double>{
      'sHalf': AppSpacing.sHalf,
      's1': AppSpacing.s1,
      's2': AppSpacing.s2,
      's3': AppSpacing.s3,
      's4': AppSpacing.s4,
      's6': AppSpacing.s6,
      's8': AppSpacing.s8,
      's12': AppSpacing.s12,
      's16': AppSpacing.s16,
    };
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in steps.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s1),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Container(
                  width: entry.value,
                  height: 16,
                  color: palette.brand,
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  '${entry.value.toInt()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RadiiScale extends StatelessWidget {
  const _RadiiScale();

  @override
  Widget build(BuildContext context) {
    const radii = <String, double>{
      'lg': AppRadii.lg,
      'xl': AppRadii.xl,
      '2xl': AppRadii.xl2,
      '3xl': AppRadii.xl3,
      'full': AppRadii.full,
    };
    final palette = context.palette;

    return Wrap(
      spacing: AppSpacing.s3,
      runSpacing: AppSpacing.s3,
      children: [
        for (final entry in radii.entries)
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.brandMuted,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(entry.value),
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(entry.key, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}

class _ShadowScale extends StatelessWidget {
  const _ShadowScale();

  @override
  Widget build(BuildContext context) {
    const shadows = <String, List<BoxShadow>>{
      'sm': AppShadows.sm,
      'base': AppShadows.base,
      'md': AppShadows.md,
      'lg': AppShadows.lg,
      'xl': AppShadows.xl,
    };
    final palette = context.palette;

    return Wrap(
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s6,
      children: [
        for (final entry in shadows.entries)
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: AppRadii.xlAll,
                  boxShadow: entry.value,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(entry.key, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Osveži prognozu')),
            OutlinedButton(onPressed: () {}, child: const Text('Dodaj lokaciju')),
            TextButton(onPressed: () {}, child: const Text('Detaljnije')),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        const TextField(
          decoration: InputDecoration(labelText: 'Geografska širina'),
        ),
        const SizedBox(height: AppSpacing.s4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KARTICA',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Paradajz',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Uslovi pogoduju razvoju plamenjače u naredna tri dana.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
