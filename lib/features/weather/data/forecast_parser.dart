import '../domain/coordinates.dart';
import '../domain/daily_forecast.dart';
import '../domain/forecast.dart';
import '../domain/weather_failure.dart';

/// Converts a time in UTC to the calendar day it belongs to for the user.
typedef Localize = DateTime Function(DateTime utc);

/// Turns a MET Norway `locationforecast/2.0/compact` document into a [Forecast].
///
/// The interesting part is precipitation. Each entry in the series may carry
/// `next_1_hours`, `next_6_hours` and `next_12_hours` blocks that describe
/// *overlapping* spans — the first entry of a real response typically has both
/// a 1-hour and a 6-hour amount for the same moment — so adding up every block
/// counts the same rain several times over. Instead the series is walked once,
/// tracking how far ahead precipitation has already been accounted for, and the
/// finest block that starts at or after that point is used.
///
/// MET drops from hourly to six-hourly resolution after roughly three days, so
/// this is not an edge case: it is most of a ten-day forecast.
class ForecastParser {
  ForecastParser({Localize? localize, this.maxDays = 10})
      : _localize = localize ?? _toLocal;

  /// Days to keep. MET returns about ten.
  final int maxDays;

  final Localize _localize;

  static DateTime _toLocal(DateTime utc) => utc.toLocal();

  /// Parses [json] into a forecast for [coordinates].
  ///
  /// Throws [WeatherFormatFailure] if the document is not shaped as expected.
  Forecast parse(
    Map<String, dynamic> json, {
    required Coordinates coordinates,
    required DateTime fetchedAt,
    DateTime? expiresAt,
    String? lastModified,
  }) {
    final properties = json['properties'];
    if (properties is! Map<String, dynamic>) {
      throw const WeatherFormatFailure('Response has no "properties" object.');
    }

    final rawSeries = properties['timeseries'];
    if (rawSeries is! List || rawSeries.isEmpty) {
      throw const WeatherFormatFailure('Forecast contains no time series.');
    }

    final entries = <_Entry>[];
    for (final raw in rawSeries) {
      final entry = _Entry.tryParse(raw);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty) {
      throw const WeatherFormatFailure('Forecast contains no readable entries.');
    }
    entries.sort((a, b) => a.time.compareTo(b.time));

    return Forecast(
      coordinates: coordinates,
      updatedAt: _updatedAt(properties) ?? fetchedAt,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      lastModified: lastModified,
      now: _currentConditions(entries),
      days: _dailySummaries(entries),
    );
  }

  DateTime? _updatedAt(Map<String, dynamic> properties) {
    final meta = properties['meta'];
    if (meta is! Map<String, dynamic>) return null;
    final updated = meta['updated_at'];
    if (updated is! String) return null;
    return DateTime.tryParse(updated);
  }

  CurrentConditions _currentConditions(List<_Entry> entries) {
    final first = entries.first;
    final next24h = _entriesWithin(entries, const Duration(hours: 24));

    final temperatures = next24h
        .map((e) => e.temperature)
        .whereType<double>()
        .toList(growable: false);

    return CurrentConditions(
      temperature: _round(first.temperature ?? 0),
      humidity: _round(first.humidity ?? 0),
      minTemperature24h: _round(
        temperatures.isEmpty ? 0 : temperatures.reduce(_min),
      ),
      maxTemperature24h: _round(
        temperatures.isEmpty ? 0 : temperatures.reduce(_max),
      ),
      precipitation12h: _round(
        _precipitationOver(entries, const Duration(hours: 12)),
      ),
    );
  }

  List<_Entry> _entriesWithin(List<_Entry> entries, Duration window) {
    final cutoff = entries.first.time.add(window);
    return entries.where((e) => !e.time.isAfter(cutoff)).toList(growable: false);
  }

  /// Total precipitation over [window] starting at the first entry, using the
  /// same non-overlapping walk as the daily totals.
  double _precipitationOver(List<_Entry> entries, Duration window) {
    final start = entries.first.time;
    final end = start.add(window);
    var total = 0.0;

    for (final span in _precipitationSpans(entries)) {
      final overlapStart = span.start.isAfter(start) ? span.start : start;
      final overlapEnd = span.end.isBefore(end) ? span.end : end;
      if (!overlapEnd.isAfter(overlapStart)) continue;

      final fraction = overlapEnd.difference(overlapStart).inMinutes /
          span.end.difference(span.start).inMinutes;
      total += span.amount * fraction;
    }

    return total;
  }

  /// Walks the series once, emitting non-overlapping precipitation spans.
  ///
  /// At each entry, the finest block available is taken and the cursor moves to
  /// the end of it; blocks that start before the cursor are already covered and
  /// are skipped.
  List<_PrecipitationSpan> _precipitationSpans(List<_Entry> entries) {
    final spans = <_PrecipitationSpan>[];
    DateTime? coveredUntil;

    for (final entry in entries) {
      if (coveredUntil != null && entry.time.isBefore(coveredUntil)) continue;

      final block = entry.finestPrecipitationBlock();
      if (block == null) continue;

      final end = entry.time.add(block.duration);
      spans.add(
        _PrecipitationSpan(
          start: entry.time,
          end: end,
          amount: block.amount,
        ),
      );
      coveredUntil = end;
    }

    return spans;
  }

