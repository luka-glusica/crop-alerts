import '../domain/coordinates.dart';
import '../domain/forecast.dart';
import '../domain/forecast_repository.dart';
import '../domain/weather_api.dart';
import '../domain/weather_failure.dart';
import 'forecast_cache.dart';

/// Serves forecasts from a cache, refreshing them every six hours.
///
/// Two separate constraints decide when a request may go out:
///
/// * the app's own policy — refresh no more often than [refreshInterval];
/// * MET Norway's terms — never re-request before the response's `Expires`.
///
/// They are not the same rule and neither implies the other. MET's `Expires` is
/// typically half an hour out, well inside six hours, so the app's policy
/// normally governs. But when MET asks for a longer wait, that wins, including
/// over a user-initiated refresh.
class CachedForecastRepository implements ForecastRepository {
  CachedForecastRepository({
    required this.api,
    required this.cache,
    DateTime Function()? now,
    this.refreshInterval = defaultRefreshInterval,
  }) : _now = now ?? DateTime.now;

  /// The six-hour cadence the app refreshes on.
  static const Duration defaultRefreshInterval = Duration(hours: 6);

  final WeatherApi api;
  final ForecastCache cache;
  final Duration refreshInterval;

  final DateTime Function() _now;

  /// Set when MET returns 429. Held in memory rather than persisted: it is a
  /// within-session guard against a user repeatedly pulling to refresh, and a
  /// stale one read at startup would block a legitimate first request.
  DateTime? _rateLimitedUntil;

  @override
  Future<ForecastResult> load(
    Coordinates coordinates, {
    bool forceRefresh = false,
  }) async {
    final cached = await cache.read(coordinates);
    final now = _now();

    if (cached != null && !_mayRequestNow(cached, now, forceRefresh)) {
      return ForecastResult(
        forecast: cached,
        source: ForecastSource.cache,
      );
    }

    try {
      final result = await api.fetch(
        coordinates,
        ifModifiedSince: cached?.lastModified,
      );

      switch (result) {
        case ForecastFetched(:final forecast):
          await cache.write(forecast);
          _rateLimitedUntil = null;
          return ForecastResult(
            forecast: forecast,
            source: ForecastSource.network,
          );

        case ForecastUnchanged(:final expiresAt, :final lastModified):
          _rateLimitedUntil = null;
          // Nothing was resent, but what we hold has just been confirmed
          // current, so its clock restarts rather than expiring again at once.
          if (cached == null) {
            throw const WeatherFormatFailure(
              'The service reported no change, but nothing is cached.',
            );
          }
          final refreshed = cached.copyWithCacheMetadata(
            fetchedAt: now,
            expiresAt: expiresAt,
            lastModified: lastModified,
          );
          await cache.write(refreshed);
          return ForecastResult(
            forecast: refreshed,
            source: ForecastSource.network,
          );
      }
    } on WeatherFailure catch (failure) {
      if (failure is WeatherRateLimitedFailure) {
        _rateLimitedUntil =
            now.add(failure.retryAfter ?? const Duration(minutes: 10));
      }

      // Old data with an explanation is more useful than an error screen.
      if (cached != null) {
        return ForecastResult(
          forecast: cached,
          source: ForecastSource.staleCache,
          failure: failure,
        );
      }
      rethrow;
    }
  }

  /// Whether a request may be sent, given what is cached and when.
  bool _mayRequestNow(Forecast cached, DateTime now, bool forceRefresh) {
    final backoff = _rateLimitedUntil;
    if (backoff != null && now.isBefore(backoff)) return false;

    // MET's Expires binds regardless of what the user asked for.
    final expiresAt = cached.expiresAt;
    if (expiresAt != null && now.isBefore(expiresAt)) return false;

    if (forceRefresh) return true;

    return !now.isBefore(cached.fetchedAt.add(refreshInterval));
  }

  @override
  Future<void> clear() async {
    _rateLimitedUntil = null;
    await cache.clear();
  }
}
