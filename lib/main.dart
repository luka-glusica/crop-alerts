import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/flags/flags.dart';
import 'core/l10n/locale_controller.dart';
import 'core/l10n/locale_store.dart';
import 'features/locations/data/prefs_location_store.dart';
import 'features/locations/locations_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flags, the chosen language and the saved plots are all read synchronously
  // once the app is running, so their storage has to be ready before the first
  // frame.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        featureFlagStoreProvider.overrideWithValue(PrefsFeatureFlagStore(prefs)),
        localeStoreProvider.overrideWithValue(PrefsLocaleStore(prefs)),
        locationStoreProvider.overrideWithValue(PrefsLocationStore(prefs)),
      ],
      child: const CropAlertsApp(),
    ),
  );
}
