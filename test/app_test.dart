import 'package:crop_alerts/app.dart';
import 'package:crop_alerts/core/flags/flags.dart';
import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/l10n/locale_store.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({Locale? savedLocale}) {
    return ProviderScope(
      overrides: [
        featureFlagStoreProvider.overrideWithValue(InMemoryFeatureFlagStore()),
        localeStoreProvider.overrideWithValue(InMemoryLocaleStore(savedLocale)),
      ],
      child: const CropAlertsApp(),
    );
  }

  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('follows the device language by default', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(harness());
    await tester.pump();

    // Localizations are installed below MaterialApp, so the context has to
    // come from inside the app.
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).appTitle, 'Crop Alerts');
  });

  testWidgets('a saved language overrides the device', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(harness(savedLocale: LocaleController.serbianLatin));
    await tester.pump();

    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).appTitle, 'Poljoprivredni Paničar');
  });
}
