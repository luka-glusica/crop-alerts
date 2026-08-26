import 'package:crop_alerts/app.dart';
import 'package:crop_alerts/core/flags/flags.dart';
import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/l10n/locale_store.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/locations_controller.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({
    Locale? savedLocale,
    ThemeMode? savedThemeMode,
    List<Locale> deviceLocales = const [Locale('en', 'US')],
  }) {
    return ProviderScope(
      overrides: [
        featureFlagStoreProvider.overrideWithValue(InMemoryFeatureFlagStore()),
        localeStoreProvider.overrideWithValue(InMemoryLocaleStore(savedLocale)),
        deviceLocalesProvider.overrideWithValue(deviceLocales),
        themeModeStoreProvider.overrideWithValue(
          InMemoryThemeModeStore(savedThemeMode),
        ),
        locationStoreProvider.overrideWithValue(InMemoryLocationStore()),
      ],
      child: const CropAlertsApp(),
    );
  }

  /// Localizations are installed below MaterialApp, so the context has to come
  /// from inside the app.
  AppLocalizations l10nOf(WidgetTester tester) {
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  group('language', () {
    testWidgets('a Serbian device gets Serbian', (tester) async {
      await tester.pumpWidget(
        harness(deviceLocales: const [Locale('sr', 'RS')]),
      );
      await tester.pump();

      expect(l10nOf(tester).appTitle, 'Poljoprivredni Paničar');
    });

    testWidgets('an English device gets English', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(l10nOf(tester).appTitle, 'Crop Alerts');
    });

    testWidgets('a device language the app does not ship gets English',
        (tester) async {
      await tester.pumpWidget(
        harness(deviceLocales: const [Locale('de', 'DE')]),
      );
      await tester.pump();

      expect(l10nOf(tester).appTitle, 'Crop Alerts');
    });

    testWidgets('a saved language overrides the device', (tester) async {
      await tester.pumpWidget(
        harness(savedLocale: LocaleController.serbianLatin),
      );
      await tester.pump();

      expect(l10nOf(tester).appTitle, 'Poljoprivredni Paničar');
    });
  });

  group('theme', () {
    ThemeMode modeOf(WidgetTester tester) {
      return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    }

    testWidgets('follows the device unless told otherwise', (tester) async {
      await tester.pumpWidget(harness());

      expect(modeOf(tester), ThemeMode.system);
    });

    testWidgets('restores a saved choice', (tester) async {
      await tester.pumpWidget(harness(savedThemeMode: ThemeMode.dark));

      expect(modeOf(tester), ThemeMode.dark);
    });
  });
}
