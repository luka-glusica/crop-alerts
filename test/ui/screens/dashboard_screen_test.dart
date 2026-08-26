import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/crops/crop_providers.dart';
import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_repository.dart';
import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/domain/location_book.dart';
import 'package:crop_alerts/features/locations/locations_controller.dart';
import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast_repository.dart';
import 'package:crop_alerts/features/weather/domain/weather_failure.dart';
import 'package:crop_alerts/features/weather/weather_providers.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/screens/dashboard_screen.dart';
import 'package:crop_alerts/ui/screens/locations_screen.dart';
import 'package:crop_alerts/ui/widgets/crop_risk_card.dart';
import 'package:crop_alerts/ui/widgets/metric_tile.dart';
import 'package:crop_alerts/ui/widgets/risk_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the shipped catalogue straight from disk, bypassing the asset bundle.
class _DiskCropRepository implements CropRepository {
  @override
  Future<List<Crop>> load(Locale locale) async {
    final language = locale.languageCode == 'en' ? 'en' : 'sr';
    return CropCatalogCodec.catalogFromJson(
      jsonDecode(File('assets/content/crops_$language.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  }
}

class _StubForecastRepository implements ForecastRepository {
  _StubForecastRepository(this.result, {this.throws});

  final ForecastResult result;
  final WeatherFailure? throws;
  int forcedRefreshes = 0;

  @override
  Future<ForecastResult> load(
    Coordinates coordinates, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) forcedRefreshes++;
    final failure = throws;
    if (failure != null) throw failure;
    return result;
  }

  @override
  Future<void> clear() async {}
}

void main() {
  late Forecast forecast;

  setUpAll(() {
    forecast = ForecastParser(
      localize: (utc) => utc.add(const Duration(hours: 2)).toUtc(),
    ).parse(
      jsonDecode(
        File('test/fixtures/met_locationforecast_compact.json').readAsStringSync(),
      ) as Map<String, dynamic>,
      coordinates: Coordinates.belgrade,
      fetchedAt: DateTime.utc(2026, 8, 25, 14, 43),
    );
  });

  /// Pumps the dashboard on a tall viewport.
  ///
  /// The default 800x600 test surface only builds the visible part of a lazy
  /// ListView, so counting cards or looking for the footer on it would quietly
  /// measure the viewport rather than the screen.
  Future<void> pumpDashboard(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Widget harness({
    ForecastSource source = ForecastSource.network,
    WeatherFailure? staleBecause,
    WeatherFailure? throws,
    LocationBook? locations,
    _StubForecastRepository? repository,
  }) {
    return ProviderScope(
      overrides: [
        locationStoreProvider
            .overrideWithValue(InMemoryLocationStore(locations)),
        cropRepositoryProvider.overrideWithValue(_DiskCropRepository()),
        forecastRepositoryProvider.overrideWithValue(
          repository ??
              _StubForecastRepository(
                ForecastResult(
                  forecast: forecast,
                  source: source,
                  failure: staleBecause,
                ),
                throws: throws,
              ),
        ),
      ],
      child: MaterialApp(
        locale: LocaleController.serbianLatin,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleController.supportedLocales,
        home: const DashboardScreen(),
      ),
    );
  }

  group('with a forecast', () {
    testWidgets('shows the active plot', (tester) async {
      await pumpDashboard(tester, harness());

      expect(find.text('Beograd'), findsOneWidget);
      expect(find.text('44.8078, 20.5656'), findsOneWidget);
      expect(find.text('AKTIVNA PARCELA'), findsOneWidget);
    });

    testWidgets('shows the current conditions', (tester) async {
      await pumpDashboard(tester, harness());

      expect(find.byType(MetricTile), findsNWidgets(4));
      expect(find.text('31.9°C'), findsOneWidget);
      expect(find.text('31.4%'), findsOneWidget);
    });

    testWidgets('renders a card per growing crop', (tester) async {
      await pumpDashboard(tester, harness());

      // All five seed crops are in season in late August.
      expect(find.byType(CropRiskCard), findsNWidgets(5));
      expect(find.text('Paradajz'), findsOneWidget);
      expect(find.text('Krompir'), findsOneWidget);
    });

    testWidgets('sorts the worst crop first', (tester) async {
      await pumpDashboard(tester, harness());

      final cards = tester
          .widgetList<CropRiskCard>(find.byType(CropRiskCard))
          .toList();

      for (var i = 1; i < cards.length; i++) {
        expect(
          cards[i - 1].assessment.overall.severity,
          greaterThanOrEqualTo(cards[i].assessment.overall.severity),
        );
      }
    });

    testWidgets('summarises how many crops are at risk', (tester) async {
      await pumpDashboard(tester, harness());

      // Serbian's few/other forms make this worth asserting on real data.
      expect(
        find.textContaining(RegExp('useva|usev')),
        findsWidgets,
      );
    });

    testWidgets('credits MET Norway, as their terms require', (tester) async {
      await pumpDashboard(tester, harness());

      expect(find.textContaining('MET Norway'), findsOneWidget);
    });

    testWidgets('shows when the forecast was last recalculated', (tester) async {
      await pumpDashboard(tester, harness());

      // MET's updated_at, not our fetch time.
      expect(find.textContaining('Poslednje ažuriranje'), findsOneWidget);
    });

    testWidgets('does not show the offline banner on fresh data',
        (tester) async {
      await pumpDashboard(tester, harness());

      expect(find.textContaining('nema veze sa mrežom'), findsNothing);
    });
  });

  group('stale data', () {
    testWidgets('says it is showing saved data rather than passing it off as '
        'current', (tester) async {
      await pumpDashboard(tester, harness(
          source: ForecastSource.staleCache,
          staleBecause: const WeatherNetworkFailure('offline'),
        ));

      expect(find.textContaining('nema veze sa mrežom'), findsOneWidget);
      // The forecast is still shown; old numbers beat an error screen.
      expect(find.byType(CropRiskCard), findsNWidgets(5));
    });
  });

  group('failure', () {
    testWidgets('offers a retry when there is nothing cached', (tester) async {
      await pumpDashboard(tester, harness(throws: const WeatherNetworkFailure('offline')));

      expect(find.text('Nije moguće preuzeti vremensku prognozu.'),
          findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
      expect(find.byType(CropRiskCard), findsNothing);
    });
  });

  group('no plots', () {
    testWidgets('shows the empty state rather than an error', (tester) async {
      await pumpDashboard(tester, harness(locations: const LocationBook(locations: [])));

      // An empty saved book is re-seeded, so delete the seeded plot to get a
      // genuinely empty dashboard.
      final element = tester.element(find.byType(DashboardScreen));
      final container = ProviderScope.containerOf(element);
      final book = container.read(locationsProvider);
      await container
          .read(locationsProvider.notifier)
          .remove(book.locations.single.id);
      await tester.pumpAndSettle();

      expect(find.text('Nemate nijednu parcelu.'), findsOneWidget);
    });
  });

  group('interaction', () {
    testWidgets('pull to refresh asks the repository to force a refresh',
        (tester) async {
      final repository = _StubForecastRepository(
        ForecastResult(forecast: forecast, source: ForecastSource.network),
      );
      await pumpDashboard(tester, harness(repository: repository));

      // Invoking the callback directly rather than simulating the drag: the
      // gesture mechanics belong to Flutter, what matters here is that the
      // pull is wired to a forced refresh rather than an ordinary load.
      final indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();

      expect(repository.forcedRefreshes, 1);
    });

    testWidgets('opens the plots screen', (tester) async {
      await pumpDashboard(tester, harness());

      await tester.tap(find.byTooltip('Parcele'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationsScreen), findsOneWidget);
    });
  });

  group('layout regressions', () {
    testWidgets('the risk strip bars actually have height', (tester) async {
      // A childless DecoratedBox under a GestureDetector receives loose
      // constraints and collapses to zero height, painting nothing while still
      // reserving the space — a strip that looks like a blank gap.
      await pumpDashboard(tester, harness());

      final bars = find.descendant(
        of: find.byType(RiskStrip).first,
        matching: find.byType(DecoratedBox),
      );
      expect(bars, findsWidgets);
      for (final bar in bars.evaluate()) {
        expect(
          tester.getSize(find.byWidget(bar.widget)).height,
          greaterThan(0),
        );
      }
    });

    testWidgets('a metric tile never clips its reading', (tester) async {
      // "Trenutna temperatura" wraps to two lines on a narrow screen, which a
      // fixed grid aspect ratio pushed the reading out of.
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      for (final tile in find.byType(MetricTile).evaluate()) {
        final tileSize = tester.getSize(find.byWidget(tile.widget));
        final value = find.descendant(
          of: find.byWidget(tile.widget),
          matching: find.byType(Text),
        );
        final lastTextBottom = tester.getBottomLeft(value.last).dy;
        final tileBottom = tester.getBottomLeft(find.byWidget(tile.widget)).dy;

        expect(
          lastTextBottom,
          lessThanOrEqualTo(tileBottom),
          reason: 'a reading is drawn outside its tile (${tileSize.height}px)',
        );
      }
    });
  });

  group('dormant crops', () {
    testWidgets('are folded away when out of season', (tester) async {
      // In February nothing in the seed catalogue is in the ground.
      final winter = Forecast(
        coordinates: Coordinates.belgrade,
        updatedAt: DateTime.utc(2026, 2, 10),
        fetchedAt: DateTime.utc(2026, 2, 10),
        now: forecast.now,
        days: [
          for (var i = 0; i < 10; i++)
            DailyForecast(
              date: DateTime(2026, 2, 10 + i),
              minTemperature: 2,
              maxTemperature: 8,
              minHumidity: 70,
              maxHumidity: 95,
              precipitation: 4,
              sampleCount: 24,
            ),
        ],
      );

      await pumpDashboard(
        tester,
        ProviderScope(
          overrides: [
            locationStoreProvider.overrideWithValue(InMemoryLocationStore()),
            cropRepositoryProvider.overrideWithValue(_DiskCropRepository()),
            forecastRepositoryProvider.overrideWithValue(
              _StubForecastRepository(
                ForecastResult(
                  forecast: winter,
                  source: ForecastSource.network,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            locale: LocaleController.serbianLatin,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleController.supportedLocales,
            home: const DashboardScreen(),
          ),
        ),
      );

      // Collapsed, so no cards are visible until the section is opened.
      expect(find.byType(CropRiskCard), findsNothing);
      expect(find.textContaining('van sezone'), findsOneWidget);

      await tester.tap(find.textContaining('van sezone'));
      await tester.pumpAndSettle();

      expect(find.byType(CropRiskCard), findsNWidgets(5));
    });
  });
}
