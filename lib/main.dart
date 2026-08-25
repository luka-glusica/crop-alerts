import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/flags/flags.dart';
import 'core/l10n/locale_controller.dart';
import 'core/l10n/locale_store.dart';
import 'features/alerts/alert_providers.dart';
import 'features/alerts/background_refresh.dart';
import 'features/alerts/notification_preferences.dart';
import 'features/locations/data/prefs_location_store.dart';
import 'features/locations/locations_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flags, the chosen language and the saved plots are all read synchronously
  // once the app is running, so their storage has to be ready before the first
  // frame.
  final prefs = await SharedPreferences.getInstance();

  // Registering the dispatcher is separate from scheduling the job: the app
  // has to be able to receive a background callback even when the grower has
  // notifications switched off, or switching them back on would do nothing
  // until the next launch.
  await BackgroundRefresh.initialize();

  final container = ProviderContainer(
    overrides: [
      featureFlagStoreProvider.overrideWithValue(PrefsFeatureFlagStore(prefs)),
      localeStoreProvider.overrideWithValue(PrefsLocaleStore(prefs)),
      locationStoreProvider.overrideWithValue(PrefsLocationStore(prefs)),
      notificationPreferencesStoreProvider.overrideWithValue(
        PrefsNotificationPreferencesStore(prefs),
      ),
    ],
  );

  // Bring the schedule back in line with the saved settings, in case the flag
  // changed in a new build or the platform dropped the registration.
  await container
      .read(notificationPreferencesProvider.notifier)
      .syncBackgroundJob();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CropAlertsApp(),
    ),
  );
}
