import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

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
      appBar: AppBar(title: const Text('Design tokens')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          0,
          AppSpacing.s4,
          AppSpacing.s16,
        ),
        children: const [
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
            OutlinedButton(onPressed: () {}, child: const Text('Dodaj parcelu')),
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
