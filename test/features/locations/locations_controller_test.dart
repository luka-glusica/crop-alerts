import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/domain/location_book.dart';
import 'package:crop_alerts/features/locations/domain/location_input.dart';
import 'package:crop_alerts/features/locations/domain/saved_location.dart';
import 'package:crop_alerts/features/locations/locations_controller.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final noviSad = Coordinates(latitude: 45.2671, longitude: 19.8335);
  final nis = Coordinates(latitude: 43.3209, longitude: 21.8958);

  ({ProviderContainer container, InMemoryLocationStore store}) build({
    LocationBook? saved,
  }) {
    final store = InMemoryLocationStore(saved);
    var counter = 0;
    final container = ProviderContainer(
      overrides: [
        locationStoreProvider.overrideWithValue(store),
        locationIdGeneratorProvider.overrideWithValue(() => 'id-${++counter}'),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, store: store);
  }

  group('a fresh install', () {
    test('starts with Belgrade selected', () {
      final book = build().container.read(locationsProvider);

      expect(book.locations, hasLength(1));
      expect(book.locations.single.name, 'Beograd');
      expect(book.locations.single.coordinates, Coordinates.belgrade);
      expect(book.active, book.locations.single);
    });

    test('seeds deterministically, so the id survives a restart unwritten', () {
      expect(
        build().container.read(locationsProvider).locations.single.id,
        LocationBook.belgrade.id,
      );
      expect(
        build().container.read(locationsProvider).locations.single.id,
        LocationBook.belgrade.id,
      );
    });

    test('an empty saved book is re-seeded rather than shown empty', () {
      final book = build(saved: const LocationBook(locations: []))
          .container
          .read(locationsProvider);

      expect(book.locations, hasLength(1));
    });
  });

  group('adding', () {
    test('appends the plot and selects it', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);

      final added = await controller.add(name: 'Njiva', coordinates: noviSad);
      final book = built.container.read(locationsProvider);

      expect(book.locations, hasLength(2));
      expect(book.locations.last, added);
      expect(book.active, added);
      expect(built.store.read()!.locations, hasLength(2));
    });

    test('trims whitespace from the name', () async {
      final built = build();

      final added = await built.container
          .read(locationsProvider.notifier)
          .add(name: '  Njiva kod reke  ', coordinates: noviSad);

      expect(added.name, 'Njiva kod reke');
    });

    test('each plot gets its own id', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);

      final first = await controller.add(name: 'A', coordinates: noviSad);
      final second = await controller.add(name: 'B', coordinates: nis);

      expect(first.id, isNot(second.id));
    });
  });

  group('editing', () {
    test('renames without changing the id, so the cache survives', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final original =
          built.container.read(locationsProvider).locations.single;

      await controller.edit(original.id, name: 'Bašta');
      final updated = built.container.read(locationsProvider).locations.single;

      expect(updated.id, original.id);
      expect(updated.name, 'Bašta');
      expect(updated.coordinates, original.coordinates);
    });

    test('moves the plot without changing the id', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final original =
          built.container.read(locationsProvider).locations.single;

      await controller.edit(original.id, coordinates: nis);
      final updated = built.container.read(locationsProvider).locations.single;

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.coordinates, nis);
    });

    test('editing an unknown id changes nothing', () async {
      final built = build();
      final before = built.container.read(locationsProvider);

      await built.container
          .read(locationsProvider.notifier)
          .edit('nema-ovoga', name: 'X');

      expect(built.container.read(locationsProvider).locations, before.locations);
    });
  });

  group('deleting', () {
    test('removes the plot', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final added = await controller.add(name: 'Njiva', coordinates: noviSad);

      await controller.remove(added.id);

      expect(built.container.read(locationsProvider).locations, hasLength(1));
    });

    test('deleting the selected plot moves the selection, not nowhere',
        () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final added = await controller.add(name: 'Njiva', coordinates: noviSad);
      expect(built.container.read(locationsProvider).active, added);

      await controller.remove(added.id);
      final book = built.container.read(locationsProvider);

      expect(book.active, isNotNull);
      expect(book.active!.name, 'Beograd');
      expect(book.activeId, book.active!.id);
    });

    test('deleting the last plot leaves the book genuinely empty', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final only = built.container.read(locationsProvider).locations.single;

      await controller.remove(only.id);
      final book = built.container.read(locationsProvider);

      // Re-seeding here would resurrect a plot the grower just deleted.
      expect(book.locations, isEmpty);
      expect(book.active, isNull);
    });
  });

  group('reordering', () {
    Future<List<String>> namesAfterReorder(int from, int to) async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      await controller.add(name: 'B', coordinates: noviSad);
      await controller.add(name: 'C', coordinates: nis);
      // Beograd, B, C

      await controller.reorder(from, to);
      return built.container
          .read(locationsProvider)
          .locations
          .map((l) => l.name)
          .toList();
    }

    test('moves a plot down', () async {
      expect(await namesAfterReorder(0, 2), ['B', 'C', 'Beograd']);
    });

    test('moves a plot up', () async {
      expect(await namesAfterReorder(2, 0), ['C', 'Beograd', 'B']);
    });

    test('moving to the same place changes nothing', () async {
      expect(await namesAfterReorder(1, 1), ['Beograd', 'B', 'C']);
    });

    test('an out-of-range index is ignored rather than throwing', () async {
      final built = build();
      final before = built.container.read(locationsProvider).locations;

      await built.container.read(locationsProvider.notifier).reorder(9, 0);
      await built.container.read(locationsProvider.notifier).reorder(-1, 0);

      expect(built.container.read(locationsProvider).locations, before);
    });

    test('reordering does not change the selection', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final added = await controller.add(name: 'B', coordinates: noviSad);

      await controller.reorder(1, 0);

      expect(built.container.read(locationsProvider).active, added);
    });
  });

  group('selection', () {
    test('setActive selects an existing plot', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);
      final beograd = built.container.read(locationsProvider).locations.single;
      await controller.add(name: 'B', coordinates: noviSad);

      await controller.setActive(beograd.id);

      expect(built.container.read(locationsProvider).active, beograd);
      expect(built.container.read(activeLocationProvider), beograd);
    });

    test('setting an unknown id is ignored', () async {
      final built = build();
      final before = built.container.read(locationsProvider).activeId;

      await built.container
          .read(locationsProvider.notifier)
          .setActive('nema-ovoga');

      expect(built.container.read(locationsProvider).activeId, before);
    });

    test('a dangling activeId falls back to the first plot', () {
      final built = build(
        saved: LocationBook(
          locations: [
            SavedLocation(id: 'a', name: 'A', coordinates: noviSad),
            SavedLocation(id: 'b', name: 'B', coordinates: nis),
          ],
          activeId: 'obrisana',
        ),
      );

      expect(built.container.read(locationsProvider).active!.id, 'a');
    });
  });

  group('persistence', () {
    test('every change is written', () async {
      final built = build();
      final controller = built.container.read(locationsProvider.notifier);

      final added = await controller.add(name: 'B', coordinates: noviSad);
      await controller.edit(added.id, name: 'C');
      await controller.setActive(LocationBook.belgrade.id);
      await controller.remove(added.id);

      expect(built.store.writes, 4);
    });

    test('a saved book is restored', () {
      final saved = LocationBook(
        locations: [
          SavedLocation(id: 'a', name: 'Njiva', coordinates: noviSad),
        ],
        activeId: 'a',
      );

      final book = build(saved: saved).container.read(locationsProvider);

      expect(book.locations.single.name, 'Njiva');
      expect(book.activeId, 'a');
    });
  });

  group('serialization', () {
    test('a book round-trips', () {
      final original = LocationBook(
        locations: [
          SavedLocation(id: 'a', name: 'Njiva', coordinates: noviSad),
          SavedLocation(id: 'b', name: 'Bašta', coordinates: nis),
        ],
        activeId: 'b',
      );

      expect(LocationBook.fromJson(original.toJson()), original);
    });

    test('one corrupted entry costs that plot, not the whole list', () {
      final book = LocationBook.fromJson({
        'activeId': 'a',
        'locations': [
          {'id': 'a', 'name': 'Njiva', 'latitude': 45.2671, 'longitude': 19.8335},
          {'id': 'b', 'name': 'Bez koordinata'},
          {'name': 'Bez id-ja', 'latitude': 1, 'longitude': 1},
          'ovo nije objekat',
        ],
      });

      expect(book.locations, hasLength(1));
      expect(book.locations.single.id, 'a');
    });

    test('a book with nothing readable comes back empty', () {
      expect(LocationBook.fromJson(const {}).locations, isEmpty);
      expect(LocationBook.fromJson(const {'locations': 5}).locations, isEmpty);
    });
  });

  group('LocationInput', () {
    LocationInput input(String name, String lat, String lon) =>
        LocationInput(name: name, latitude: lat, longitude: lon);

    test('accepts a well-formed plot', () {
      final valid = input('Njiva', '45.2671', '19.8335');

      expect(valid.isValid, isTrue);
      expect(valid.coordinates, noviSad);
    });

    test('accepts a comma as the decimal separator', () {
      // A Serbian numeric keyboard offers a comma.
      expect(input('Njiva', '45,2671', '19,8335').coordinates, noviSad);
    });

    test('requires a name', () {
      expect(
        input('', '45', '19').errors,
        contains(LocationInputError.nameRequired),
      );
      expect(
        input('   ', '45', '19').errors,
        contains(LocationInputError.nameRequired),
      );
    });

    test('rejects an out-of-range latitude rather than clamping it', () {
      // Coordinates clamps, which is right for values from code and wrong for
      // a typo: 448.078 should be reported, not moved to the north pole.
      expect(
        input('Njiva', '448.078', '20').errors,
        contains(LocationInputError.latitudeInvalid),
      );
      expect(input('Njiva', '448.078', '20').coordinates, isNull);
    });

    test('rejects an out-of-range longitude', () {
      expect(
        input('Njiva', '45', '200').errors,
        contains(LocationInputError.longitudeInvalid),
      );
    });

    test('accepts the extremes of both ranges', () {
      expect(input('Njiva', '90', '180').isValid, isTrue);
      expect(input('Njiva', '-90', '-180').isValid, isTrue);
    });

    test('rejects text and blanks', () {
      expect(input('Njiva', 'sever', '20').isValid, isFalse);
      expect(input('Njiva', '', '20').isValid, isFalse);
    });

    test('reports every problem at once', () {
      expect(input('', 'x', 'y').errors, hasLength(3));
    });
  });
}
