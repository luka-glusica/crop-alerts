import 'package:flutter/foundation.dart';

/// One day of weather, reduced to the values the crop rules care about.
@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.minHumidity,
    required this.maxHumidity,
    required this.precipitation,
    required this.sampleCount,
  });

  /// Local calendar date, with no time component.
  final DateTime date;

  /// Degrees Celsius.
  final double minTemperature;
  final double maxTemperature;

  /// Relative humidity, percent.
  final double minHumidity;
  final double maxHumidity;

  /// Total rainfall for the day, millimetres.
  final double precipitation;

  /// How many forecast readings this day was built from.
  ///
  /// The first and last day of a forecast are usually partial, and a rule that
  /// keys off a daily minimum should be able to tell.
  final int sampleCount;

  /// Midpoint of the day's temperature range.
  double get averageTemperature => (minTemperature + maxTemperature) / 2;

  /// Midpoint of the day's humidity range.
  double get averageHumidity => (minHumidity + maxHumidity) / 2;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minTemperature': minTemperature,
        'maxTemperature': maxTemperature,
        'minHumidity': minHumidity,
        'maxHumidity': maxHumidity,
        'precipitation': precipitation,
        'sampleCount': sampleCount,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['date'] as String),
      minTemperature: (json['minTemperature'] as num).toDouble(),
      maxTemperature: (json['maxTemperature'] as num).toDouble(),
      minHumidity: (json['minHumidity'] as num).toDouble(),
      maxHumidity: (json['maxHumidity'] as num).toDouble(),
      precipitation: (json['precipitation'] as num).toDouble(),
      sampleCount: (json['sampleCount'] as num).toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyForecast &&
      other.date == date &&
      other.minTemperature == minTemperature &&
      other.maxTemperature == maxTemperature &&
      other.minHumidity == minHumidity &&
      other.maxHumidity == maxHumidity &&
      other.precipitation == precipitation &&
      other.sampleCount == sampleCount;

  @override
  int get hashCode => Object.hash(
        date,
        minTemperature,
        maxTemperature,
        minHumidity,
        maxHumidity,
        precipitation,
        sampleCount,
      );

  @override
  String toString() => 'DailyForecast(${date.toIso8601String().split('T').first}, '
      '$minTemperature–$maxTemperature°C, $minHumidity–$maxHumidity%, '
      '${precipitation}mm)';
}
