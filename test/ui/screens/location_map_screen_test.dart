import 'dart:convert';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/domain/device_location_service.dart';
import 'package:crop_alerts/features/locations/domain/location_draft.dart';
import 'package:crop_alerts/features/locations/domain/saved_location.dart';
import 'package:crop_alerts/features/locations/locations_controller.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/screens/location_map_screen.dart';
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

class _FakeDeviceLocationService implements DeviceLocationService {
  _FakeDeviceLocationService(this.result);

  DeviceLocationResult result;
  int calls = 0;

  @override
  Future<DeviceLocationResult> current() async {
    calls++;
    return result;
  }
}

void main() {
  final noviSad = Coordinates(latitude: 45.2671, longitude: 19.8335);

  late _FakeDeviceLocationService locationService;
  LocationDraft? popped;
  var wasPopped = false;

  Widget harness({SavedLocation? existing, DeviceLocationResult? gps}) {
    locationService = _FakeDeviceLocationService(
      gps ?? const DeviceLocationResult.failure(DeviceLocationFailure.unavailable),
    );
    popped = null;
    wasPopped = false;

    return ProviderScope(
      overrides: [
        locationStoreProvider.overrideWithValue(InMemoryLocationStore()),
        mapTileProviderProvider.overrideWithValue(_StubTileProvider.new),
        deviceLocationServiceProvider.overrideWithValue(locationService),
      ],
      child: MaterialApp(
        locale: LocaleController.serbianLatin,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleController.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<LocationDraft>(
                    MaterialPageRoute<LocationDraft>(
                      builder: (context) => LocationMapScreen(existing: existing),
                    ),
                  );
                  popped = result;
                  wasPopped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openMap(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Taps the center of the map. flutter_map holds a tap for 250ms before
  /// firing `onTap`, to rule out the first half of a double-tap-to-zoom, so
  /// the wait has to be simulated too.
  Future<void> tapMapCenter(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('adding', () {
    testWidgets('the drawer is hidden until a point is picked', (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping the map raises the drawer with the tapped point',
        (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);

      await tapMapCenter(tester);

      expect(find.byType(TextField), findsOneWidget);
      // The map centers on the seeded Belgrade location by default.
      expect(find.text('44.8078, 20.5656'), findsOneWidget);
    });

    testWidgets('saving pops a draft with the trimmed name', (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);
      await tapMapCenter(tester);

      await tester.enterText(find.byType(TextField), '  Njiva  ');
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      expect(wasPopped, isTrue);
      expect(popped, isNotNull);
      expect(popped!.name, '  Njiva  ');
      expect(popped!.coordinates, Coordinates.belgrade);
    });

    testWidgets('a blank name blocks the save and reports why', (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);
      await tapMapCenter(tester);

      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      expect(wasPopped, isFalse);
      expect(find.text('Unesite naziv lokacije.'), findsOneWidget);
    });

    testWidgets('the name error is not shown before the first save attempt',
        (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);
      await tapMapCenter(tester);

      expect(find.text('Unesite naziv lokacije.'), findsNothing);
    });

    testWidgets('the name error clears live once the grower starts typing',
        (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);
      await tapMapCenter(tester);

      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();
      expect(find.text('Unesite naziv lokacije.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Njiva');
      await tester.pump();

      expect(find.text('Unesite naziv lokacije.'), findsNothing);
    });

    testWidgets('cancel pops without a draft', (tester) async {
      await tester.pumpWidget(harness());
      await openMap(tester);
      await tapMapCenter(tester);

      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();

      expect(wasPopped, isTrue);
      expect(popped, isNull);
    });
  });

  group('editing', () {
    final existing =
        SavedLocation(id: 'a', name: 'Njiva', coordinates: noviSad);

    testWidgets('the drawer is already open, pre-filled with the saved point',
        (tester) async {
      await tester.pumpWidget(harness(existing: existing));
      await openMap(tester);

      expect(find.text('Njiva'), findsOneWidget);
      expect(find.text('45.2671, 19.8335'), findsOneWidget);
    });

    testWidgets('renaming alone is enough to save', (tester) async {
      await tester.pumpWidget(harness(existing: existing));
      await openMap(tester);

      await tester.enterText(find.byType(TextField), 'Bašta');
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      expect(popped!.name, 'Bašta');
      expect(popped!.coordinates, noviSad);
    });

    testWidgets('picking a new point replaces the saved one', (tester) async {
      await tester.pumpWidget(harness(existing: existing));
      await openMap(tester);

      await tapMapCenter(tester);
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      // The map centers on the location being edited, not Belgrade.
      expect(popped!.coordinates, noviSad);
    });
  });

  group('locating', () {
    testWidgets('a successful fix pins the point and raises the drawer',
        (tester) async {
      final home = Coordinates(latitude: 45.5, longitude: 20.1);
      await tester.pumpWidget(
        harness(gps: DeviceLocationResult.success(home)),
      );
      await openMap(tester);

      await tester.tap(find.byTooltip('Moja lokacija'));
      await tester.pumpAndSettle();

      expect(locationService.calls, 1);
      expect(find.text('45.5000, 20.1000'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    for (final failure in DeviceLocationFailure.values) {
      testWidgets('reports $failure and leaves the pin alone', (tester) async {
        await tester.pumpWidget(
          harness(gps: DeviceLocationResult.failure(failure)),
        );
        await openMap(tester);

        await tester.tap(find.byTooltip('Moja lokacija'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);

        final offersSettings = find.text('Otvori podešavanja');
        if (failure == DeviceLocationFailure.permissionBlocked) {
          expect(offersSettings, findsOneWidget);
        } else {
          expect(offersSettings, findsNothing);
        }
      });
    }
  });
}
