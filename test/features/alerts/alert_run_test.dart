import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/features/alerts/alert_run.dart';
import 'package:crop_alerts/features/alerts/notification_preferences.dart';
import 'package:crop_alerts/features/alerts/notification_service.dart';
import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_repository.dart';
import 'package:crop_alerts/features/locations/data/prefs_location_store.dart';
import 'package:crop_alerts/features/locations/domain/location_book.dart';
import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/forecast.dart';
import 'package:crop_alerts/features/weather/domain/forecast_repository.dart';
import 'package:crop_alerts/features/weather/domain/weather_failure.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiskCrops implements CropRepository {
  @override
  Future<List<Crop>> load(Locale locale) async =>
      CropCatalogCodec.catalogFromJson(
        jsonDecode(File('assets/content/crops_sr.json').readAsStringSync())
            as Map<String, dynamic>,
      );
}

class _StubForecasts implements ForecastRepository {
  _StubForecasts(this.forecast, {this.throws});

  final Forecast forecast;
  final WeatherFailure? throws;

  @override
  Future<ForecastResult> load(
    Coordinates coordinates, {
    bool forceRefresh = false,
  }) async {
    final failure = throws;
    if (failure != null) throw failure;
    return ForecastResult(
      forecast: forecast,
      source: ForecastSource.network,
    );
  }

  @override
  Future<void> clear() async {}
}

void main() {
  late Forecast forecast;
  // The captured forecast starts on 25 August 2026.
  final today = DateTime(2026, 8, 25);

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

  ({AlertRun run, NoopNotificationService notifications,
    InMemoryNotificationPreferencesStore store}) build({
    NotificationPreferences preferences =
        const NotificationPreferences(high: true),
    String? lastAlertKey,
    LocationBook? locations,
    WeatherFailure? throws,
    bool permitted = true,
  }) {
    final notifications = NoopNotificationService()..permitted = permitted;
    final store = InMemoryNotificationPreferencesStore(preferences, lastAlertKey);

    return (
      run: AlertRun(
        locations: InMemoryLocationStore(locations ?? LocationBook.seeded()),
        forecasts: _StubForecasts(forecast, throws: throws),
        crops: _DiskCrops(),
        preferences: store,
        notifications: notifications,
        locale: LocaleController.serbianLatin,
      ),
      notifications: notifications,
      store: store,
    );
  }

  group('when it notifies', () {
    test('sends one alert naming the crops at risk', () async {
      final built = build();

      expect(await built.run.execute(now: today), AlertOutcome.notified);
      expect(built.notifications.shown, hasLength(1));

      final alert = built.notifications.shown.single;
      expect(alert.title, 'Poljoprivredni Paničar');
      expect(alert.body, contains('visok rizik'));
      expect(alert.body, contains('usevi:'));
    });

    test('names at most four crops, so the body stays readable', () async {
      final built = build();
      await built.run.execute(now: today);

      final crops = built.notifications.shown.single.body.split('usevi: ').last;
      expect(crops.split(', ').length, lessThanOrEqualTo(4));
    });

    test('reports moderate risk only when asked to', () async {
      final highOnly = build();
      await highOnly.run.execute(now: today);
      expect(highOnly.notifications.shown.single.body,
          isNot(contains('umeren rizik')));

      final both = build(
        preferences: const NotificationPreferences(high: true, moderate: true),
      );
      await both.run.execute(now: today);
      expect(both.notifications.shown.single.body, contains('umeren rizik'));
    });
  });

  group('de-duplication', () {
    test('the same outlook is not delivered twice', () async {
      // Four runs a day would otherwise repeat the same news four times.
      final built = build();

      expect(await built.run.execute(now: today), AlertOutcome.notified);
      expect(await built.run.execute(now: today), AlertOutcome.alreadyDelivered);
      expect(await built.run.execute(now: today), AlertOutcome.alreadyDelivered);
      expect(built.notifications.shown, hasLength(1));
    });

    test('a worsening outlook does get through', () async {
      // The key is built from the content, not the date, so genuinely new
      // information is not suppressed for the rest of the day.
      final built = build(lastAlertKey: 'high|1|0|Paradajz');

      expect(await built.run.execute(now: today), AlertOutcome.notified);
    });

    test('the key survives across runs', () async {
      final built = build();
      await built.run.execute(now: today);

      expect(built.store.readLastAlertKey(), isNotNull);
    });
  });

  group('when it stays quiet', () {
    test('notifications switched off', () async {
      final built = build(preferences: const NotificationPreferences());

      expect(
        await built.run.execute(now: today),
        AlertOutcome.notificationsDisabled,
      );
      expect(built.notifications.shown, isEmpty);
    });

    test('permission refused', () async {
      final built = build(permitted: false);

      expect(await built.run.execute(now: today), AlertOutcome.notPermitted);
      expect(built.notifications.shown, isEmpty);
    });

    test('no plot to check', () async {
      final built = build(locations: const LocationBook(locations: []));

      expect(await built.run.execute(now: today), AlertOutcome.noLocation);
    });

    test('nothing crossing the threshold', () async {
      // Deep winter: every crop is dormant, so nothing can be reported.
      final built = build();

      expect(
        await built.run.execute(now: DateTime(2027)),
        AlertOutcome.nothingToReport,
      );
      expect(built.notifications.shown, isEmpty);
    });

    test('the forecast is unavailable', () async {
      final built = build(throws: const WeatherNetworkFailure('offline'));

      expect(
        await built.run.execute(now: today),
        AlertOutcome.forecastUnavailable,
      );
      expect(
        built.notifications.shown,
        isEmpty,
        reason: 'a background job is the wrong place to complain about network',
      );
    });
  });
}
