import 'package:flutter/foundation.dart';

import 'feature_flag.dart';

/// An immutable snapshot of every flag's effective value.
///
/// A flag is either left at its [FeatureFlag.defaultValue] or explicitly
/// overridden by the user. Keeping the two apart lets the settings screen show
/// which flags have been touched, and lets [reset] restore the shipped defaults.
@immutable
class FeatureFlags {
  const FeatureFlags(this._overrides);

  /// Every flag at its shipped default.
  const FeatureFlags.defaults() : _overrides = const {};

  final Map<FeatureFlag, bool> _overrides;

  /// The effective value of [flag].
  bool isEnabled(FeatureFlag flag) => _overrides[flag] ?? flag.defaultValue;

  /// Shorthand for [isEnabled], so call sites read as `flags[FeatureFlag.x]`.
  bool operator [](FeatureFlag flag) => isEnabled(flag);

  /// Whether the user has explicitly set [flag] rather than inheriting it.
  bool isOverridden(FeatureFlag flag) => _overrides.containsKey(flag);

  /// The flags the user has explicitly set.
  Map<FeatureFlag, bool> get overrides => Map.unmodifiable(_overrides);

  /// A copy with [flag] set to [value], or back to its default when `null`.
  FeatureFlags withOverride(FeatureFlag flag, bool? value) {
    final next = Map<FeatureFlag, bool>.from(_overrides);
    if (value == null) {
      next.remove(flag);
    } else {
      next[flag] = value;
    }
    return FeatureFlags(next);
  }

  /// A copy with every override cleared.
  FeatureFlags reset() => const FeatureFlags.defaults();

  @override
  bool operator ==(Object other) =>
      other is FeatureFlags &&
      mapEquals(_overrides, other._overrides);

  @override
  int get hashCode => Object.hashAllUnordered(
        _overrides.entries.map((e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() {
    final enabled = FeatureFlag.values.where(isEnabled).map((f) => f.name);
    return 'FeatureFlags(enabled: ${enabled.join(', ')})';
  }
}
