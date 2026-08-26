import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the grower a notification.
///
/// An interface so the background run can be tested without a platform channel
/// in sight, and so the app can substitute a no-op where notifications are not
/// wanted.
abstract class NotificationService {
  /// Prepares the platform and asks for permission if it has not been granted.
  ///
  /// Returns whether notifications may actually be shown.
  Future<bool> prepare();

  /// Shows the risk alert.
  Future<void> showRiskAlert({required String title, required String body});
}

/// [NotificationService] backed by `flutter_local_notifications`.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required this.channelName,
    required this.channelDescription,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Android notification channel. Changing the id creates a new channel and
  /// loses whatever the user configured on the old one, so it is fixed.
  static const String channelId = 'crop_alerts.risk';

  /// A single id, so a newer alert replaces the previous one rather than
  /// stacking up a column of near-identical warnings.
  static const int notificationId = 1;

  final String channelName;
  final String channelDescription;
  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  @override
  Future<bool> prepare() async {
    if (!_initialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Permission is requested explicitly below rather than on the
            // first launch, so the prompt arrives with some context.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }

    return false;
  }

  @override
  Future<void> showRiskAlert({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // The body runs to several crops, which a collapsed notification
          // would cut off mid-name.
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

/// A [NotificationService] that does nothing, for tests and disabled builds.
class NoopNotificationService implements NotificationService {
  /// Every alert it was asked to show, for assertions in tests.
  final List<({String title, String body})> shown = [];

  /// What [prepare] should report.
  bool permitted = true;

  @override
  Future<bool> prepare() async => permitted;

  @override
  Future<void> showRiskAlert({
    required String title,
    required String body,
  }) async {
    shown.add((title: title, body: body));
    debugPrint('Notification suppressed: $title — $body');
  }
}
