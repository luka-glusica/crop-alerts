import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/weather_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the test to a fixed +02:00 zone (Belgrade in summer) so day bucketing
/// does not depend on where the tests happen to run.
DateTime belgradeSummer(DateTime utc) =>
    utc.add(const Duration(hours: 2)).toUtc();

Map<String, dynamic> document(List<Map<String, dynamic>> series, {String? updatedAt}) {
  return {
    'properties': {
      'meta': {'updated_at': updatedAt ?? '2026-08-25T13:16:50Z'},
      'timeseries': series,
    },
  };
}

Map<String, dynamic> entry(
  String time, {
  double? temperature,
  double? humidity,
  double? oneHour,
  double? sixHours,
  double? twelveHours,
}) {
  return {
    'time': time,
    'data': {
      if (temperature != null || humidity != null)
        'instant': {
          'details': {
            'air_temperature': ?temperature,
            'relative_humidity': ?humidity,
          },
        },
      if (oneHour != null)
        'next_1_hours': {
          'details': {'precipitation_amount': oneHour},
        },
      if (sixHours != null)
        'next_6_hours': {
          'details': {'precipitation_amount': sixHours},
        },
      if (twelveHours != null)
        'next_12_hours': {
          'details': {'precipitation_amount': twelveHours},
        },
    },
  };
}

