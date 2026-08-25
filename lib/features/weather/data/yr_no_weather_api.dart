import 'package:dio/dio.dart';

import '../domain/coordinates.dart';
import '../domain/weather_api.dart';
import '../domain/weather_failure.dart';
import 'forecast_parser.dart';

/// MET Norway's `locationforecast` product, the same one the web app uses.
///
/// Their terms of service are enforced with blocks rather than warnings, so the
/// obligations are implemented here rather than left to callers:
///
/// * every request identifies the application and a contact address;
/// * coordinates are capped at four decimals, since newer products answer 403
///   for anything more precise;
/// * `Last-Modified` is replayed as `If-Modified-Since` so unchanged forecasts
///   come back as a 304 instead of a fresh download;
/// * `Expires` is carried through so the caller can honour it;
/// * a 429 is surfaced as its own failure, because their terms require backing
///   off immediately rather than retrying.
///
/// See https://api.met.no/doc/TermsOfService
class YrNoWeatherApi implements WeatherApi {
  YrNoWeatherApi({Dio? dio, ForecastParser? parser, DateTime Function()? now})
      : _dio = dio ?? Dio(),
        _parser = parser ?? ForecastParser(),
        _now = now ?? DateTime.now;

  /// The compact variant carries everything the rules need at a third the size
  /// of the complete one.
  static const String endpoint =
      'https://api.met.no/weatherapi/locationforecast/2.0/compact';

  /// Identifies this application to MET Norway.
  ///
  /// Their terms treat a missing, fake or copied identifier as grounds for a
  /// permanent ban, so this must stay a real, reachable contact.
  static const String userAgent =
      'CropAlerts/1.0 (luka.glusica89.dev@gmail.com)';

  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 20);

  final Dio _dio;
  final ForecastParser _parser;
  final DateTime Function() _now;

  @override
  Future<ForecastFetchResult> fetch(
    Coordinates coordinates, {
    String? ifModifiedSince,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        endpoint,
        queryParameters: {
          'lat': coordinates.latitudeParam,
          'lon': coordinates.longitudeParam,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
            'If-Modified-Since': ?ifModifiedSince,
          },
          sendTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          // 304 is a successful outcome here, not an error.
          validateStatus: (status) =>
              status != null && (status == 304 || (status >= 200 && status < 300)),
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }

    if (response.statusCode == 304) {
      return ForecastUnchanged(
        expiresAt: _expiresAt(response.headers),
        lastModified: _header(response.headers, 'last-modified'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw WeatherFormatFailure(
        'Expected a JSON object but received ${data.runtimeType}.',
      );
    }

    return ForecastFetched(
      _parser.parse(
        data,
        coordinates: coordinates,
        fetchedAt: _now(),
        expiresAt: _expiresAt(response.headers),
        lastModified: _header(response.headers, 'last-modified'),
      ),
    );
  }

  WeatherFailure _mapError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const WeatherNetworkFailure('The forecast request timed out.');
      case DioExceptionType.connectionError:
        return WeatherNetworkFailure(
          error.message ?? 'Could not reach the forecast service.',
        );
      case DioExceptionType.unknown:
        // dio reports a body it could not decode as "unknown". Reporting that
        // as a network failure would tell the user they are offline when in
        // fact the server answered with something unreadable.
        if (error.error is FormatException) {
          return WeatherFormatFailure(
            'The forecast service returned a body that is not JSON: '
            '${(error.error! as FormatException).message}',
          );
        }
        return WeatherNetworkFailure(
          error.message ?? 'Could not reach the forecast service.',
        );
      case DioExceptionType.cancel:
        return const WeatherNetworkFailure('The forecast request was cancelled.');
      case DioExceptionType.badCertificate:
        return const WeatherNetworkFailure(
          'The forecast service presented an invalid certificate.',
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 429) {
          return WeatherRateLimitedFailure(
            'MET Norway is rate limiting this client.',
            retryAfter: _retryAfter(error.response?.headers),
          );
        }
        return WeatherServerFailure(
          'The forecast service returned $status.',
          statusCode: status,
        );
    }
  }

  static String? _header(Headers headers, String name) =>
      headers.value(name)?.trim();

  static DateTime? _expiresAt(Headers headers) {
    final raw = _header(headers, 'expires');
    if (raw == null) return null;
    return _parseHttpDate(raw);
  }

  static Duration? _retryAfter(Headers? headers) {
    if (headers == null) return null;
    final raw = _header(headers, 'retry-after');
    if (raw == null) return null;

    // Retry-After is either a number of seconds or an HTTP date.
    final seconds = int.tryParse(raw);
    if (seconds != null) return Duration(seconds: seconds);

    final date = _parseHttpDate(raw);
    if (date == null) return null;
    final delay = date.difference(DateTime.now().toUtc());
    return delay.isNegative ? Duration.zero : delay;
  }

  /// Parses an RFC 1123 date such as `Tue, 25 Aug 2026 15:14:02 GMT`.
  ///
  /// Returns `null` rather than throwing: a malformed cache header should cost
  /// us a cache hit, not the whole forecast.
  static DateTime? _parseHttpDate(String value) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12, //
    };

    final match = RegExp(
      r'^\w{3},\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final month = months[match.group(2)];
    if (month == null) return null;

    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
