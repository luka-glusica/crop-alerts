import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'locale_store.dart';

/// The store backing [localeProvider]. Overridden in `main()`.
final localeStoreProvider = Provider<LocaleStore>((ref) {
  throw StateError(
    'localeStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// The user's chosen locale, or `null` to follow the device language.
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// Reads the saved language at startup and writes changes back.
class LocaleController extends Notifier<Locale?> {
  /// Serbian in Latin script — the app's primary language, matching the web
  /// version's `lang="sr-Latn"`.
  static const Locale serbianLatin = Locale.fromSubtags(
    languageCode: 'sr',
    scriptCode: 'Latn',
  );

  static const Locale english = Locale('en');

  /// The languages the user can pick explicitly, in menu order.
  static const List<Locale> selectable = [serbianLatin, english];

  /// The locales the app resolves the device language against.
  ///
  /// Serbian is deliberately first: it is the app's primary language, so a
  /// device set to something the app does not translate should land on Serbian
  /// rather than English. The generated `AppLocalizations.supportedLocales`
  /// lists English first purely because it sorts alphabetically.
  static const List<Locale> supportedLocales = [serbianLatin, english];

  @override
  Locale? build() {
    final saved = ref.read(localeStoreProvider).read();
    // A locale we no longer ship would leave the app in an unresolvable state,
    // so treat it as "follow the device".
    if (saved != null && !isSupported(saved)) return null;
    return saved;
  }

  /// Whether [locale] is one the app ships translations for.
  static bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  /// Sets the language, or passes `null` to follow the device again.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(localeStoreProvider).write(locale);
  }
}