  List<DailyForecast> _dailySummaries(List<_Entry> entries) {
    final buckets = <DateTime, _DayBucket>{};

    for (final entry in entries) {
      final day = _dateOnly(_localize(entry.time));
      final bucket = buckets.putIfAbsent(day, () => _DayBucket(day));
      bucket.addInstant(
        temperature: entry.temperature,
        humidity: entry.humidity,
      );
    }

    // Precipitation is attributed by overlap rather than to the day a block
    // starts on: a six-hour block straddling midnight belongs partly to each.
    for (final span in _precipitationSpans(entries)) {
      _distribute(span, buckets);
    }

    final days = buckets.values.where((b) => b.hasInstantData).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return days.take(maxDays).map((b) => b.toDailyForecast()).toList();
  }

  void _distribute(_PrecipitationSpan span, Map<DateTime, _DayBucket> buckets) {
    final totalMinutes = span.end.difference(span.start).inMinutes;
    if (totalMinutes <= 0) return;

    var cursor = span.start;
    while (cursor.isBefore(span.end)) {
      final local = _localize(cursor);

      // Distance to the next local midnight is computed from the wall-clock
      // fields rather than by subtracting two DateTime values: the localized
      // time and a date-only value can disagree about whether they are UTC,
      // and Dart's difference() would then silently be off by the offset.
      final minutesIntoDay =
          local.hour * Duration.minutesPerHour + local.minute;
      final minutesToMidnight = Duration.minutesPerDay - minutesIntoDay;
      final nextBoundary = cursor.add(Duration(minutes: minutesToMidnight));

      final chunkEnd = nextBoundary.isBefore(span.end) ? nextBoundary : span.end;
      final minutes = chunkEnd.difference(cursor).inMinutes;
      if (minutes <= 0) break;

      // A day with no instant readings is not a forecast day, so rain falling
      // outside the reported range is dropped rather than inventing one.
      final bucket = buckets[_dateOnly(local)];
      if (bucket != null) {
        bucket.precipitation += span.amount * (minutes / totalMinutes);
      }

      cursor = chunkEnd;
    }
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}

/// Rounds to one decimal, matching the precision the web app displays.
double _round(double value) => (value * 10).round() / 10;

class _PrecipitationSpan {
  const _PrecipitationSpan({
    required this.start,
    required this.end,
    required this.amount,
  });

  final DateTime start;
  final DateTime end;
  final double amount;
}

class _PrecipitationBlock {
  const _PrecipitationBlock(this.duration, this.amount);

  final Duration duration;
  final double amount;
}

class _DayBucket {
  _DayBucket(this.date);

  final DateTime date;

  double? minTemperature;
  double? maxTemperature;
  double? minHumidity;
  double? maxHumidity;
  double precipitation = 0;
  int sampleCount = 0;

  bool get hasInstantData => sampleCount > 0;

  void addInstant({double? temperature, double? humidity}) {
    if (temperature == null || humidity == null) return;

    sampleCount++;
    minTemperature =
        minTemperature == null || temperature < minTemperature! ? temperature : minTemperature;
    maxTemperature =
        maxTemperature == null || temperature > maxTemperature! ? temperature : maxTemperature;
    minHumidity =
        minHumidity == null || humidity < minHumidity! ? humidity : minHumidity;
    maxHumidity =
        maxHumidity == null || humidity > maxHumidity! ? humidity : maxHumidity;
  }

  DailyForecast toDailyForecast() {
    return DailyForecast(
      date: date,
      minTemperature: _round(minTemperature ?? 0),
      maxTemperature: _round(maxTemperature ?? 0),
      minHumidity: _round(minHumidity ?? 0),
      maxHumidity: _round(maxHumidity ?? 0),
      precipitation: _round(precipitation),
      sampleCount: sampleCount,
    );
  }
}

class _Entry {
  const _Entry({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.data,
  });

  final DateTime time;
  final double? temperature;
  final double? humidity;
  final Map<String, dynamic> data;

  static _Entry? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    final time = DateTime.tryParse(raw['time'] as String? ?? '');
    if (time == null) return null;

    final data = raw['data'];
    if (data is! Map<String, dynamic>) return null;

    final details = _details(data['instant']);

    return _Entry(
      time: time.toUtc(),
      temperature: _number(details?['air_temperature']),
      humidity: _number(details?['relative_humidity']),
      data: data,
    );
  }

  /// The shortest forecast block that reports an amount, so hourly data wins
  /// over the six- and twelve-hour blocks covering the same time.
  _PrecipitationBlock? finestPrecipitationBlock() {
    const candidates = <String, Duration>{
      'next_1_hours': Duration(hours: 1),
      'next_6_hours': Duration(hours: 6),
      'next_12_hours': Duration(hours: 12),
    };

    for (final candidate in candidates.entries) {
      final amount = _number(
        _details(data[candidate.key])?['precipitation_amount'],
      );
      if (amount != null) return _PrecipitationBlock(candidate.value, amount);
    }
    return null;
  }

  static Map<String, dynamic>? _details(Object? block) {
    if (block is! Map<String, dynamic>) return null;
    final details = block['details'];
    return details is Map<String, dynamic> ? details : null;
  }

  static double? _number(Object? value) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }
    return null;
  }
}
