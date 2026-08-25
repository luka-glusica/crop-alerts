import 'package:shared_preferences/shared_preferences.dart';

import 'feature_flag.dart';

/// Persistence for user-set flag overrides.
///
/// Reads are synchronous so that the first frame can be built with the correct
/// flags — there is no loading state for a feature toggle.
abstract class FeatureFlagStore {
  /// Every override the user has set. Flags absent from the map use their default.
  Map<FeatureFlag, bool> readOverrides();

  /// Persists [value] for [flag], or clears the override when [value] is `null`.
  Future<void> writeOverride(FeatureFlag flag, bool? value);

  /// Clears every override.
  Future<void> clear();
}

/// [FeatureFlagStore] backed by [SharedPreferences].
class PrefsFeatureFlagStore implements FeatureFlagStore {
  PrefsFeatureFlagStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Map<FeatureFlag, bool> readOverrides() {
    final overrides = <FeatureFlag, bool>{};
    for (final flag in FeatureFlag.values) {
      final value = _prefs.getBool(flag.storageKey);
      if (value != null) overrides[flag] = value;
    }
    return overrides;
  }

  @override
  Future<void> writeOverride(FeatureFlag flag, bool? value) async {
    if (value == null) {
      await _prefs.remove(flag.storageKey);
    } else {
      await _prefs.setBool(flag.storageKey, value);
    }
  }

  @override
  Future<void> clear() async {
    for (final flag in FeatureFlag.values) {
      await _prefs.remove(flag.storageKey);
    }
  }
}

/// In-memory [FeatureFlagStore] for tests and for the background isolate.
class InMemoryFeatureFlagStore implements FeatureFlagStore {
  InMemoryFeatureFlagStore([Map<FeatureFlag, bool>? initial])
      : _overrides = {...?initial};

  final Map<FeatureFlag, bool> _overrides;

  @override
  Map<FeatureFlag, bool> readOverrides() => Map.of(_overrides);

  @override
  Future<void> writeOverride(FeatureFlag flag, bool? value) async {
    if (value == null) {
      _overrides.remove(flag);
    } else {
      _overrides[flag] = value;
    }
  }

  @override
  Future<void> clear() async => _overrides.clear();
}
