import 'dart:io';

import 'package:crop_alerts/features/weather/data/forecast_cache.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinates = Coordinates(latitude: 44.8078, longitude: 20.5656);
  final elsewhere = Coordinates(latitude: 45.2671, longitude: 19.8335);

  late Directory temp;
  late FileForecastCache cache;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('crop_alerts_cache_test');
    cache = FileForecastCache(directory: () async => temp);
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Forecast sample({Coordinates? at, double temperature = 21.5}) {
    return Forecast(
      coordinates: at ?? coordinates,
      updatedAt: DateTime.utc(2026, 8, 25, 13, 16, 50),
      fetchedAt: DateTime.utc(2026, 8, 25, 14, 43),
      expiresAt: DateTime.utc(2026, 8, 25, 15, 14, 2),
      lastModified: 'Tue, 25 Aug 2026 14:43:12 GMT',
      now: CurrentConditions(
        temperature: temperature,
        humidity: 63.2,
        minTemperature24h: 12.4,
        maxTemperature24h: 31.9,
        precipitation12h: 8.2,
      ),
      days: [
        DailyForecast(
          date: DateTime(2026, 8, 25),
          minTemperature: 12.4,
          maxTemperature: 31.9,
          minHumidity: 31.4,
          maxHumidity: 91.2,
          precipitation: 8.2,
          sampleCount: 18,
        ),
        DailyForecast(
          date: DateTime(2026, 8, 26),
          minTemperature: 14,
          maxTemperature: 27,
          minHumidity: 40,
          maxHumidity: 88,
          precipitation: 0,
          sampleCount: 24,
        ),
      ],
    );
  }

  test('round-trips a forecast through the filesystem', () async {
    final original = sample();
    await cache.write(original);

    final restored = (await cache.read(coordinates))!;

    expect(restored.coordinates, original.coordinates);
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.fetchedAt, original.fetchedAt);
    expect(restored.expiresAt, original.expiresAt);
    expect(restored.lastModified, original.lastModified);
    expect(restored.now, original.now);
    expect(restored.days, original.days);
  });

  test('returns null when nothing has been cached', () async {
    expect(await cache.read(coordinates), isNull);
  });

  test('creates its directory on first write', () async {
    final missing = Directory('${temp.path}/not_yet');
    final freshCache = FileForecastCache(directory: () async => missing);

    await freshCache.write(sample());

    expect(await freshCache.read(coordinates), isNotNull);
  });

  test('keeps a separate file per location', () async {
    await cache.write(sample(temperature: 30));
    await cache.write(sample(at: elsewhere, temperature: 18));

    expect((await cache.read(coordinates))!.now.temperature, 30);
    expect((await cache.read(elsewhere))!.now.temperature, 18);
    expect(temp.listSync().whereType<File>(), hasLength(2));
  });

  test('overwrites the previous forecast for the same location', () async {
    await cache.write(sample(temperature: 30));
    await cache.write(sample(temperature: 31));

    expect((await cache.read(coordinates))!.now.temperature, 31);
    expect(temp.listSync().whereType<File>(), hasLength(1));
  });

  test('filenames are filesystem safe and stable', () {
    final name = FileForecastCache.fileNameFor(coordinates);

    expect(name, isNot(contains('.json.')));
    expect(name, endsWith('.json'));
    expect(name, isNot(matches(RegExp(r'[\\/:*?"<>|]'))));
    expect(FileForecastCache.fileNameFor(coordinates), name);
  });

  test('locations differing only in sign do not collide', () {
    final north = Coordinates(latitude: 44.8078, longitude: 20.5656);
    final south = Coordinates(latitude: -44.8078, longitude: 20.5656);

    expect(
      FileForecastCache.fileNameFor(north),
      isNot(FileForecastCache.fileNameFor(south)),
    );
  });

  group('a damaged cache costs a refresh, not a crash', () {
    test('truncated JSON reads as empty', () async {
      await cache.write(sample());
      final file = temp
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.json'));
      await file.writeAsString('{"coordinates": {"latitu');

      expect(await cache.read(coordinates), isNull);
    });

    test('valid JSON of the wrong shape reads as empty', () async {
      await cache.write(sample());
      final file = temp
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.json'));
      await file.writeAsString('{"unexpected": true}');

      expect(await cache.read(coordinates), isNull);
    });

    test('a JSON array rather than an object reads as empty', () async {
      await cache.write(sample());
      final file = temp
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.json'));
      await file.writeAsString('[]');

      expect(await cache.read(coordinates), isNull);
    });
  });

  test('clear removes everything', () async {
    await cache.write(sample());
    await cache.write(sample(at: elsewhere));

    await cache.clear();

    expect(await cache.read(coordinates), isNull);
    expect(await cache.read(elsewhere), isNull);
  });

  test('clearing an empty cache is not an error', () async {
    await cache.clear();
    await cache.clear();
  });
}
