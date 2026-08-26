import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/flags/flags.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/l10n/locale_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../crops/data/local_crop_repository.dart';
import '../locations/data/prefs_location_store.dart';
import '../weather/data/cached_forecast_repository.dart';
import '../weather/data/forecast_cache.dart';
import '../weather/data/yr_no_weather_api.dart';
import 'alert_run.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

/// Entry point for the background isolate.
///
/// Must be a top-level function annotated for the tree shaker, or the release
/// build drops it and the task silently never runs.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != BackgroundRefresh.taskName) return true;
    await BackgroundRefresh.runOnce();
    // Returning true regardless: a failed run is retried on the next six-hour
    // tick, which is soon enough, and asking the platform to retry a network
    // request that failed because there is no signal only drains the battery.
    return true;
  });
}

/// The six-hourly job: refresh the forecast, re-evaluate, notify on risk.
abstract final class BackgroundRefresh {
  static const String taskName = 'crop-alerts.refresh-forecast';
  static const String uniqueName = 'crop-alerts.refresh-forecast.periodic';

  /// How often the platform is asked to run the job.
  ///
  /// Android treats this as a floor and may run it later; iOS treats it as a
  /// hint and decides for itself based on how the app is used. Neither
  /// guarantees six hours, which is why the app also refreshes when opened.
  static const Duration interval = Duration(hours: 6);

  /// Registers the dispatcher. Call once, before [schedule].
  static Future<void> initialize() =>
      Workmanager().initialize(callbackDispatcher);

  /// Starts the periodic job, replacing any existing registration.
  static Future<void> schedule() {
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: interval,
      // No point waking up to fetch a forecast with no network.
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      initialDelay: interval,
    );
  }

  /// Stops the periodic job.
  static Future<void> cancel() =>
      Workmanager().cancelByUniqueName(uniqueName);

  /// Applies [enabled], so the job follows the feature flag and the grower's
  /// notification settings without the caller having to know which of
  /// [schedule] or [cancel] is appropriate.
  static Future<void> apply({required bool enabled}) =>
      enabled ? schedule() : cancel();

  /// Runs one pass. Shared by the worker and the in-app trigger.
  ///
  /// The background isolate has no ProviderScope and no widget tree, so every
  /// dependency is built here from scratch.
  static Future<AlertOutcome> runOnce() async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();

    final flags = FeatureFlags(PrefsFeatureFlagStore(prefs).readOverrides());
    if (!flags[FeatureFlag.backgroundAlerts]) {
      return AlertOutcome.notificationsDisabled;
    }

    final locale = _localeFor(prefs);
    final l10n = await AppLocalizations.delegate.load(locale);

    final run = AlertRun(
      locations: PrefsLocationStore(prefs),
      forecasts: CachedForecastRepository(
        api: YrNoWeatherApi(),
        cache: FileForecastCache(),
      ),
      crops: LocalCropRepository(),
      preferences: PrefsNotificationPreferencesStore(prefs),
      notifications: LocalNotificationService(
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
      ),
      locale: locale,
    );

    return run.execute();
  }

  /// The language a notification should be written in.
  ///
  /// The isolate has no ProviderScope, so it repeats what [LocaleController]
  /// does at startup: the saved choice, otherwise the device language narrowed
  /// to one the app ships, otherwise English.
  static Locale _localeFor(SharedPreferences prefs) {
    final saved = PrefsLocaleStore(prefs).read();
    final chosen = saved == null ? null : LocaleController.matching(saved);
    return chosen ??
        LocaleController.resolveDevice(PlatformDispatcher.instance.locales);
  }
}
