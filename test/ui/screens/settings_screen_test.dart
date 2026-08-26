import 'package:crop_alerts/core/flags/flags.dart';
import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/l10n/locale_store.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/alerts/alert_providers.dart';
import 'package:crop_alerts/features/alerts/notification_preferences.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryLocaleStore localeStore;
  late InMemoryFeatureFlagStore flagStore;
  late InMemoryThemeModeStore themeStore;
  late InMemoryNotificationPreferencesStore alertStore;

  Future<void> pumpSettings(
    WidgetTester tester, {
    Locale? locale,
    ThemeMode? themeMode,
    List<Locale> deviceLocales = const [Locale('en', 'US')],
    NotificationPreferences preferences = const NotificationPreferences(),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    localeStore = InMemoryLocaleStore(locale);
    flagStore = InMemoryFeatureFlagStore();
    themeStore = InMemoryThemeModeStore(themeMode);
    alertStore = InMemoryNotificationPreferencesStore(preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeStoreProvider.overrideWithValue(localeStore),
          deviceLocalesProvider.overrideWithValue(deviceLocales),
          featureFlagStoreProvider.overrideWithValue(flagStore),
          themeModeStoreProvider.overrideWithValue(themeStore),
          notificationPreferencesStoreProvider.overrideWithValue(alertStore),
        ],
        child: MaterialApp(
          locale: LocaleController.serbianLatin,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleController.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('language', () {
    RadioGroup<String> languageGroup(WidgetTester tester) {
      return tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    }

    testWidgets('offers the two languages and nothing else', (tester) async {
      await pumpSettings(tester);

      final options =
          tester.widgetList<RadioListTile<String>>(
            find.byType(RadioListTile<String>),
          ).map((tile) => tile.value).toList();
      expect(options, ['sr', 'en']);
      expect(find.text('Kao na uređaju'), findsOneWidget); // the theme option
    });

    testWidgets('shows the device language as the one in use', (tester) async {
      await pumpSettings(tester, deviceLocales: const [Locale('sr', 'RS')]);

      expect(languageGroup(tester).groupValue, 'sr');
    });

    testWidgets('an untranslated device language shows English',
        (tester) async {
      await pumpSettings(tester, deviceLocales: const [Locale('de', 'DE')]);

      expect(languageGroup(tester).groupValue, 'en');
    });

    testWidgets('choosing English persists the choice', (tester) async {
      await pumpSettings(tester, deviceLocales: const [Locale('sr', 'RS')]);

      await tester.tap(find.text('Engleski'));
      await tester.pumpAndSettle();

      expect(localeStore.read(), LocaleController.english);
    });

    testWidgets('a saved script-qualified locale still matches its option',
        (tester) async {
      // sr-Latn must select "Srpski" rather than nothing at all.
      await pumpSettings(tester, locale: LocaleController.serbianLatin);

      expect(languageGroup(tester).groupValue, 'sr');
    });
  });

  group('theme', () {
    RadioGroup<ThemeMode> themeGroup(WidgetTester tester) {
      return tester.widget<RadioGroup<ThemeMode>>(
        find.byType(RadioGroup<ThemeMode>),
      );
    }

    testWidgets('starts on the device setting', (tester) async {
      await pumpSettings(tester);

      expect(themeGroup(tester).groupValue, ThemeMode.system);
      expect(find.text('Svetla'), findsOneWidget);
      expect(find.text('Tamna'), findsOneWidget);
    });

    testWidgets('reflects what was saved', (tester) async {
      await pumpSettings(tester, themeMode: ThemeMode.dark);

      expect(themeGroup(tester).groupValue, ThemeMode.dark);
    });

    testWidgets('choosing dark persists the choice', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Tamna'));
      await tester.pumpAndSettle();

      expect(themeStore.read(), ThemeMode.dark);
      expect(themeGroup(tester).groupValue, ThemeMode.dark);
    });
  });

  group('notifications', () {
    testWidgets('both start switched off', (tester) async {
      await pumpSettings(tester);

      final switches =
          tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      final alertSwitches = switches.take(2);
      expect(alertSwitches.every((s) => s.value == false), isTrue);
    });

    testWidgets('reflect what was saved', (tester) async {
      await pumpSettings(
        tester,
        preferences: const NotificationPreferences(high: true),
      );

      final high = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Obavesti me o visokom riziku'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(high.value, isTrue);
    });

    testWidgets('switching one off persists immediately', (tester) async {
      await pumpSettings(
        tester,
        preferences: const NotificationPreferences(high: true),
      );

      await tester.tap(find.text('Obavesti me o visokom riziku'));
      await tester.pumpAndSettle();

      expect(alertStore.read().high, isFalse);
    });
  });

  // Feature flags are a team-side toggle, so the grower is never shown them.
  testWidgets('does not expose the feature flags', (tester) async {
    await pumpSettings(tester);

    for (final flag in FeatureFlag.values) {
      expect(find.text(flag.name), findsNothing, reason: flag.name);
      expect(find.text(flag.description), findsNothing, reason: flag.name);
    }
  });

  testWidgets('credits MET Norway, as their terms require', (tester) async {
    await pumpSettings(tester);

    expect(find.textContaining('MET Norway'), findsOneWidget);
  });
}
