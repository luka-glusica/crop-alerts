/// Toggles that gate functionality which is either not finished yet, or that a
/// user may want to switch off.
///
/// The enum deliberately carries its own default and storage key so that adding
/// a flag is a one-line change and nothing has to be kept in sync elsewhere.
/// Flags whose default is `false` describe work planned for future releases —
/// the code paths they guard exist as interfaces and stubs so that switching
/// them on later does not require reshaping the architecture.
enum FeatureFlag {
  /// Six-hourly background forecast refresh plus local risk notifications.
  backgroundAlerts(
    defaultValue: true,
    description: 'Refresh the forecast every 6 hours and notify on high risk',
  ),

  /// Signed-in accounts. Planned; `authorId` already exists on crops and rules.
  authentication(
    defaultValue: false,
    description: 'Sign in to sync plots and contribute content',
  ),

  /// Crowd-sourced crops fetched from a server instead of bundled assets.
  communityCrops(
    defaultValue: false,
    description: 'Load community-contributed crops alongside the built-in ones',
  ),

  /// Rules fetched as JSON rather than read from bundled content.
  remoteRules(
    defaultValue: false,
    description: 'Fetch updated weather rules without shipping a new build',
  ),

  /// Rating whether a mitigation measure actually worked.
  mitigationRatings(
    defaultValue: false,
    description: 'Rate how well a piece of advice worked',
  ),

  /// Device GPS instead of manually entered coordinates.
  deviceLocation(
    defaultValue: false,
    description: 'Use the device location for the active plot',
  );

  const FeatureFlag({
    required this.defaultValue,
    required this.description,
  });

  /// Value used when the user has not overridden the flag.
  final bool defaultValue;

  /// Developer-facing explanation, shown in the debug settings screen.
  final String description;

  /// Key under which an override for this flag is persisted.
  String get storageKey => 'feature_flag.$name';

  /// Resolves a flag from its [name], or `null` if it no longer exists.
  ///
  /// Persisted overrides outlive the code that reads them, so a removed flag
  /// must not crash the app on the next launch.
  static FeatureFlag? byName(String name) {
    for (final flag in values) {
      if (flag.name == name) return flag;
    }
    return null;
  }
}
