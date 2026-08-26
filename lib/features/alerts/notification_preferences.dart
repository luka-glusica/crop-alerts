import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rules/domain/risk.dart';

/// Which risk levels are worth waking someone up for.
///
/// Both default to off, matching the web version: an app that starts notifying
/// before being asked is one people mute rather than configure.
@immutable
class NotificationPreferences {
  const NotificationPreferences({this.high = false, this.moderate = false});

  final bool high;
  final bool moderate;

  bool get anyEnabled => high || moderate;

  /// Whether [level] should produce a notification.
  bool wants(RiskLevel level) {
    return switch (level) {
      RiskLevel.high => high,
      RiskLevel.moderate => moderate,
      RiskLevel.low => false,
    };
  }

  /// The least severe level the grower has asked to hear about.
  RiskLevel? get threshold {
    if (moderate) return RiskLevel.moderate;
    if (high) return RiskLevel.high;
    return null;
  }

  NotificationPreferences copyWith({bool? high, bool? moderate}) {
    return NotificationPreferences(
      high: high ?? this.high,
      moderate: moderate ?? this.moderate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.high == high &&
      other.moderate == moderate;

  @override
  int get hashCode => Object.hash(high, moderate);
}

/// Persistence for [NotificationPreferences] and the de-duplication marker.
abstract class NotificationPreferencesStore {
  NotificationPreferences read();
  Future<void> write(NotificationPreferences preferences);

  /// The key of the last alert actually shown, used to avoid repeating it.
  String? readLastAlertKey();
  Future<void> writeLastAlertKey(String key);
}

/// [NotificationPreferencesStore] backed by [SharedPreferences].
class PrefsNotificationPreferencesStore implements NotificationPreferencesStore {
  PrefsNotificationPreferencesStore(this._prefs);

  static const String highKey = 'alerts.notifyHigh';
  static const String moderateKey = 'alerts.notifyModerate';
  static const String lastAlertKey = 'alerts.lastAlertKey';

  final SharedPreferences _prefs;

  @override
  NotificationPreferences read() {
    return NotificationPreferences(
      high: _prefs.getBool(highKey) ?? false,
      moderate: _prefs.getBool(moderateKey) ?? false,
    );
  }

  @override
  Future<void> write(NotificationPreferences preferences) async {
    await _prefs.setBool(highKey, preferences.high);
    await _prefs.setBool(moderateKey, preferences.moderate);
  }

  @override
  String? readLastAlertKey() => _prefs.getString(lastAlertKey);

  @override
  Future<void> writeLastAlertKey(String key) =>
      _prefs.setString(lastAlertKey, key);
}

/// In-memory store for tests and for a single background run.
class InMemoryNotificationPreferencesStore
    implements NotificationPreferencesStore {
  InMemoryNotificationPreferencesStore([
    this._preferences = const NotificationPreferences(),
    this._lastAlertKey,
  ]);

  NotificationPreferences _preferences;
  String? _lastAlertKey;

  @override
  NotificationPreferences read() => _preferences;

  @override
  Future<void> write(NotificationPreferences preferences) async =>
      _preferences = preferences;

  @override
  String? readLastAlertKey() => _lastAlertKey;

  @override
  Future<void> writeLastAlertKey(String key) async => _lastAlertKey = key;
}
