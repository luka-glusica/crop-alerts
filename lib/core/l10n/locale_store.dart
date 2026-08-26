import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for the user's chosen language.
///
/// Nothing saved means the user has not chosen yet, and the device language
/// decides.
abstract class LocaleStore {
  /// The locale the user picked, or `null` if they never picked one.
  Locale? read();

  /// Persists [locale].
  Future<void> write(Locale locale);
}

/// [LocaleStore] backed by [SharedPreferences].
class PrefsLocaleStore implements LocaleStore {
  PrefsLocaleStore(this._prefs);

  static const String storageKey = 'settings.locale';

  final SharedPreferences _prefs;

  @override
  Locale? read() => parseTag(_prefs.getString(storageKey));

  @override
  Future<void> write(Locale locale) async =>
      _prefs.setString(storageKey, toTag(locale));

  /// Renders [locale] as a BCP-47 tag, e.g. `sr-Latn` or `en`.
  static String toTag(Locale locale) => locale.toLanguageTag();

  /// Parses a tag written by [toTag]. Returns `null` for anything unreadable,
  /// so a corrupted or outdated preference falls back to the device language
  /// rather than crashing at startup.
  static Locale? parseTag(String? tag) {
    if (tag == null || tag.isEmpty) return null;

    final parts = tag.split(RegExp('[-_]'));
    if (parts.isEmpty || parts.first.isEmpty) return null;

    final language = parts.first;
    String? script;
    String? country;
    for (final part in parts.skip(1)) {
      if (part.length == 4) {
        script = part;
      } else if (part.length == 2 || part.length == 3) {
        country = part;
      }
    }

    return Locale.fromSubtags(
      languageCode: language,
      scriptCode: script,
      countryCode: country,
    );
  }
}

/// In-memory [LocaleStore] for tests.
class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore([this._locale]);

  Locale? _locale;

  @override
  Locale? read() => _locale;

  @override
  Future<void> write(Locale locale) async => _locale = locale;
}
