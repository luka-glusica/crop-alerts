import 'dart:ui';

import '../../l10n/generated/app_localizations.dart';
import '../crops/domain/crop_repository.dart';
import '../crops/domain/crop_risk_evaluator.dart';
import '../locations/domain/location_store.dart';
import '../weather/domain/forecast_repository.dart';
import '../weather/domain/weather_failure.dart';
import 'alert_digest.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

/// What one background run did.
enum AlertOutcome {
  /// A notification was shown.
  notified,

  /// Nothing crossed the grower's threshold.
  nothingToReport,

  /// The same alert had already been delivered.
  alreadyDelivered,

  /// The grower has not asked for notifications.
  notificationsDisabled,

  /// Permission was refused, or the platform will not show notifications.
  notPermitted,

  /// There is no plot to check.
  noLocation,

  /// The forecast could not be obtained and nothing was cached.
  forecastUnavailable,
}

/// One pass of the six-hourly job: refresh, re-evaluate, notify if warranted.
///
/// Deliberately free of `workmanager` and of any platform channel, so the whole
/// decision — including the de-duplication that stops the same news arriving
/// four times a day — is testable in an ordinary unit test. The worker and the
/// in-app "refresh now" trigger both run this.
class AlertRun {
  const AlertRun({
    required this.locations,
    required this.forecasts,
    required this.crops,
    required this.preferences,
    required this.notifications,
    required this.locale,
    this.evaluator = const CropRiskEvaluator(),
    this.horizonDays = 5,
  });

  final LocationStore locations;
  final ForecastRepository forecasts;
  final CropRepository crops;
  final NotificationPreferencesStore preferences;
  final NotificationService notifications;
  final Locale locale;
  final CropRiskEvaluator evaluator;

  /// How far ahead the digest looks. Five days matches the web version: far
  /// enough to act on, near enough to still be worth trusting.
  final int horizonDays;

  Future<AlertOutcome> execute({DateTime? now}) async {
    final settings = preferences.read();
    if (!settings.anyEnabled) return AlertOutcome.notificationsDisabled;

    final book = locations.read();
    final location = book?.active;
    if (location == null) return AlertOutcome.noLocation;

    if (!await notifications.prepare()) return AlertOutcome.notPermitted;

    final catalogue = await crops.load(locale);

    try {
      final result = await forecasts.load(location.coordinates);

      final digest = AlertDigest.build(
        assessments: evaluator.assessAll(
          crops: catalogue,
          forecast: result.forecast.days,
        ),
        preferences: settings,
        today: now ?? DateTime.now(),
        horizonDays: horizonDays,
      );
      if (digest == null) return AlertOutcome.nothingToReport;

      // Four runs a day would otherwise deliver the same outlook four times.
      // The key is built from the content, so a forecast that *worsens* still
      // gets through.
      if (preferences.readLastAlertKey() == digest.dedupeKey) {
        return AlertOutcome.alreadyDelivered;
      }

      final l10n = await AppLocalizations.delegate.load(locale);
      await notifications.showRiskAlert(
        title: l10n.appTitle,
        body: _body(digest, l10n),
      );
      await preferences.writeLastAlertKey(digest.dedupeKey);

      return AlertOutcome.notified;
    } on WeatherFailure {
      // The repository already falls back to cached data, so reaching here
      // means there is nothing to report on at all. A background job is the
      // wrong place to complain about it.
      return AlertOutcome.forecastUnavailable;
    }
  }

  /// Formats the digest the way the web version does: the counts, then the
  /// crops involved.
  String _body(AlertDigest digest, AppLocalizations l10n) {
    final parts = <String>[
      if (digest.highCount > 0) l10n.alertHighRisk(digest.highCount),
      if (digest.moderateCount > 0) l10n.alertModerateRisk(digest.moderateCount),
    ];

    // Naming every crop would run past what a notification shows; the worst
    // few are what matters.
    final names = digest.cropNames.take(4).join(', ');
    if (names.isNotEmpty) parts.add(l10n.alertCrops(names));

    return parts.join(' · ');
  }
}
