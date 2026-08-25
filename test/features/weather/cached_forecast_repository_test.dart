import 'package:crop_alerts/features/weather/data/cached_forecast_repository.dart';
import 'package:crop_alerts/features/weather/data/forecast_cache.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast_repository.dart';
import 'package:crop_alerts/features/weather/domain/weather_api.dart';
import 'package:crop_alerts/features/weather/domain/weather_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// A WeatherApi whose every response is scripted, recording what it was asked.
class _ScriptedApi implements WeatherApi {
  _ScriptedApi(this._responses);

  final List<Object> _responses;
  final List<String?> ifModifiedSinceSeen = [];
  int calls = 0;

  @override
  Future<ForecastFetchResult> fetch(
    Coordinates coordinates, {
    String? ifModifiedSince,
  }) async {
    calls++;
    ifModifiedSinceSeen.add(ifModifiedSince);

    final response = _responses.isEmpty
        ? _responses
        : _responses.removeAt(0);
    if (response is ForecastFetchResult) return response;
    if (response is WeatherFailure) throw response;
    throw StateError('The scripted API ran out of responses.');
  }
}

void main() {
  final coordinates = Coordinates(latitude: 44.8078, longitude: 20.5656);
  final elsewhere = Coordinates(latitude: 45.2671, longitude: 19.8335);

  Forecast forecastAt(
    DateTime fetchedAt, {
    Coordinates? at,
    DateTime? expiresAt,
    String? lastModified,
    double temperature = 20,
  }) {
    return Forecast(
      coordinates: at ?? coordinates,
      updatedAt: fetchedAt.subtract(const Duration(minutes: 30)),
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      lastModified: lastModified,
      now: CurrentConditions(
        temperature: temperature,
        humidity: 60,
        minTemperature24h: 12,
        maxTemperature24h: 28,
        precipitation12h: 0,
      ),
      days: [
        DailyForecast(
          date: DateTime(fetchedAt.year, fetchedAt.month, fetchedAt.day),
          minTemperature: 12,
          maxTemperature: 28,
          minHumidity: 40,
          maxHumidity: 90,
          precipitation: 0,
          sampleCount: 24,
        ),
      ],
    );
  }

  CachedForecastRepository build({
    required List<Object> responses,
    required DateTime now,
    ForecastCache? cache,
  }) {
    return CachedForecastRepository(
      api: _ScriptedApi(responses),
      cache: cache ?? InMemoryForecastCache(),
      now: () => now,
    );
  }

  group('the six-hour policy', () {
    test('serves the cache while it is under six hours old', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(hours: 5, minutes: 59))));

      final api = _ScriptedApi([]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.cache);
      expect(api.calls, 0, reason: 'no request should have gone out');
    });

    test('refreshes once six hours have passed', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(hours: 6))));

      final fresh = forecastAt(now, temperature: 31);
      final api = _ScriptedApi([ForecastFetched(fresh)]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.network);
      expect(result.forecast.now.temperature, 31);
      expect(api.calls, 1);
    });

    test('fetches when nothing is cached', () async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final repository = build(
        responses: [ForecastFetched(forecastAt(now))],
        now: now,
      );

      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.network);
    });

    test('a forced refresh overrides the six-hour policy', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(minutes: 5))));

      final api = _ScriptedApi([ForecastFetched(forecastAt(now, temperature: 33))]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates, forceRefresh: true);

      expect(result.source, ForecastSource.network);
      expect(api.calls, 1);
    });

    test('the refresh interval is configurable', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(minutes: 30))));

      final api = _ScriptedApi([ForecastFetched(forecastAt(now))]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
        refreshInterval: const Duration(minutes: 15),
      );

      expect((await repository.load(coordinates)).source, ForecastSource.network);
    });
  });

  group("MET Norway's Expires header", () {
    test('blocks a refresh that the six-hour policy would allow', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      // Older than six hours, but MET asked us to wait until 13:00.
      await cache.write(
        forecastAt(
          now.subtract(const Duration(hours: 8)),
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      final api = _ScriptedApi([]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.cache);
      expect(api.calls, 0);
    });

    test('blocks even a user-initiated refresh', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(
        forecastAt(now, expiresAt: now.add(const Duration(minutes: 30))),
      );

      final api = _ScriptedApi([]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates, forceRefresh: true);

      expect(result.source, ForecastSource.cache);
      expect(
        api.calls,
        0,
        reason: 'their terms bind regardless of what the user pressed',
      );
    });

    test('stops blocking once it has passed', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(
        forecastAt(
          now.subtract(const Duration(hours: 7)),
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      final api = _ScriptedApi([ForecastFetched(forecastAt(now))]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      expect((await repository.load(coordinates)).source, ForecastSource.network);
    });
  });

  group('304 Not Modified', () {
    test('restarts the clock on data we already hold', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      final old = forecastAt(
        now.subtract(const Duration(hours: 7)),
        lastModified: 'Tue, 25 Aug 2026 05:00:00 GMT',
        temperature: 19,
      );
      await cache.write(old);

      final api = _ScriptedApi([
        ForecastUnchanged(
          expiresAt: now.add(const Duration(minutes: 30)),
          lastModified: 'Tue, 25 Aug 2026 05:00:00 GMT',
        ),
      ]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.network);
      // The data is unchanged...
      expect(result.forecast.now.temperature, 19);
      expect(result.forecast.updatedAt, old.updatedAt);
      // ...but it counts as freshly confirmed.
      expect(result.forecast.fetchedAt, now);
      expect((await cache.read(coordinates))!.fetchedAt, now);
    });

    test('sends the cached Last-Modified as If-Modified-Since', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(
        forecastAt(
          now.subtract(const Duration(hours: 7)),
          lastModified: 'Tue, 25 Aug 2026 05:00:00 GMT',
        ),
      );

      final api = _ScriptedApi([const ForecastUnchanged()]);
      await CachedForecastRepository(api: api, cache: cache, now: () => now)
          .load(coordinates);

      expect(api.ifModifiedSinceSeen, ['Tue, 25 Aug 2026 05:00:00 GMT']);
    });

    test('sends nothing when there is no cache to validate', () async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final api = _ScriptedApi([ForecastFetched(forecastAt(now))]);
      await CachedForecastRepository(
        api: api,
        cache: InMemoryForecastCache(),
        now: () => now,
      ).load(coordinates);

      expect(api.ifModifiedSinceSeen, [null]);
    });

    test('a 304 with nothing cached is a format failure, not a crash', () async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final repository = build(
        responses: [const ForecastUnchanged()],
        now: now,
      );

      expect(
        () => repository.load(coordinates),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });
  });

  group('when the network fails', () {
    test('falls back to stale cache and explains why', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(
        forecastAt(now.subtract(const Duration(hours: 30)), temperature: 17),
      );

      final repository = CachedForecastRepository(
        api: _ScriptedApi([const WeatherNetworkFailure('offline')]),
        cache: cache,
        now: () => now,
      );
      final result = await repository.load(coordinates);

      expect(result.source, ForecastSource.staleCache);
      expect(result.isStale, isTrue);
      expect(result.forecast.now.temperature, 17);
      expect(result.failure, isA<WeatherNetworkFailure>());
      expect(result.forecast.ageAt(now), const Duration(hours: 30));
    });

    test('rethrows when there is no cache to fall back on', () async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final repository = build(
        responses: [const WeatherNetworkFailure('offline')],
        now: now,
      );

      expect(
        () => repository.load(coordinates),
        throwsA(isA<WeatherNetworkFailure>()),
      );
    });

    test('does not overwrite the cache with nothing', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      final original = forecastAt(now.subtract(const Duration(hours: 30)));
      await cache.write(original);

      await CachedForecastRepository(
        api: _ScriptedApi([const WeatherServerFailure('500', statusCode: 500)]),
        cache: cache,
        now: () => now,
      ).load(coordinates);

      expect((await cache.read(coordinates))!.fetchedAt, original.fetchedAt);
    });
  });

  group('rate limiting', () {
    test('stops requesting for as long as Retry-After asks', () async {
      final cache = InMemoryForecastCache();
      var now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(hours: 7))));

      final api = _ScriptedApi([
        const WeatherRateLimitedFailure('429', retryAfter: Duration(minutes: 20)),
        ForecastFetched(forecastAt(now)),
      ]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      expect((await repository.load(coordinates)).source, ForecastSource.staleCache);
      expect(api.calls, 1);

      // Ten minutes later, still inside the backoff.
      now = now.add(const Duration(minutes: 10));
      expect(
        (await repository.load(coordinates, forceRefresh: true)).source,
        ForecastSource.cache,
      );
      expect(api.calls, 1, reason: 'must not retry inside the backoff window');
    });

    test('backs off for a default period when Retry-After is absent', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now.subtract(const Duration(hours: 7))));

      final api = _ScriptedApi([
        const WeatherRateLimitedFailure('429'),
        ForecastFetched(forecastAt(now)),
      ]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      await repository.load(coordinates);
      await repository.load(coordinates, forceRefresh: true);

      expect(api.calls, 1);
    });

    test('a successful request clears the backoff', () async {
      var now = DateTime.utc(2026, 8, 25, 12);
      final cache = InMemoryForecastCache();
      await cache.write(forecastAt(now.subtract(const Duration(hours: 7))));

      final api = _ScriptedApi([
        const WeatherRateLimitedFailure('429', retryAfter: Duration(minutes: 5)),
        ForecastFetched(forecastAt(now.add(const Duration(minutes: 6)))),
        ForecastFetched(forecastAt(now.add(const Duration(minutes: 7)))),
      ]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      await repository.load(coordinates);
      now = now.add(const Duration(minutes: 6));
      final recovered = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );
      expect((await recovered.load(coordinates)).source, ForecastSource.network);
    });
  });

  group('several plots', () {
    test('each location caches independently', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);

      final api = _ScriptedApi([
        ForecastFetched(forecastAt(now, temperature: 30)),
        ForecastFetched(forecastAt(now, at: elsewhere, temperature: 22)),
      ]);
      final repository = CachedForecastRepository(
        api: api,
        cache: cache,
        now: () => now,
      );

      expect((await repository.load(coordinates)).forecast.now.temperature, 30);
      expect((await repository.load(elsewhere)).forecast.now.temperature, 22);
      expect(cache.length, 2);

      // Both are now cached, so neither refetches.
      expect((await repository.load(coordinates)).source, ForecastSource.cache);
      expect((await repository.load(elsewhere)).source, ForecastSource.cache);
      expect(api.calls, 2);
    });

    test('clear empties every location', () async {
      final cache = InMemoryForecastCache();
      final now = DateTime.utc(2026, 8, 25, 12);
      await cache.write(forecastAt(now));
      await cache.write(forecastAt(now, at: elsewhere));

      await CachedForecastRepository(
        api: _ScriptedApi([]),
        cache: cache,
        now: () => now,
      ).clear();

      expect(cache.length, 0);
    });
  });
}
