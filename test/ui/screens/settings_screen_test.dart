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
  late InMemoryNotificationPreferencesStore alertStore;

  Future<void> pumpSettings(
    WidgetTester tester, {
    Locale? locale,
    NotificationPreferences preferences = const NotificationPreferences(),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    localeStore = InMemoryLocaleStore(locale);
    flagStore = InMemoryFeatureFlagStore();
    alertStore = InMemoryNotificationPreferencesStore(preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeStoreProvider.overrideWithValue(localeStore),
          featureFlagStoreProvider.overrideWithValue(flagStore),
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
    testWidgets('follows the device by default', (tester) async {
      await pumpSettings(tester);

      final selected = tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .toList();
      expect(selected, hasLength(3));
      expect(find.text('Kao na uređaju'), findsOneWidget);
    });

    testWidgets('choosing English persists the choice', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Engleski'));
      await tester.pumpAndSettle();

      expect(localeStore.read(), LocaleController.english);
    });

    testWidgets('a saved script-qualified locale still matches its option',
        (tester) async {
      // sr-Latn must select "Srpski", not fall through to "Kao na uređaju".
      await pumpSettings(tester, locale: LocaleController.serbianLatin);

      final serbian = tester.widget<RadioListTile<String>>(
        find.ancestor(
          of: find.text('Srpski'),
          matching: find.byType(RadioListTile<String>),
        ),
      );
      expect(serbian.value, 'sr');
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

  group('feature flags', () {
    testWidgets('every flag is listed with what it does', (tester) async {
      await pumpSettings(tester);

      for (final flag in FeatureFlag.values) {
        expect(find.text(flag.name), findsOneWidget, reason: flag.name);
        expect(find.text(flag.description), findsOneWidget, reason: flag.name);
      }
    });

    testWidgets('toggling one persists an override', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text(FeatureFlag.mitigationRatings.name));
      await tester.pumpAndSettle();

      expect(
        flagStore.readOverrides()[FeatureFlag.mitigationRatings],
        isTrue,
      );
    });

    testWidgets('reset clears every override', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text(FeatureFlag.mitigationRatings.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vrati podrazumevano'));
      await tester.pumpAndSettle();

      expect(flagStore.readOverrides(), isEmpty);
    });
  });

  testWidgets('credits MET Norway, as their terms require', (tester) async {
    await pumpSettings(tester);

    expect(find.textContaining('MET Norway'), findsOneWidget);
  });
}
