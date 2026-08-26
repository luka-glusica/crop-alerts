import 'package:flutter/foundation.dart';

import 'coordinates.dart';
import 'daily_forecast.dart';

/// The conditions right now, for the dashboard's summary tiles.
@immutable
class CurrentConditions {
  const CurrentConditions({
    required this.temperature,
    required this.humidity,
    required this.minTemperature24h,
    required this.maxTemperature24h,
    required this.precipitation12h,
  });

  final double temperature;
  final double humidity;
  final double minTemperature24h;
  final double maxTemperature24h;
  final double precipitation12h;

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'humidity': humidity,
        'minTemperature24h': minTemperature24h,
        'maxTemperature24h': maxTemperature24h,
        'precipitation12h': precipitation12h,
      };

  factory CurrentConditions.fromJson(Map<String, dynamic> json) {
    return CurrentConditions(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      minTemperature24h: (json['minTemperature24h'] as num).toDouble(),
      maxTemperature24h: (json['maxTemperature24h'] as num).toDouble(),
      precipitation12h: (json['precipitation12h'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CurrentConditions &&
      other.temperature == temperature &&
      other.humidity == humidity &&
      other.minTemperature24h == minTemperature24h &&
      other.maxTemperature24h == maxTemperature24h &&
      other.precipitation12h == precipitation12h;

  @override
  int get hashCode => Object.hash(
        temperature,
        humidity,
        minTemperature24h,
        maxTemperature24h,
        precipitation12h,
      );
}

/// A complete forecast for one place, ready for the rule engine.
@immutable
class Forecast {
  const Forecast({
    required this.coordinates,
    required this.updatedAt,
    required this.fetchedAt,
    required this.now,
    required this.days,
    this.expiresAt,
    this.lastModified,
  });

  final Coordinates coordinates;

  /// When MET Norway last recalculated this forecast
  /// (`properties.meta.updated_at`), which is not when we fetched it.
  final DateTime updatedAt;

  /// When this app fetched it. Drives the six-hour cache.
  final DateTime fetchedAt;

  /// Value of the response's `Expires` header. MET's terms ask clients not to
  /// re-request before this time.
  final DateTime? expiresAt;

  /// Raw `Last-Modified` header, replayed verbatim as `If-Modified-Since` on
  /// the next request so the server can answer 304.
  final String? lastModified;

  final CurrentConditions now;

  /// Daily summaries in chronological order, starting today.
  final List<DailyForecast> days;

  /// Whether [expiresAt] has passed as of [at].
  bool isExpiredAt(DateTime at) {
    final expires = expiresAt;
    return expires != null && !at.isBefore(expires);
  }

  /// How old the data is, as of [at].
  Duration ageAt(DateTime at) => at.difference(fetchedAt);

  Map<String, dynamic> toJson() => {
        'coordinates': {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
        },
        'updatedAt': updatedAt.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lastModified': lastModified,
        'now': now.toJson(),
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory Forecast.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates']! as Map<String, dynamic>;
    final expiresAt = json['expiresAt'] as String?;

    return Forecast(
      coordinates: Coordinates(
        latitude: (coordinates['latitude'] as num).toDouble(),
        longitude: (coordinates['longitude'] as num).toDouble(),
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
      lastModified: json['lastModified'] as String?,
      now: CurrentConditions.fromJson(json['now']! as Map<String, dynamic>),
      days: (json['days']! as List)
          .cast<Map<String, dynamic>>()
          .map(DailyForecast.fromJson)
          .toList(),
    );
  }

  /// A copy with cache metadata replaced, used when a 304 refreshes only the
  /// freshness of data we already hold.
  Forecast copyWithCacheMetadata({
    required DateTime fetchedAt,
    DateTime? expiresAt,
    String? lastModified,
  }) {
    return Forecast(
      coordinates: coordinates,
      updatedAt: updatedAt,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastModified: lastModified ?? this.lastModified,
      now: now,
      days: days,
    );
  }
}
