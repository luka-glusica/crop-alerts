import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_store.dart';

/// The store backing [localeProvider]. Overridden in `main()`.
final localeStoreProvider = Provider<LocaleStore>((ref) {
  throw StateError(
    'localeStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// The device's preferred languages, most preferred first.
///
/// A provider rather than a direct [PlatformDispatcher] read so that tests can
/// pin the device language without touching global state.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => PlatformDispatcher.instance.locales,
);

/// The language the app is running in. Never `null`: a device language the app
/// does not translate is resolved to English at startup.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// Reads the saved language at startup and writes changes back.
class LocaleController extends Notifier<Locale> {
  /// Serbian in Latin script — the app's primary language, matching the web
  /// version's `lang="sr-Latn"`.
  static const Locale serbianLatin = Locale.fromSubtags(
    languageCode: 'sr',
    scriptCode: 'Latn',
  );

  static const Locale english = Locale('en');

  /// The languages the user can pick, in menu order.
  static const List<Locale> selectable = [serbianLatin, english];

  /// The locales the app ships translations for.
  ///
  /// The app always hands `MaterialApp` a locale from this list, so the order
  /// only matters as a safety net; English is first because it is what an
  /// untranslated device language falls back to.
  static const List<Locale> supportedLocales = [english, serbianLatin];

  @override
  Locale build() {
    final saved = ref.read(localeStoreProvider).read();
    // A saved locale is narrowed the same way a device one is, so a value
    // written by an older build — or one the app no longer ships — cannot leave
    // the app in an unresolvable state.
    final chosen = saved == null ? null : matching(saved);
    return chosen ?? resolveDevice(ref.read(deviceLocalesProvider));
  }

  /// The shipped locale [locale] should be shown in, or `null` if the app has
  /// no translation for it.
  ///
  /// Matching is by language alone: a Serbian device set to Cyrillic still gets
  /// Latin, the only script the app ships.
  static Locale? matching(Locale locale) {
    for (final supported in selectable) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return null;
  }

  /// The language to run in for a device that prefers [deviceLocales].
  ///
  /// Falls back to English when the device asks for nothing the app ships,
  /// rather than to the app's own primary language.
  static Locale resolveDevice(List<Locale> deviceLocales) {
    for (final device in deviceLocales) {
      final match = matching(device);
      if (match != null) return match;
    }
    return english;
  }

  /// Sets the language and remembers it, so it survives a device language
  /// change from here on.
  Future<void> setLocale(Locale locale) async {
    final chosen = matching(locale) ?? english;
    state = chosen;
    await ref.read(localeStoreProvider).write(chosen);
  }
}
