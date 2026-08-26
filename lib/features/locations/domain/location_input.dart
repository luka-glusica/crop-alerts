import 'package:flutter/foundation.dart';

import '../../weather/domain/coordinates.dart';

/// What is wrong with a plot the grower is entering.
enum LocationInputError { nameRequired, latitudeInvalid, longitudeInvalid }

/// Validates the plot form.
///
/// [Coordinates] silently clamps out-of-range values, which is right when a
/// value arrives from code but wrong for something typed in: a grower who types
/// 448.078 should be told, not quietly moved to the north pole.
@immutable
class LocationInput {
  const LocationInput({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String latitude;
  final String longitude;

  /// Everything wrong with the input, empty when it is usable.
  Set<LocationInputError> get errors {
    return {
      if (name.trim().isEmpty) LocationInputError.nameRequired,
      if (!_isValid(latitude, 90)) LocationInputError.latitudeInvalid,
      if (!_isValid(longitude, 180)) LocationInputError.longitudeInvalid,
    };
  }

  bool get isValid => errors.isEmpty;

  /// The parsed coordinates, or `null` if the input is not usable.
  Coordinates? get coordinates {
    if (!isValid) return null;
    return Coordinates(
      latitude: double.parse(latitude.trim().replaceAll(',', '.')),
      longitude: double.parse(longitude.trim().replaceAll(',', '.')),
    );
  }

  static bool _isValid(String raw, double limit) {
    // A comma is the decimal separator in Serbian, and a numeric keyboard on a
    // Serbian device offers one.
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) return false;
    return value >= -limit && value <= limit;
  }
}
