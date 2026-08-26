import 'coordinates.dart';
import 'forecast.dart';
import 'weather_failure.dart';

/// Fetches a weather forecast for a point on the map.
///
/// Kept as an interface so the yr.no implementation can be swapped for a
/// server-side one later without touching anything above it — and so tests can
/// run against canned data.
abstract class WeatherApi {
  /// Fetches the forecast for [coordinates].
  ///
  /// Pass the [Forecast.lastModified] of data already held as [ifModifiedSince]
  /// to let the server answer with [ForecastUnchanged] instead of resending a
  /// forecast that has not been recalculated.
  ///
  /// Throws a [WeatherFailure] subclass on failure.
  Future<ForecastFetchResult> fetch(
    Coordinates coordinates, {
    String? ifModifiedSince,
  });
}

/// Outcome of a successful request.
sealed class ForecastFetchResult {
  const ForecastFetchResult();
}

/// The server sent a forecast.
class ForecastFetched extends ForecastFetchResult {
  const ForecastFetched(this.forecast);

  final Forecast forecast;
}

/// The server answered 304: what we already hold is still current.
class ForecastUnchanged extends ForecastFetchResult {
  const ForecastUnchanged({this.expiresAt, this.lastModified});

  /// A refreshed `Expires`, if the 304 carried one.
  final DateTime? expiresAt;

  /// A refreshed `Last-Modified`, if the 304 carried one.
  final String? lastModified;
}
