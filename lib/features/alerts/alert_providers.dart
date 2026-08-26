import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/flags.dart';
import 'background_refresh.dart';
import 'notification_preferences.dart';

/// The store backing [notificationPreferencesProvider]. Overridden in `main()`.
final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>((ref) {
  throw StateError(
    'notificationPreferencesStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// Which risk levels the grower wants to be told about.
final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

/// Reads and writes the notification settings, keeping the background job in
/// step with them.
class NotificationPreferencesController
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() =>
      ref.read(notificationPreferencesStoreProvider).read();

  Future<void> setHigh({required bool enabled}) =>
      _update(state.copyWith(high: enabled));

  Future<void> setModerate({required bool enabled}) =>
      _update(state.copyWith(moderate: enabled));

  Future<void> _update(NotificationPreferences preferences) async {
    state = preferences;
    await ref.read(notificationPreferencesStoreProvider).write(preferences);
    await syncBackgroundJob();
  }

  /// Starts or stops the six-hourly job to match the flag and the settings.
  ///
  /// There is no point waking the device every six hours to work out that the
  /// grower asked not to be told anything.
  Future<void> syncBackgroundJob() async {
    final enabled = ref.read(featureFlagsProvider)[FeatureFlag.backgroundAlerts] &&
        state.anyEnabled;
    await BackgroundRefresh.apply(enabled: enabled);
  }
}
