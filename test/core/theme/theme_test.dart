import 'package:crop_alerts/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorScale', () {
    test('indexes by Tailwind step', () {
      expect(AppColors.emerald[50], const Color(0xFFECFDF5));
      expect(AppColors.emerald[700], const Color(0xFF047857));
      expect(AppColors.emerald[950], const Color(0xFF022C22));
    });

    test('rejects a step that is not on the ramp', () {
      expect(() => AppColors.emerald[550], throwsArgumentError);
      expect(() => AppColors.emerald[0], throwsArgumentError);
    });

    test('every ramp resolves all eleven steps', () {
      const ramps = [
        AppColors.emerald,
        AppColors.green,
        AppColors.amber,
        AppColors.red,
        AppColors.stone,
      ];

      for (final ramp in ramps) {
        final colors = ColorScale.steps.map((s) => ramp[s]).toSet();
        expect(colors, hasLength(ColorScale.steps.length));
      }
    });

    test('ramps run light to dark', () {
      for (var i = 1; i < ColorScale.steps.length; i++) {
        final lighter = AppColors.emerald[ColorScale.steps[i - 1]];
        final darker = AppColors.emerald[ColorScale.steps[i]];
        expect(
          lighter.computeLuminance(),
          greaterThan(darker.computeLuminance()),
          reason: 'step ${ColorScale.steps[i - 1]} vs ${ColorScale.steps[i]}',
        );
      }
    });

    test('matches the colours the web app renders the logo with', () {
      // The published logo.svg uses these exact values; keeping the assertion
      // here means a palette edit cannot silently drift away from the artwork.
      expect(AppColors.emerald[50], const Color(0xFFECFDF5));
      expect(AppColors.emerald[200], const Color(0xFFA7F3D0));
      expect(AppColors.green[700], const Color(0xFF15803D));
      expect(AppColors.green[800], const Color(0xFF166534));
      expect(AppColors.red[800], const Color(0xFF991B1B));
    });
  });

  group('AppSpacing', () {
    test('sits on a 4px grid above the half step', () {
      const scale = [
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s8,
        AppSpacing.s10,
        AppSpacing.s12,
        AppSpacing.s16,
      ];

      for (final step in scale) {
        expect(step % 4, 0, reason: '$step is not a multiple of 4');
      }
    });

    test('step names match their Tailwind value', () {
      expect(AppSpacing.s4, 16);
      expect(AppSpacing.s6, 24);
      expect(AppSpacing.s16, 64);
    });
  });

  group('AppTypography', () {
    test('line heights are expressed as a ratio of the font size', () {
      expect(AppTypography.leadingBase * AppTypography.base, 24);
      expect(AppTypography.leadingSm * AppTypography.sm, 20);
      expect(AppTypography.leadingXl4 * AppTypography.xl4, 40);
    });

    test('tracking scales with the font size it is applied to', () {
      expect(AppTypography.trackingWidest(AppTypography.xs), closeTo(1.2, 1e-9));
      expect(AppTypography.trackingTight(AppTypography.xl4), closeTo(-0.9, 1e-9));
    });
  });

  group('AppPalette', () {
    test('light canvas and brand match the web app manifest', () {
      expect(AppPalette.light.canvas, const Color(0xFFF3F7EC));
      expect(AppColors.brand, const Color(0xFF2F6F3E));
    });

    test('risk text is readable on its own background', () {
      const palettes = [AppPalette.light, AppPalette.dark];

      for (final palette in palettes) {
        final states = [
          palette.riskHigh,
          palette.riskModerate,
          palette.riskLow,
          palette.dormant,
        ];
        for (final state in states) {
          final contrast = _contrastRatio(state.foreground, state.background);
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: 'contrast $contrast is below WCAG AA for body text',
          );
        }
      }
    });

    test('body text is readable on the surface it sits on', () {
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        expect(
          _contrastRatio(palette.textPrimary, palette.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.textPrimary, palette.canvas),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.textOnBrand, palette.brand),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('copyWith replaces only what it is given', () {
      final changed = AppPalette.light.copyWith(canvas: const Color(0xFF123456));

      expect(changed.canvas, const Color(0xFF123456));
      expect(changed.surface, AppPalette.light.surface);
      expect(changed.riskHigh.accent, AppPalette.light.riskHigh.accent);
    });

    test('lerp interpolates between light and dark', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);

      expect(mid.canvas, isNot(AppPalette.light.canvas));
      expect(mid.canvas, isNot(AppPalette.dark.canvas));
      expect(
        AppPalette.light.lerp(AppPalette.dark, 0).canvas,
        AppPalette.light.canvas,
      );
      expect(
        AppPalette.light.lerp(AppPalette.dark, 1).canvas,
        AppPalette.dark.canvas,
      );
    });

    test('lerp against a foreign extension returns itself', () {
      expect(AppPalette.light.lerp(null, 0.5), same(AppPalette.light));
    });
  });

  group('AppTheme', () {
    test('registers the palette as a theme extension', () {
      expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
      expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    });

    test('paints the scaffold with the canvas colour', () {
      expect(AppTheme.light().scaffoldBackgroundColor, AppPalette.light.canvas);
      expect(AppTheme.dark().scaffoldBackgroundColor, AppPalette.dark.canvas);
    });

    test('brightness is carried through to the colour scheme', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    testWidgets('context.palette resolves the themed extension', (tester) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              resolved = context.palette;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, AppPalette.dark);
    });

    testWidgets('context.palette falls back to light without a theme extension',
        (tester) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = context.palette;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, AppPalette.light);
    });
  });

  group('ThemeModeController', () {
    ProviderContainer containerWith(ThemeModeStore store) {
      final container = ProviderContainer(
        overrides: [themeModeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to the device setting', () {
      final container = containerWith(InMemoryThemeModeStore());

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('restores a saved choice', () {
      final container = containerWith(InMemoryThemeModeStore(ThemeMode.light));

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setThemeMode updates state and persists', () async {
      final store = InMemoryThemeModeStore();
      final container = containerWith(store);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(store.read(), ThemeMode.dark);
    });

    test('every selectable mode is a real ThemeMode', () {
      expect(ThemeModeController.selectable, ThemeMode.values.toSet());
    });
  });

  group('PrefsThemeModeStore parsing', () {
    test('round-trips every mode', () {
      for (final mode in ThemeMode.values) {
        expect(PrefsThemeModeStore.parseName(mode.name), mode);
      }
    });

    test('returns null for anything unreadable', () {
      // A preference written by a build that offered a mode this one does not
      // must cost the choice, not the launch.
      expect(PrefsThemeModeStore.parseName(null), isNull);
      expect(PrefsThemeModeStore.parseName(''), isNull);
      expect(PrefsThemeModeStore.parseName('sepia'), isNull);
    });
  });
}

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
