import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../weather/domain/coordinates.dart';
import 'data/geolocator_device_location.dart';
import 'domain/device_location_service.dart';
import 'domain/location_book.dart';
import 'domain/location_store.dart';
import 'domain/saved_location.dart';

/// The store backing [locationsProvider]. Overridden in `main()`.
final locationStoreProvider = Provider<LocationStore>((ref) {
  throw StateError(
    'locationStoreProvider must be overridden in ProviderScope. '
    'See main() for the production override.',
  );
});

/// Generates ids for newly added plots. Overridden in tests to make them
/// deterministic.
final locationIdGeneratorProvider = Provider<String Function()>((ref) {
  return () => 'plot-${DateTime.now().microsecondsSinceEpoch}';
});

/// The grower's saved plots and which one is selected.
final locationsProvider = NotifierProvider<LocationsController, LocationBook>(
  LocationsController.new,
);

/// The plot currently being viewed, or `null` if every plot has been deleted.
final activeLocationProvider = Provider<SavedLocation?>((ref) {
  return ref.watch(locationsProvider.select((book) => book.active));
});

/// Reads the device's GPS position for the map screen's locate button.
final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => GeolocatorDeviceLocation(),
);

/// Builds the tile provider fetching the map screen's satellite tiles.
///
/// Unlike the store providers above, this has a working default: there is
/// nothing to prepare in `main()`, only a stub to swap in for widget tests,
/// which have no network.
///
/// A factory rather than a single instance because [TileLayer] disposes the
/// provider it is given, and [NetworkTileProvider.dispose] closes its HTTP
/// client. Sharing one instance meant the first time the map screen closed it
/// left a dead client behind, and every later visit loaded no tiles at all.
final mapTileProviderProvider = Provider<TileProvider Function()>(
  (ref) => NetworkTileProvider.new,
);

/// Adds, edits, reorders and deletes plots, persisting every change.
class LocationsController extends Notifier<LocationBook> {
  @override
  LocationBook build() {
    final saved = ref.read(locationStoreProvider).read();
    // A fresh install starts with Belgrade rather than an empty screen, so the
    // app has something to show before the grower has entered anything.
    if (saved == null || saved.isEmpty) return LocationBook.seeded();
    return saved;
  }

  /// Adds a plot and selects it.
  Future<SavedLocation> add({
    required String name,
    required Coordinates coordinates,
  }) async {
    final location = SavedLocation(
      id: ref.read(locationIdGeneratorProvider)(),
      name: name.trim(),
      coordinates: coordinates,
    );

    await _update(
      state.copyWith(
        locations: [...state.locations, location],
        activeId: location.id,
      ),
    );
    return location;
  }

  /// Renames or moves an existing plot, leaving its id and its cached forecast
  /// alone.
  Future<void> edit(
    String id, {
    String? name,
    Coordinates? coordinates,
  }) async {
    final locations = [
      for (final location in state.locations)
        if (location.id == id)
          location.copyWith(name: name?.trim(), coordinates: coordinates)
        else
          location,
    ];

    await _update(state.copyWith(locations: locations));
  }

  /// Removes a plot.
  ///
  /// If it was the selected one, the selection falls to whatever remains rather
  /// than being left dangling.
  Future<void> remove(String id) async {
    final locations =
        state.locations.where((location) => location.id != id).toList();

    if (locations.isEmpty) {
      await _update(const LocationBook(locations: []));
      return;
    }

    final activeId = state.activeId == id ? locations.first.id : state.activeId;
    await _update(LocationBook(locations: locations, activeId: activeId));
  }

  /// Moves the plot at [oldIndex] so that it ends up at [newIndex].
  ///
  /// [newIndex] is the position in the list *after* the plot has been lifted
  /// out, which is what `ReorderableListView.onReorderItem` reports. The older
  /// `onReorder` callback reports it before removal and needs adjusting; this
  /// takes the adjusted form so the compensation is not applied twice.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.locations.length) return;

    final locations = [...state.locations];
    final moved = locations.removeAt(oldIndex);
    locations.insert(newIndex.clamp(0, locations.length), moved);

    await _update(state.copyWith(locations: locations));
  }

  /// Selects [id], if it names a plot that exists.
  Future<void> setActive(String id) async {
    if (state.byId(id) == null) return;
    await _update(state.copyWith(activeId: id));
  }

  Future<void> _update(LocationBook book) async {
    state = book;
    await ref.read(locationStoreProvider).write(book);
  }
}
