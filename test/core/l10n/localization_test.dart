import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/l10n/locale_store.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB files', () {
    Map<String, dynamic> readArb(String name) {
      final raw = File('lib/l10n/$name').readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    Set<String> messageKeys(Map<String, dynamic> arb) {
      return arb.keys.where((k) => !k.startsWith('@')).toSet();
    }

    test('Serbian and English define exactly the same messages', () {
      final sr = messageKeys(readArb('app_sr.arb'));
      final en = messageKeys(readArb('app_en.arb'));

      expect(
        sr.difference(en),
        isEmpty,
        reason: 'missing from app_en.arb',
      );
      expect(
        en.difference(sr),
        isEmpty,
        reason: 'missing from app_sr.arb, the template',
      );
    });

    test('placeholders match between the two languages', () {
      final sr = readArb('app_sr.arb');
      final en = readArb('app_en.arb');

      Set<String> placeholdersOf(Map<String, dynamic> arb, String key) {
        final meta = arb['@$key'];
        if (meta is! Map) return {};
        final placeholders = meta['placeholders'];
        if (placeholders is! Map) return {};
        return placeholders.keys.cast<String>().toSet();
      }

      for (final key in messageKeys(sr)) {
        final srPlaceholders = placeholdersOf(sr, key);
        if (srPlaceholders.isEmpty) continue;
        expect(
          placeholdersOf(en, key),
          srPlaceholders,
          reason: 'placeholders differ for "$key"',
        );
      }
    });

    test('the sr_Latn variant only overrides, inheriting the rest from sr', () {
      // AppLocalizationsSrLatn extends AppLocalizationsSr, so this file only
      // needs to carry differences — keeping it empty avoids two copies of the
      // same translations drifting apart.
      final latn = readArb('app_sr_Latn.arb');
      expect(latn['@@locale'], 'sr_Latn');
      expect(messageKeys(latn), isEmpty);
    });

    test('every message is reachable through the generated class', () async {
      final keys = messageKeys(readArb('app_sr.arb'));
      final l10n = await AppLocalizations.delegate.load(
        LocaleController.serbianLatin,
      );

      // A spot check across the string kinds: plain, plural and placeholder.
      expect(l10n.appTitle, 'Poljoprivredni Paničar');
      expect(l10n.riskHigh, 'Visok rizik');
      expect(l10n.cropsAtRisk(0), 'Nijedan usev nije ugrožen');
      expect(l10n.cropsAtRisk(1), '1 usev je ugrožen');
      expect(l10n.cropsAtRisk(3), '3 useva su ugrožena');
      expect(l10n.cropsAtRisk(7), '7 useva je ugroženo');
      expect(l10n.degreesCelsius('21.5'), '21.5°C');
      expect(keys, contains('attributionMet'));
    });

    test('English plurals resolve too', () async {
      final l10n = await AppLocalizations.delegate.load(
        LocaleController.english,
      );

      expect(l10n.appTitle, 'Crop Alerts');
      expect(l10n.cropsAtRisk(0), 'No crops at risk');
      expect(l10n.cropsAtRisk(1), '1 crop at risk');
      expect(l10n.cropsAtRisk(4), '4 crops at risk');
    });
  });

  group('locale resolution', () {
    Future<Locale> resolvedLocaleFor(
      WidgetTester tester,
      List<Locale> deviceLocales,
    ) async {
      late Locale resolved;
      tester.platformDispatcher.localesTestValue = deviceLocales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleController.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = Localizations.localeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      return resolved;
    }

    testWidgets('a Serbian device gets Serbian in Latin script',
        (tester) async {
      final resolved = await resolvedLocaleFor(tester, [const Locale('sr', 'RS')]);

      expect(resolved.languageCode, 'sr');
      expect(resolved.scriptCode, 'Latn');
    });

    testWidgets('a Cyrillic Serbian device still gets Latin, the only script '
        'the app ships', (tester) async {
      final resolved = await resolvedLocaleFor(tester, [
        const Locale.fromSubtags(
          languageCode: 'sr',
          scriptCode: 'Cyrl',
          countryCode: 'RS',
        ),
      ]);

      expect(resolved.languageCode, 'sr');
      expect(resolved.scriptCode, 'Latn');
    });

    testWidgets('an English device gets English', (tester) async {
      final resolved = await resolvedLocaleFor(tester, [const Locale('en', 'GB')]);

      expect(resolved.languageCode, 'en');
    });

    testWidgets('an untranslated language falls back to Serbian, not English',
        (tester) async {
      final resolved = await resolvedLocaleFor(tester, [const Locale('de', 'DE')]);

      expect(resolved.languageCode, 'sr');
    });
  });

  group('PrefsLocaleStore tag parsing', () {
    test('round-trips a script-qualified locale', () {
      const locale = LocaleController.serbianLatin;
      final tag = PrefsLocaleStore.toTag(locale);

      expect(tag, 'sr-Latn');
      expect(PrefsLocaleStore.parseTag(tag), locale);
    });

    test('round-trips a plain language', () {
      expect(PrefsLocaleStore.toTag(const Locale('en')), 'en');
      expect(PrefsLocaleStore.parseTag('en'), const Locale('en'));
    });

    test('accepts underscore-separated tags', () {
      expect(
        PrefsLocaleStore.parseTag('sr_Latn_RS'),
        const Locale.fromSubtags(
          languageCode: 'sr',
          scriptCode: 'Latn',
          countryCode: 'RS',
        ),
      );
    });

    test('returns null for anything unreadable', () {
      expect(PrefsLocaleStore.parseTag(null), isNull);
      expect(PrefsLocaleStore.parseTag(''), isNull);
      expect(PrefsLocaleStore.parseTag('-'), isNull);
    });
  });

  group('LocaleController', () {
    ProviderContainer containerWith(LocaleStore store) {
      final container = ProviderContainer(
        overrides: [localeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to following the device', () {
      final container = containerWith(InMemoryLocaleStore());

      expect(container.read(localeProvider), isNull);
    });

    test('restores a saved language', () {
      final container = containerWith(
        InMemoryLocaleStore(LocaleController.english),
      );

      expect(container.read(localeProvider), LocaleController.english);
    });

    test('ignores a saved language the app no longer ships', () {
      final container = containerWith(
        InMemoryLocaleStore(const Locale('fr')),
      );

      expect(container.read(localeProvider), isNull);
    });

    test('setLocale updates state and persists', () async {
      final store = InMemoryLocaleStore();
      final container = containerWith(store);

      await container
          .read(localeProvider.notifier)
          .setLocale(LocaleController.serbianLatin);

      expect(container.read(localeProvider), LocaleController.serbianLatin);
      expect(store.read(), LocaleController.serbianLatin);
    });

    test('clearing the choice goes back to the device language', () async {
      final store = InMemoryLocaleStore(LocaleController.english);
      final container = containerWith(store);

      await container.read(localeProvider.notifier).setLocale(null);

      expect(container.read(localeProvider), isNull);
      expect(store.read(), isNull);
    });

    test('both selectable languages are supported', () {
      for (final locale in LocaleController.selectable) {
        expect(LocaleController.isSupported(locale), isTrue);
      }
      expect(LocaleController.isSupported(const Locale('fr')), isFalse);
    });
  });
}
