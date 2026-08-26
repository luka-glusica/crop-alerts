import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_store.dart';

/// The store backing [themeModeProvider]. Overridden in `main()`.
final themeModeStoreProvider = Provider<ThemeModeStore>((ref) {
  throw StateError(
    'themeModeStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// Whether the app runs light, dark, or whatever the device is set to.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Reads the saved theme at startup and writes changes back.
class ThemeModeController extends Notifier<ThemeMode> {
  /// The themes the user can pick, in menu order.
  static const List<ThemeMode> selectable = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  @override
  ThemeMode build() => ref.read(themeModeStoreProvider).read() ?? ThemeMode.system;

  /// Sets the theme and remembers it.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(themeModeStoreProvider).write(mode);
  }
}
