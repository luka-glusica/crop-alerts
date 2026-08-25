import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crops/crop_providers.dart';
import '../crops/domain/crop_assessment.dart';
import '../locations/domain/saved_location.dart';
import '../locations/locations_controller.dart';
import '../rules/domain/risk.dart';
import '../weather/domain/forecast.dart';
import '../weather/domain/forecast_repository.dart';
import '../weather/domain/weather_failure.dart';
import '../weather/weather_providers.dart';

/// Everything one screen needs: where, what the weather is doing, and what that
/// means for each crop.
@immutable
class Dashboard {
  const Dashboard({
    required this.location,
    required this.forecast,
    required this.assessments,
    required this.source,
    this.failure,
  });

  final SavedLocation location;
  final Forecast forecast;

  /// Every crop, worst first, dormant ones last.
  final List<CropAssessment> assessments;

  final ForecastSource source;

  /// Why the last refresh failed, when showing saved data.
  final WeatherFailure? failure;

  /// Whether the forecast shown is older than it should be.
  bool get isStale => source == ForecastSource.staleCache;

  /// Crops currently in their growing season.
  List<CropAssessment> get growing =>
      assessments.where((a) => !a.isDormant).toList();

  /// Crops out of season, which the dashboard collapses.
  List<CropAssessment> get dormant =>
      assessments.where((a) => a.isDormant).toList();

  /// How many growing crops have anything to worry about.
  int get atRiskCount => growing.where((a) => a.hasRisk).length;

  /// The worst level across every growing crop.
  RiskLevel get worst {
    var worst = RiskLevel.low;
    for (final assessment in growing) {
      if (assessment.overall > worst) worst = assessment.overall;
    }
    return worst;
  }
}

/// The dashboard for the active plot, in the given locale.
///
/// Keyed by locale because the crop catalogue is localized content: switching
/// language genuinely changes the data, not just the chrome.
final dashboardProvider = FutureProvider.family<Dashboard?, Locale>(
  // Riverpod retries a failing provider automatically, with backoff. That is
  // wrong here: a first launch with no signal would sit on a spinner forever
  // instead of showing the failure and a retry button, and every silent attempt
  // is another request MET Norway did not ask for. Retrying is the grower's
  // decision, made by pulling to refresh or pressing the button.
  retry: (retryCount, error) => null,
  (ref, locale) async {
    final location = ref.watch(activeLocationProvider);
    // Every plot deleted. The screen shows an empty state rather than an error.
    if (location == null) return null;

    final crops = await ref.watch(cropsProvider(locale).future);
    final result =
        await ref.watch(forecastRepositoryProvider).load(location.coordinates);

    return Dashboard(
      location: location,
      forecast: result.forecast,
      assessments: ref.watch(cropRiskEvaluatorProvider).assessAll(
            crops: crops,
            forecast: result.forecast.days,
          ),
      source: result.source,
      failure: result.failure,
    );
  },
);

/// Forces a refresh for the active plot, then rebuilds the dashboard.
///
/// MET Norway's `Expires` still applies, so this does not guarantee a request
/// goes out — which is deliberate; their terms bind regardless of what the user
/// pressed.
Future<void> refreshDashboard(WidgetRef ref, Locale locale) async {
  final location = ref.read(activeLocationProvider);
  if (location == null) return;

  try {
    await ref
        .read(forecastRepositoryProvider)
        .load(location.coordinates, forceRefresh: true);
  } on WeatherFailure {
    // The rebuild below surfaces the failure through the normal path, which
    // already knows how to fall back to cached data.
  }
  ref.invalidate(dashboardProvider(locale));
  await ref.read(dashboardProvider(locale).future);
}
