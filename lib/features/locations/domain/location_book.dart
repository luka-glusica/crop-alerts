import 'package:flutter/foundation.dart';

import '../../weather/domain/coordinates.dart';
import 'saved_location.dart';

/// Every plot a grower has saved, and which one they are looking at.
@immutable
class LocationBook {
  const LocationBook({required this.locations, this.activeId});

  /// The plot every new install starts with, matching the web version's
  /// default coordinates. Its id is fixed rather than generated so that seeding
  /// is deterministic and does not have to be written to disk to be stable.
  static final SavedLocation belgrade = SavedLocation(
    id: 'seed-belgrade',
    name: 'Beograd',
    coordinates: Coordinates.belgrade,
  );

  /// A book for a fresh install.
  static LocationBook seeded() =>
      LocationBook(locations: [belgrade], activeId: belgrade.id);

  final List<SavedLocation> locations;

  /// The selected plot's id. May point at nothing if the plot was deleted.
  final String? activeId;

  bool get isEmpty => locations.isEmpty;

  /// The plot currently being viewed.
  ///
  /// Falls back to the first plot when [activeId] names one that no longer
  /// exists, so a deleted plot cannot leave the app with nothing selected.
  SavedLocation? get active {
    if (locations.isEmpty) return null;
    for (final location in locations) {
      if (location.id == activeId) return location;
    }
    return locations.first;
  }

  SavedLocation? byId(String id) {
    for (final location in locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  LocationBook copyWith({
    List<SavedLocation>? locations,
    String? activeId,
    bool clearActive = false,
  }) {
    return LocationBook(
      locations: locations ?? this.locations,
      activeId: clearActive ? null : (activeId ?? this.activeId),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeId': activeId,
        'locations': locations.map((l) => l.toJson()).toList(),
      };

  /// Reads a book, skipping any entry that cannot be understood.
  static LocationBook fromJson(Map<String, dynamic> json) {
    final rawLocations = json['locations'];
    final locations = <SavedLocation>[];
    if (rawLocations is List) {
      for (final raw in rawLocations) {
        final location = SavedLocation.fromJson(raw);
        if (location != null) locations.add(location);
      }
    }

    final activeId = json['activeId'];
    return LocationBook(
      locations: locations,
      activeId: activeId is String ? activeId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocationBook &&
      other.activeId == activeId &&
      listEquals(other.locations, locations);

  @override
  int get hashCode => Object.hash(activeId, Object.hashAll(locations));
}
