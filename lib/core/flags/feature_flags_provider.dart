import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flag.dart';
import 'feature_flag_store.dart';
import 'feature_flags.dart';

/// The store backing [featureFlagsProvider].
///
/// Overridden in `main()` with a [PrefsFeatureFlagStore] once
/// `SharedPreferences` has loaded, and in tests with an
/// [InMemoryFeatureFlagStore]. It throws rather than defaulting so that a
/// missing override surfaces immediately instead of silently losing settings.
final featureFlagStoreProvider = Provider<FeatureFlagStore>((ref) {
  throw StateError(
    'featureFlagStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// The current value of every feature flag.
final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(
  FeatureFlagsNotifier.new,
);

/// Watches a single flag, so widgets only rebuild when that flag changes.
final featureFlagProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  return ref.watch(featureFlagsProvider.select((flags) => flags.isEnabled(flag)));
});

/// Reads flag overrides at startup and writes them back as the user edits them.
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  @override
  FeatureFlags build() {
    return FeatureFlags(ref.read(featureFlagStoreProvider).readOverrides());
  }

  /// Sets [flag] to [value], or restores its default when [value] is `null`.
  Future<void> setOverride(FeatureFlag flag, bool? value) async {
    state = state.withOverride(flag, value);
    await ref.read(featureFlagStoreProvider).writeOverride(flag, value);
  }

  /// Toggles [flag] relative to its current effective value.
  Future<void> toggle(FeatureFlag flag) =>
      setOverride(flag, !state.isEnabled(flag));

  /// Restores every flag to its shipped default.
  Future<void> resetAll() async {
    state = state.reset();
    await ref.read(featureFlagStoreProvider).clear();
  }
}
