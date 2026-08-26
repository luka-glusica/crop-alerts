import 'package:flutter/foundation.dart';

import '../../weather/domain/coordinates.dart';

/// A location picked on the map, waiting to be named and saved.
///
/// The point comes from a tap or from GPS, so it is valid by construction —
/// unlike the old typed lat/lon form, there is nothing here to reject beyond a
/// blank name.
@immutable
class LocationDraft {
  const LocationDraft({required this.name, required this.coordinates});

  final String name;
  final Coordinates coordinates;

  /// Whether [name] is usable once whitespace is trimmed.
  bool get isNamed => name.trim().isNotEmpty;
}