void main() {
  final coordinates = Coordinates(latitude: 44.8078, longitude: 20.5656);
  final fetchedAt = DateTime.utc(2026, 8, 25, 14, 43);

  ForecastParser parser({int maxDays = 10}) =>
      ForecastParser(localize: belgradeSummer, maxDays: maxDays);

  group('precipitation, the part that overlaps', () {
    test('prefers the hourly block over a six-hour block at the same time', () {
      // This is the real shape of MET's first entry: 0.0 mm for the next hour
      // and 8.2 mm for the next six. Summing both would invent 8.2 mm of rain.
      final forecast = parser().parse(
        document([
          entry('2026-08-25T00:00:00Z',
              temperature: 20, humidity: 50, oneHour: 0.0, sixHours: 8.2),
          for (var hour = 1; hour < 6; hour++)
            entry('2026-08-25T0$hour:00:00Z',
                temperature: 20, humidity: 50, oneHour: 0.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days.single.precipitation, 0.0);
    });

    test('falls back to the six-hour block once hourly data runs out', () {
      final forecast = parser().parse(
        document([
          for (var hour = 0; hour < 6; hour++)
            entry('2026-08-25T0$hour:00:00Z',
                temperature: 20, humidity: 50, oneHour: 0.5),
          // Beyond three days MET only publishes six-hourly blocks.
          entry('2026-08-25T06:00:00Z',
              temperature: 20, humidity: 50, sixHours: 6.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      // 6 hourly readings of 0.5 plus one six-hour block of 6.0.
      expect(forecast.days.single.precipitation, closeTo(9.0, 0.001));
    });

    test('does not double count when blocks overlap in the middle', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-25T00:00:00Z',
              temperature: 20, humidity: 50, sixHours: 12.0),
          // Covered by the six-hour block above, so ignored.
          entry('2026-08-25T01:00:00Z',
              temperature: 20, humidity: 50, oneHour: 5.0),
          entry('2026-08-25T03:00:00Z',
              temperature: 20, humidity: 50, oneHour: 5.0),
          entry('2026-08-25T06:00:00Z',
              temperature: 20, humidity: 50, oneHour: 1.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days.single.precipitation, closeTo(13.0, 0.001));
    });

    test('splits a block that straddles local midnight across both days', () {
      // 22:00Z is 00:00 local; a six-hour block from 20:00Z spans 22:00–02:00
      // local, so four of its six hours belong to the following day.
      final forecast = parser().parse(
        document([
          entry('2026-08-25T20:00:00Z',
              temperature: 20, humidity: 50, sixHours: 6.0),
          entry('2026-08-26T02:00:00Z', temperature: 20, humidity: 50),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days, hasLength(2));
      expect(forecast.days[0].precipitation, closeTo(2.0, 0.05));
      expect(forecast.days[1].precipitation, closeTo(4.0, 0.05));
      // Nothing is lost in the split.
      expect(
        forecast.days.fold<double>(0, (sum, d) => sum + d.precipitation),
        closeTo(6.0, 0.05),
      );
    });

    test('uses the twelve-hour block only when nothing finer exists', () {
      final forecast = parser().parse(
        document([
          // 00:00Z is 02:00 local, so the whole twelve-hour block lands on the
          // same local day.
          entry('2026-08-25T00:00:00Z',
              temperature: 20, humidity: 50, twelveHours: 3.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days.single.precipitation, closeTo(3.0, 0.05));
    });

    test('a finer block wins over a twelve-hour one at the same time', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-25T00:00:00Z',
              temperature: 20,
              humidity: 50,
              oneHour: 0.4,
              sixHours: 6.0,
              twelveHours: 12.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days.single.precipitation, closeTo(0.4, 0.001));
    });

    test('a day with no precipitation blocks reports zero, not null', () {
      final forecast = parser().parse(
        document([entry('2026-08-25T00:00:00Z', temperature: 20, humidity: 50)]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days.single.precipitation, 0.0);
    });
  });

  group('daily aggregation', () {
    test('takes the minimum and maximum across the day', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-25T04:00:00Z', temperature: 12.4, humidity: 91.2),
          entry('2026-08-25T10:00:00Z', temperature: 27.8, humidity: 44.1),
          entry('2026-08-25T16:00:00Z', temperature: 22.0, humidity: 60.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      final day = forecast.days.single;
      expect(day.minTemperature, 12.4);
      expect(day.maxTemperature, 27.8);
      expect(day.minHumidity, 44.1);
      expect(day.maxHumidity, 91.2);
      expect(day.sampleCount, 3);
    });

    test('buckets by local date, not UTC date', () {
      // 23:00Z on the 25th is 01:00 local on the 26th.
      final forecast = parser().parse(
        document([
          entry('2026-08-25T23:00:00Z', temperature: 15, humidity: 80),
          entry('2026-08-26T10:00:00Z', temperature: 30, humidity: 40),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days, hasLength(1));
      expect(forecast.days.single.date, DateTime(2026, 8, 26));
      expect(forecast.days.single.minTemperature, 15);
    });

    test('skips readings missing either temperature or humidity', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-25T04:00:00Z', temperature: 12, humidity: 90),
          entry('2026-08-25T05:00:00Z', temperature: 99),
          entry('2026-08-25T06:00:00Z', humidity: 10),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      final day = forecast.days.single;
      expect(day.sampleCount, 1);
      expect(day.maxTemperature, 12);
      expect(day.minHumidity, 90);
    });

    test('caps the number of days returned', () {
      final forecast = parser(maxDays: 3).parse(
        document([
          for (var day = 1; day <= 10; day++)
            entry(
              '2026-09-${day.toString().padLeft(2, '0')}T10:00:00Z',
              temperature: 20,
              humidity: 50,
            ),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.days, hasLength(3));
      expect(forecast.days.first.date, DateTime(2026, 9));
    });

    test('returns days in chronological order even if the series is not', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-27T10:00:00Z', temperature: 20, humidity: 50),
          entry('2026-08-25T10:00:00Z', temperature: 20, humidity: 50),
          entry('2026-08-26T10:00:00Z', temperature: 20, humidity: 50),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(
        forecast.days.map((d) => d.date.day),
        [25, 26, 27],
      );
    });
  });

  group('current conditions', () {
    test('reads now from the first entry and the range from 24 hours', () {
      final forecast = parser().parse(
        document([
          entry('2026-08-25T12:00:00Z', temperature: 31.9, humidity: 31.4),
          entry('2026-08-25T20:00:00Z', temperature: 18.0, humidity: 70.0),
          entry('2026-08-26T11:00:00Z', temperature: 35.0, humidity: 25.0),
          // Beyond 24 hours, so excluded from the range.
          entry('2026-08-26T14:00:00Z', temperature: 99.0, humidity: 99.0),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.now.temperature, 31.9);
      expect(forecast.now.humidity, 31.4);
      expect(forecast.now.minTemperature24h, 18.0);
      expect(forecast.now.maxTemperature24h, 35.0);
    });

    test('totals precipitation over the next twelve hours only', () {
      final forecast = parser().parse(
        document([
          for (var hour = 0; hour < 24; hour++)
            entry(
              '2026-08-25T${hour.toString().padLeft(2, '0')}:00:00Z',
              temperature: 20,
              humidity: 50,
              oneHour: 1.0,
            ),
        ]),
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.now.precipitation12h, closeTo(12.0, 0.001));
    });
  });

  group('malformed input', () {
    test('rejects a document with no properties', () {
      expect(
        () => parser().parse(
          const {},
          coordinates: coordinates,
          fetchedAt: fetchedAt,
        ),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });

    test('rejects an empty time series', () {
      expect(
        () => parser().parse(
          document(const []),
          coordinates: coordinates,
          fetchedAt: fetchedAt,
        ),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });

    test('rejects a series where nothing is readable', () {
      expect(
        () => parser().parse(
          document([
            {'time': 'not a date', 'data': <String, dynamic>{}},
          ]),
          coordinates: coordinates,
          fetchedAt: fetchedAt,
        ),
        throwsA(isA<WeatherFormatFailure>()),
      );
    });

    test('falls back to the fetch time when updated_at is missing', () {
      final forecast = parser().parse(
        {
          'properties': {
            'timeseries': [
              entry('2026-08-25T10:00:00Z', temperature: 20, humidity: 50),
            ],
          },
        },
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.updatedAt, fetchedAt);
    });
  });

  group('against a real MET Norway response', () {
    late Map<String, dynamic> fixture;

    setUpAll(() {
      final raw = File('test/fixtures/met_locationforecast_compact.json')
          .readAsStringSync();
      fixture = jsonDecode(raw) as Map<String, dynamic>;
    });

    test('parses the captured Belgrade forecast', () {
      final forecast = parser().parse(
        fixture,
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      expect(forecast.updatedAt, DateTime.utc(2026, 8, 25, 13, 16, 50));
      expect(forecast.days, hasLength(10));
      expect(forecast.coordinates, coordinates);
    });

    test('produces physically sensible values throughout', () {
      final forecast = parser().parse(
        fixture,
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      for (final day in forecast.days) {
        expect(day.minTemperature, lessThanOrEqualTo(day.maxTemperature));
        expect(day.minHumidity, lessThanOrEqualTo(day.maxHumidity));
        expect(day.minHumidity, inInclusiveRange(0, 100));
        expect(day.maxHumidity, inInclusiveRange(0, 100));
        expect(day.minTemperature, inInclusiveRange(-60, 60));
        expect(day.precipitation, greaterThanOrEqualTo(0));
        expect(day.sampleCount, greaterThan(0));
      }
    });

    test('total precipitation stays under the naive sum of every block', () {
      final forecast = parser().parse(
        fixture,
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      var naive = 0.0;
      final series = (fixture['properties']
          as Map<String, dynamic>)['timeseries'] as List;
      for (final raw in series) {
        final data = (raw as Map<String, dynamic>)['data'] as Map<String, dynamic>;
        for (final block in ['next_1_hours', 'next_6_hours', 'next_12_hours']) {
          final details =
              (data[block] as Map<String, dynamic>?)?['details'] as Map?;
          final amount = details?['precipitation_amount'];
          if (amount is num) naive += amount.toDouble();
        }
      }

      final actual =
          forecast.days.fold<double>(0, (sum, d) => sum + d.precipitation);

      // The naive sum counts the same rain in overlapping blocks; ours does not.
      expect(actual, lessThan(naive));
      expect(actual, greaterThan(0));
    });

    test('days are consecutive with no gaps', () {
      final forecast = parser().parse(
        fixture,
        coordinates: coordinates,
        fetchedAt: fetchedAt,
      );

      for (var i = 1; i < forecast.days.length; i++) {
        expect(
          forecast.days[i].date.difference(forecast.days[i - 1].date).inDays,
          1,
        );
      }
    });
  });
}
