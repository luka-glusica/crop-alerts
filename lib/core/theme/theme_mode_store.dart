import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for the user's chosen theme.
///
/// Nothing saved means [ThemeMode.system], which is the default.
abstract class ThemeModeStore {
  /// The theme the user picked, or `null` if they never picked one.
  ThemeMode? read();

  /// Persists [mode].
  Future<void> write(ThemeMode mode);
}

/// [ThemeModeStore] backed by [SharedPreferences].
class PrefsThemeModeStore implements ThemeModeStore {
  PrefsThemeModeStore(this._prefs);

  static const String storageKey = 'settings.themeMode';

  final SharedPreferences _prefs;

  @override
  ThemeMode? read() => parseName(_prefs.getString(storageKey));

  @override
  Future<void> write(ThemeMode mode) =>
      _prefs.setString(storageKey, mode.name);

  /// Parses a value written by [write]. Returns `null` for anything
  /// unreadable, so a corrupted preference costs the choice rather than the
  /// launch.
  static ThemeMode? parseName(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}

/// In-memory [ThemeModeStore] for tests.
class InMemoryThemeModeStore implements ThemeModeStore {
  InMemoryThemeModeStore([this._mode]);

  ThemeMode? _mode;

  @override
  ThemeMode? read() => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}
