import 'package:flutter/foundation.dart';

/// A point on the globe, at the precision the MET Norway API accepts.
///
/// Their terms cap coordinates at four decimals — newer products return 403 for
/// anything more precise — so the values are rounded on construction rather
/// than at the call site, where it would eventually be forgotten.
@immutable
class Coordinates {
  Coordinates({required double latitude, required double longitude})
      : latitude = _round(latitude.clamp(-90, 90)),
        longitude = _round(longitude.clamp(-180, 180));

  /// The web app's default: Belgrade.
  static final Coordinates belgrade =
      Coordinates(latitude: 44.8078, longitude: 20.5656);

  /// Decimal places MET Norway allows.
  static const int precision = 4;

  final double latitude;
  final double longitude;

  /// Formatted the way the API expects them in a query string.
  String get latitudeParam => latitude.toStringAsFixed(precision);
  String get longitudeParam => longitude.toStringAsFixed(precision);

  static double _round(num value) {
    const factor = 10000; // 10^precision
    return (value * factor).round() / factor;
  }

  @override
  bool operator ==(Object other) =>
      other is Coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Coordinates($latitudeParam, $longitudeParam)';
}
