import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/data/yr_no_weather_api.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/weather_api.dart';
import 'package:crop_alerts/features/weather/domain/weather_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the request dio would have sent and replays a canned response,
/// so the real client code — headers, query, status handling — is exercised.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final coordinates = Coordinates(latitude: 44.8078, longitude: 20.5656);
  final now = DateTime.utc(2026, 8, 25, 14, 43);
  late String fixtureJson;

  setUpAll(() {
    fixtureJson =
        File('test/fixtures/met_locationforecast_compact.json').readAsStringSync();
  });

  ({YrNoWeatherApi api, _RecordingAdapter adapter}) build({
    int statusCode = 200,
    String? body,
    Map<String, List<String>> headers = const {},
    DioException? failWith,
  }) {
    final adapter = _RecordingAdapter((options) {
      if (failWith != null) throw failWith;
      return ResponseBody.fromString(
        body ?? fixtureJson,
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      );
    });

    final dio = Dio()..httpClientAdapter = adapter;
    return (
      api: YrNoWeatherApi(
        dio: dio,
        parser: ForecastParser(localize: (utc) => utc.add(const Duration(hours: 2)).toUtc()),
        now: () => now,
      ),
      adapter: adapter,
    );
  }

  group('terms-of-service obligations', () {
    test('identifies the app and a contact address', () async {
      final built = build();
      await built.api.fetch(coordinates);

      final userAgent = built.adapter.lastRequest!.headers['User-Agent'] as String;
      expect(userAgent, contains('CropAlerts'));
      expect(
        userAgent,
        contains('@'),
        reason: 'MET Norway requires a reachable contact in the User-Agent',
      );
      expect(userAgent, isNot(contains('Dart')));
    });

    test('never sends more than four decimals of coordinate', () async {
      final built = build();
      await built.api.fetch(
        Coordinates(latitude: 44.80780123456, longitude: 20.56560987654),
      );

      final query = built.adapter.lastRequest!.queryParameters;
      expect(query['lat'], '44.8078');
      expect(query['lon'], '20.5656');
      // Five or more decimals returns 403 on newer MET products.
      for (final value in query.values) {
        expect((value! as String).split('.').last.length, lessThanOrEqualTo(4));
      }
    });

    test('requests the compact product', () async {
      final built = build();
      await built.api.fetch(coordinates);

      expect(built.adapter.lastRequest!.uri.path, endsWith('/2.0/compact'));
    });

    test('replays Last-Modified as If-Modified-Since', () async {
      final built = build();
      await built.api.fetch(
        coordinates,
        ifModifiedSince: 'Tue, 25 Aug 2026 14:43:12 GMT',
      );

      expect(
        built.adapter.lastRequest!.headers['If-Modified-Since'],
        'Tue, 25 Aug 2026 14:43:12 GMT',
      );
    });

    test('omits If-Modified-Since when nothing is cached', () async {
      final built = build();
      await built.api.fetch(coordinates);

      expect(
        built.adapter.lastRequest!.headers.containsKey('If-Modified-Since'),
        isFalse,
      );
    });
  });

  group('successful responses', () {
    test('returns a parsed forecast', () async {
      final built = build();
      final result = await built.api.fetch(coordinates);

      expect(result, isA<ForecastFetched>());
      final forecast = (result as ForecastFetched).forecast;
      expect(forecast.days, hasLength(10));
      expect(forecast.fetchedAt, now);
      expect(forecast.coordinates, coordinates);
    });

    test('carries Expires and Last-Modified through to the forecast', () async {
      final built = build(headers: {
        'expires': ['Tue, 25 Aug 2026 15:14:02 GMT'],
        'last-modified': ['Tue, 25 Aug 2026 14:43:12 GMT'],
      });

      final result = await built.api.fetch(coordinates) as ForecastFetched;

      expect(result.forecast.expiresAt, DateTime.utc(2026, 8, 25, 15, 14, 2));
      expect(result.forecast.lastModified, 'Tue, 25 Aug 2026 14:43:12 GMT');
    });

    test('survives a missing or unparseable Expires header', () async {
      final withoutHeader = build();
      final garbled = build(headers: {
        'expires': ['whenever'],
      });

      expect(
        ((await withoutHeader.api.fetch(coordinates)) as ForecastFetched)
            .forecast
            .expiresAt,
        isNull,
      );
      expect(
        ((await garbled.api.fetch(coordinates)) as ForecastFetched)
            .forecast
            .expiresAt,
        isNull,
      );
    });
  });

  group('304 Not Modified', () {
    test('is treated as success, not an error', () async {
      final built = build(statusCode: 304, body: '');
      final result = await built.api.fetch(
        coordinates,
        ifModifiedSince: 'Tue, 25 Aug 2026 14:43:12 GMT',
      );

      expect(result, isA<ForecastUnchanged>());
    });

    test('carries a refreshed Expires so the cache can be extended', () async {
      final built = build(
        statusCode: 304,
        body: '',
        headers: {
          'expires': ['Tue, 25 Aug 2026 16:00:00 GMT'],
          'last-modified': ['Tue, 25 Aug 2026 14:43:12 GMT'],
        },
      );

      final result = await built.api.fetch(coordinates) as ForecastUnchanged;

      expect(result.expiresAt, DateTime.utc(2026, 8, 25, 16));
      expect(result.lastModified, 'Tue, 25 Aug 2026 14:43:12 GMT');
    });
  });

  group('failures', () {
    DioException dioError(DioExceptionType type, {Response<dynamic>? response}) {
      return DioException(
        requestOptions: RequestOptions(path: YrNoWeatherApi.endpoint),
        type: type,
        response: response,
      );
    }

    test('a timeout is a network failure', () async {
      final built = build(
        failWith: dioError(DioExceptionType.receiveTimeout),
      );

      expect(
        () => built.api.fetch(coordinates),
        throwsA(isA<WeatherNetworkFailure>()),
      );
    });

    test('no connectivity is a network failure', () async {
      final built = build(
        failWith: dioError(DioExceptionType.connectionError),
      );

      expect(
        () => built.api.fetch(coordinates),
        throwsA(isA<WeatherNetworkFailure>()),
      );
    });

    test('429 is its own failure, since the terms require backing off',
        () async {
      final built = build(
        failWith: dioError(
          DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: YrNoWeatherApi.endpoint),
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['120'],
            }),
          ),
        ),
      );

      await expectLater(
        built.api.fetch(coordinates),
        throwsA(
          isA<WeatherRateLimitedFailure>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 120),
          ),
        ),
      );
    });

    test('403 for over-precise coordinates surfaces the status', () async {
      final built = build(
        failWith: dioError(
          DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: YrNoWeatherApi.endpoint),
            statusCode: 403,
          ),
        ),
      );

      await expectLater(
        built.api.fetch(coordinates),
        throwsA(
          isA<WeatherServerFailure>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('a non-JSON body is a format failure', () async {
      final built = build(body: '<html>maintenance</html>');

      expect(
        () => built.api.fetch(coordinates),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });

    test('valid JSON of the wrong shape is a format failure', () async {
      final built = build(body: jsonEncode({'unexpected': true}));

      expect(
        () => built.api.fetch(coordinates),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });
  });

  group('Coordinates', () {
    test('rounds to four decimals on construction', () {
      final precise = Coordinates(latitude: 44.80785555, longitude: 20.5656999);

      expect(precise.latitude, 44.8079);
      expect(precise.longitude, 20.5657);
    });

    test('clamps to the valid range', () {
      final beyond = Coordinates(latitude: 120, longitude: -400);

      expect(beyond.latitude, 90);
      expect(beyond.longitude, -180);
    });

    test('formats parameters with exactly four decimals', () {
      final whole = Coordinates(latitude: 45, longitude: 20);

      expect(whole.latitudeParam, '45.0000');
      expect(whole.longitudeParam, '20.0000');
    });

    test('value equality', () {
      expect(
        Coordinates(latitude: 44.8078, longitude: 20.5656),
        Coordinates(latitude: 44.80780001, longitude: 20.56559999),
      );
    });
  });
}
