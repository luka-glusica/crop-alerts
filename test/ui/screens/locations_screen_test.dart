import 'dart:convert';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/domain/location_book.dart';
import 'package:crop_alerts/features/locations/domain/saved_location.dart';
import 'package:crop_alerts/features/locations/locations_controller.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/screens/locations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1x1 transparent PNG, so the map has something to decode without a
/// network — widget tests have none.
final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _StubTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}

void main() {
  final noviSad = Coordinates(latitude: 45.2671, longitude: 19.8335);

  late InMemoryLocationStore store;

  Widget harness({LocationBook? saved}) {
    store = InMemoryLocationStore(saved);
    var counter = 0;
    return ProviderScope(
      overrides: [
        locationStoreProvider.overrideWithValue(store),
        locationIdGeneratorProvider.overrideWithValue(() => 'id-${++counter}'),
        mapTileProviderProvider.overrideWithValue(_StubTileProvider.new),
      ],
      child: MaterialApp(
        locale: LocaleController.serbianLatin,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleController.supportedLocales,
        home: const LocationsScreen(),
      ),
    );
  }

  testWidgets('lists the seeded location', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Beograd'), findsOneWidget);
    expect(find.text('44.8078, 20.5656'), findsOneWidget);
    expect(find.text('AKTIVNA LOKACIJA'), findsOneWidget);
  });

  testWidgets('adds a location by picking a point on the map', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj lokaciju'));
    await tester.pumpAndSettle();

    // Taps the map's center, which is where a fresh install's camera starts:
    // on Belgrade, since there is no active location to centre on yet either.
    // flutter_map holds a tap for 250ms before firing onTap, to rule out a
    // double-tap-to-zoom, so the test has to wait that out too.
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Njiva kod reke');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Njiva kod reke'), findsOneWidget);
    expect(store.read()!.locations, hasLength(2));
    expect(find.text('Lokacija „Njiva kod reke“ je dodata.'), findsOneWidget);
  });

  testWidgets('selects a location when tapped', (tester) async {
    await tester.pumpWidget(
      harness(
        saved: LocationBook(
          locations: [
            SavedLocation(id: 'a', name: 'Prva', coordinates: noviSad),
            SavedLocation(id: 'b', name: 'Druga', coordinates: noviSad),
          ],
          activeId: 'a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Druga'));
    await tester.pumpAndSettle();

    expect(store.read()!.activeId, 'b');
  });

  testWidgets('asks before deleting, and does nothing if cancelled',
      (tester) async {
    await tester.pumpWidget(
      harness(
        saved: LocationBook(
          locations: [
            SavedLocation(id: 'a', name: 'Prva', coordinates: noviSad),
            SavedLocation(id: 'b', name: 'Druga', coordinates: noviSad),
          ],
          activeId: 'a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Obriši').first);
    await tester.pumpAndSettle();
    expect(find.text('Obrisati lokaciju „Prva“?'), findsOneWidget);

    await tester.tap(find.text('Otkaži'));
    await tester.pumpAndSettle();

    expect(find.text('Prva'), findsOneWidget);
    expect(store.writes, 0, reason: 'cancelling must not persist anything');
  });

  testWidgets('deletes when confirmed', (tester) async {
    await tester.pumpWidget(
      harness(
        saved: LocationBook(
          locations: [
            SavedLocation(id: 'a', name: 'Prva', coordinates: noviSad),
            SavedLocation(id: 'b', name: 'Druga', coordinates: noviSad),
          ],
          activeId: 'a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Obriši').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši').last);
    await tester.pumpAndSettle();

    expect(find.text('Prva'), findsNothing);
    expect(store.read()!.locations, hasLength(1));
    expect(store.read()!.activeId, 'b');
  });

  testWidgets('edits an existing location through the map', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Izmeni lokaciju').first);
    await tester.pumpAndSettle();

    // The drawer opens immediately, pre-filled with the saved point — no
    // re-tap needed just to rename it.
    expect(find.text('Beograd'), findsOneWidget);
    expect(find.text('44.8078, 20.5656'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bašta');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Bašta'), findsOneWidget);
    expect(store.read()!.locations.single.id, LocationBook.belgrade.id);
    expect(find.text('Lokacija „Bašta“ je izmenjena.'), findsOneWidget);
  });

  testWidgets('shows the empty state once every location is gone',
      (tester) async {
    await tester.pumpWidget(
      harness(
        saved: LocationBook(
          locations: [
            SavedLocation(id: 'a', name: 'Prva', coordinates: noviSad),
          ],
          activeId: 'a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Obriši').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši').last);
    await tester.pumpAndSettle();

    expect(find.text('Nemate nijednu lokaciju.'), findsOneWidget);
  });
}
