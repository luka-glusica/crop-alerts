import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/coordinates.dart';
import '../domain/forecast.dart';

/// Stores the last forecast fetched for each set of coordinates.
///
/// Keyed by location so that several saved plots each keep their own copy and
/// switching between them does not trigger a refresh.
abstract class ForecastCache {
  /// The cached forecast for [coordinates], or `null` if there is none.
  Future<Forecast?> read(Coordinates coordinates);

  /// Stores [forecast] under its own coordinates.
  Future<void> write(Forecast forecast);

  /// Removes every cached forecast.
  Future<void> clear();
}

/// [ForecastCache] backed by one JSON file per location.
///
/// A forecast is a few kilobytes of JSON that is only ever read whole, so a
/// file per location is a better fit than a database — and it survives being
/// read from the background isolate without any setup.
class FileForecastCache implements ForecastCache {
  FileForecastCache({Future<Directory> Function()? directory})
      : _resolveDirectory = directory ?? _defaultDirectory;

  static const String folderName = 'forecasts';

  final Future<Directory> Function() _resolveDirectory;

  static Future<Directory> _defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/$folderName');
  }

  /// A filename that is stable for a location and safe on every platform.
  static String fileNameFor(Coordinates coordinates) {
    final latitude = coordinates.latitudeParam.replaceAll('.', '_');
    final longitude = coordinates.longitudeParam.replaceAll('.', '_');
    return 'forecast_${latitude}__$longitude.json';
  }

  @override
  Future<Forecast?> read(Coordinates coordinates) async {
    try {
      final directory = await _resolveDirectory();
      final file = File('${directory.path}/${fileNameFor(coordinates)}');
      // Reading and catching beats an exists() check: it avoids a second
      // filesystem round trip and the race between the two.
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return Forecast.fromJson(json);
    } on FileSystemException {
      return null;
    } on FormatException {
      // A truncated or outdated cache file should cost a refresh, not a crash.
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(Forecast forecast) async {
    final directory = await _resolveDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/${fileNameFor(forecast.coordinates)}');
    await file.writeAsString(jsonEncode(forecast.toJson()), flush: true);
  }

  @override
  Future<void> clear() async {
    final directory = await _resolveDirectory();
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Nothing cached yet.
    }
  }
}

/// [ForecastCache] held in memory, for tests and for a single background run.
class InMemoryForecastCache implements ForecastCache {
  final Map<String, Forecast> _entries = {};

  /// How many forecasts are held, for assertions in tests.
  int get length => _entries.length;

  @override
  Future<Forecast?> read(Coordinates coordinates) async =>
      _entries[_key(coordinates)];

  @override
  Future<void> write(Forecast forecast) async =>
      _entries[_key(forecast.coordinates)] = forecast;

  @override
  Future<void> clear() async => _entries.clear();

  static String _key(Coordinates coordinates) =>
      '${coordinates.latitudeParam},${coordinates.longitudeParam}';
}
