import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/cached_forecast_repository.dart';
import 'data/forecast_cache.dart';
import 'data/yr_no_weather_api.dart';
import 'domain/coordinates.dart';
import 'domain/forecast_repository.dart';
import 'domain/weather_api.dart';

/// The HTTP client used for forecast requests.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  ref.onDispose(dio.close);
  return dio;
});

/// The forecast source. Overridden in tests, and the seam where a server-side
/// implementation would slot in.
final weatherApiProvider = Provider<WeatherApi>((ref) {
  return YrNoWeatherApi(dio: ref.watch(dioProvider));
});

/// Where fetched forecasts are kept between launches.
final forecastCacheProvider = Provider<ForecastCache>((ref) {
  return FileForecastCache();
});

/// Forecasts, cached for six hours.
final forecastRepositoryProvider = Provider<ForecastRepository>((ref) {
  return CachedForecastRepository(
    api: ref.watch(weatherApiProvider),
    cache: ref.watch(forecastCacheProvider),
  );
});

/// The forecast for one set of coordinates.
final forecastProvider =
    FutureProvider.family<ForecastResult, Coordinates>((ref, coordinates) {
  return ref.watch(forecastRepositoryProvider).load(coordinates);
});
