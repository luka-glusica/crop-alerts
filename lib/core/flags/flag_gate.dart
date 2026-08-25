import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flag.dart';
import 'feature_flags_provider.dart';

/// Shows [child] only while [flag] is enabled.
///
/// When the flag is off it renders [fallback], which defaults to nothing at
/// all — the usual case for a feature that is not shipped yet.
class FlagGate extends ConsumerWidget {
  const FlagGate({
    required this.flag,
    required this.child,
    this.fallback,
    super.key,
  });

  final FeatureFlag flag;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(featureFlagProvider(flag));
    if (enabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Convenience access to feature flags from a [WidgetRef].
extension FeatureFlagRefX on WidgetRef {
  /// Whether [flag] is currently enabled, rebuilding the widget when it changes.
  bool isEnabled(FeatureFlag flag) => watch(featureFlagProvider(flag));
}
