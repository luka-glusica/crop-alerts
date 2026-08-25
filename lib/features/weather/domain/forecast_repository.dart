import 'package:flutter/foundation.dart';

import 'coordinates.dart';
import 'forecast.dart';
import 'weather_failure.dart';

/// Where a forecast came from.
enum ForecastSource {
  /// Freshly downloaded.
  network,

  /// Read from the cache while still considered current.
  cache,

  /// Read from the cache after a failed refresh. The data is past its age
  /// limit, but showing yesterday's forecast beats showing nothing.
  staleCache,
}

/// A forecast plus how it was obtained.
@immutable
class ForecastResult {
  const ForecastResult({
    required this.forecast,
    required this.source,
    this.failure,
  });

  final Forecast forecast;
  final ForecastSource source;

  /// Why the refresh failed, when [source] is [ForecastSource.staleCache].
  ///
  /// The UI uses this to explain itself — "showing saved data, no network" —
  /// rather than silently presenting old numbers as current.
  final WeatherFailure? failure;

  bool get isStale => source == ForecastSource.staleCache;
}

/// Supplies forecasts, deciding when to go to the network.
abstract class ForecastRepository {
  /// Returns the forecast for [coordinates].
  ///
  /// Serves the cache while it is current, otherwise refreshes. Pass
  /// [forceRefresh] for an explicit pull-to-refresh; note that MET Norway's
  /// terms are still honoured, so a forced refresh before the response's
  /// `Expires` time will still be served from cache.
  ///
  /// Throws a [WeatherFailure] only when the network fails and there is no
  /// cached forecast to fall back on.
  Future<ForecastResult> load(
    Coordinates coordinates, {
    bool forceRefresh = false,
  });

  /// Drops every cached forecast.
  Future<void> clear();
}
