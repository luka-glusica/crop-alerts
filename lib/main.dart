import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/flags/flags.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Feature flags are read synchronously once the app is running, so the store
  // has to be ready before the first frame.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        featureFlagStoreProvider.overrideWithValue(PrefsFeatureFlagStore(prefs)),
      ],
      child: const CropAlertsApp(),
    ),
  );
}
