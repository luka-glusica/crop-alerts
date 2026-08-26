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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('lists the seeded plot', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Beograd'), findsOneWidget);
    expect(find.text('44.8078, 20.5656'), findsOneWidget);
    expect(find.text('AKTIVNA PARCELA'), findsOneWidget);
  });

  testWidgets('adds a plot through the form', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj parcelu'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Njiva kod reke');
    await tester.enterText(find.byType(TextField).at(1), '45.2671');
    await tester.enterText(find.byType(TextField).at(2), '19.8335');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Njiva kod reke'), findsOneWidget);
    expect(store.read()!.locations, hasLength(2));
  });

  testWidgets('refuses to save an invalid plot and says what is wrong',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj parcelu'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '448.078');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    // Still on the form, with both problems named.
    expect(find.text('Unesite naziv parcele.'), findsOneWidget);
    expect(
      find.text('Geografska širina mora biti između -90 i 90.'),
      findsOneWidget,
    );
    expect(store.writes, 0, reason: 'an invalid plot must not be saved');
  });

  testWidgets('does not scold before the first save attempt', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj parcelu'));
    await tester.pumpAndSettle();

    expect(find.text('Unesite naziv parcele.'), findsNothing);
  });

  testWidgets('selects a plot when tapped', (tester) async {
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
    expect(find.text('Obrisati parcelu „Prva“?'), findsOneWidget);

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

  testWidgets('edits an existing plot through the same form', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Izmeni parcelu').first);
    await tester.pumpAndSettle();

    // The form opens pre-filled.
    expect(find.text('44.8078'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Bašta');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Bašta'), findsOneWidget);
    expect(store.read()!.locations.single.id, LocationBook.belgrade.id);
  });

  testWidgets('shows the empty state once every plot is gone', (tester) async {
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

    expect(find.text('Nemate nijednu parcelu.'), findsOneWidget);
  });
}
