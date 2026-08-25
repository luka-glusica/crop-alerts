import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/core/flags/flags.dart';
import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/core/theme/theme.dart';
import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_assessment.dart';
import 'package:crop_alerts/features/crops/domain/crop_risk_evaluator.dart';
import 'package:crop_alerts/features/rules/domain/risk.dart';
import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:crop_alerts/ui/screens/crop_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = CropRiskEvaluator();
  late List<Crop> crops;
  late List<DailyForecast> forecast;

  setUpAll(() {
    crops = CropCatalogCodec.catalogFromJson(
      jsonDecode(File('assets/content/crops_sr.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    forecast = ForecastParser(
      localize: (utc) => utc.add(const Duration(hours: 2)).toUtc(),
    )
        .parse(
          jsonDecode(
            File('test/fixtures/met_locationforecast_compact.json')
                .readAsStringSync(),
          ) as Map<String, dynamic>,
          coordinates: Coordinates.belgrade,
          fetchedAt: DateTime.utc(2026, 8, 25, 14, 43),
        )
        .days;
  });

  CropAssessment assessmentFor(String cropId, {List<DailyForecast>? days}) {
    return evaluator.assess(
      crop: crops.firstWhere((c) => c.id == cropId),
      forecast: days ?? forecast,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    CropAssessment assessment, {
    bool ratings = false,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagStoreProvider.overrideWithValue(
            InMemoryFeatureFlagStore(
              ratings ? {FeatureFlag.mitigationRatings: true} : null,
            ),
          ),
        ],
        child: MaterialApp(
          locale: LocaleController.serbianLatin,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleController.supportedLocales,
          home: CropDetailScreen(assessment: assessment),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('header', () {
    testWidgets('names the crop and its growing season', (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      expect(find.text('Krompir'), findsWidgets);
      expect(find.textContaining('Sezona: mart – septembar'), findsOneWidget);
    });
  });

  group('the selected day', () {
    testWidgets('opens on the worst day, not on today', (tester) async {
      // Someone tapping through from a high-risk card is asking about the risk.
      final assessment = assessmentFor('krompir');
      await pumpDetail(tester, assessment);

      final worst = assessment.daysAtRisk.first;
      expect(
        find.textContaining(worst.date.day.toString()),
        findsWidgets,
      );
      expect(find.text('Krompirova zlatica'), findsWidgets);
    });

    testWidgets('explains why, with the readings that triggered the rules',
        (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      expect(find.text('ZAŠTO'), findsWidgets);
      // The Colorado beetle rule is heat plus a dry spell; both readings should
      // be on screen, in words, with units.
      expect(find.textContaining('najviša temperatura'), findsWidgets);
      expect(find.textContaining('°C'), findsWidgets);
      expect(find.textContaining('padavine'), findsWidgets);
      expect(find.textContaining('mm'), findsWidgets);
    });

    testWidgets('gives the response steps for what is actually threatening',
        (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      expect(find.text('MERE'), findsWidgets);
      expect(
        find.textContaining('Ručno sakupljanje odraslih jedinki'),
        findsOneWidget,
      );
    });

    testWidgets('switching day changes what is shown', (tester) async {
      final assessment = assessmentFor('krompir');
      await pumpDetail(tester, assessment);

      // 28 August is a quiet day for potato in this forecast.
      final quiet = assessment.days
          .indexWhere((d) => d.risk.level == RiskLevel.low);
      expect(quiet, greaterThanOrEqualTo(0));

      await tester.tap(
        find.text('${assessment.days[quiet].date.day}.').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Nema povećanog rizika za ovaj dan.'), findsOneWidget);
    });
  });

  group('the threat reference', () {
    testWidgets('groups every threat by kind', (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      expect(find.text('Gljivične bolesti'), findsOneWidget);
      expect(find.text('Štetočine'), findsOneWidget);
      expect(find.text('Ostali problemi'), findsOneWidget);
    });

    testWidgets('lists prevention for threats that are not firing',
        (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      // Late blight is quiet in this dry spell, but its prevention advice is
      // still the useful thing to read.
      expect(find.text('Plamenjača krompira'), findsWidgets);
      expect(find.text('PREVENCIJA'), findsWidgets);
      expect(
        find.textContaining('Sertifikovano, zdravo seme'),
        findsOneWidget,
      );
    });
  });

  group('out of season', () {
    testWidgets('says the rules do not apply, and hides the day selector',
        (tester) async {
      final winter = [
        for (var i = 0; i < 10; i++)
          DailyForecast(
            date: DateTime(2026, 1, 5 + i),
            minTemperature: 16,
            maxTemperature: 20,
            minHumidity: 80,
            maxHumidity: 95,
            precipitation: 12,
            sampleCount: 24,
          ),
      ];

      await pumpDetail(tester, assessmentFor('krompir', days: winter));

      expect(
        find.text('Ovaj usev je van sezone, pa se pravila ne primenjuju.'),
        findsOneWidget,
      );
      expect(find.text('IZABERITE DAN'), findsNothing);
      // The reference section is still there — it is what a grower plans from.
      expect(find.text('Gljivične bolesti'), findsOneWidget);
    });
  });

  group('mitigation rating', () {
    testWidgets('is hidden while the flag is off', (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'));

      expect(find.text('Da li je ovaj savet pomogao?'), findsNothing);
    });

    testWidgets('appears when the flag is on', (tester) async {
      await pumpDetail(tester, assessmentFor('krompir'), ratings: true);

      expect(find.text('Da li je ovaj savet pomogao?'), findsWidgets);
    });
  });
}
