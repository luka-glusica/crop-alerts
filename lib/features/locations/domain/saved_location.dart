import 'package:flutter/foundation.dart';

import '../../weather/domain/coordinates.dart';

/// A place a grower keeps crops — a plot, a field, a garden.
///
/// Each one caches its own forecast, so switching between them costs nothing
/// and does not trigger a request.
@immutable
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.name,
    required this.coordinates,
  });

  /// Stable identifier, unchanged by renaming or moving the plot.
  final String id;

  /// What the grower calls it.
  final String name;

  final Coordinates coordinates;

  SavedLocation copyWith({String? name, Coordinates? coordinates}) {
    return SavedLocation(
      id: id,
      name: name ?? this.name,
      coordinates: coordinates ?? this.coordinates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
      };

  /// Reads a location, or `null` if the entry is unusable.
  ///
  /// Returning null rather than throwing means one corrupted entry costs that
  /// plot, not the whole list.
  static SavedLocation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;

    final id = json['id'];
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];

    if (id is! String || id.isEmpty) return null;
    if (name is! String) return null;
    if (latitude is! num || longitude is! num) return null;
    if (!latitude.toDouble().isFinite || !longitude.toDouble().isFinite) {
      return null;
    }

    return SavedLocation(
      id: id,
      name: name,
      coordinates: Coordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedLocation &&
      other.id == id &&
      other.name == name &&
      other.coordinates == coordinates;

  @override
  int get hashCode => Object.hash(id, name, coordinates);

  @override
  String toString() => 'SavedLocation($id, $name, $coordinates)';
}
