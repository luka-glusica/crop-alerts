import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/crop_risk_evaluator.dart';
import 'package:crop_alerts/features/rules/domain/risk.dart';
import 'package:crop_alerts/features/weather/data/forecast_parser.dart';
import 'package:crop_alerts/features/weather/domain/coordinates.dart';
import 'package:crop_alerts/features/weather/domain/daily_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

/// End to end over the whole pipeline: a real MET Norway response for Belgrade,
/// parsed, then run through the shipped catalogue.
///
/// This is where an over-eager rule shows up. A model that flags everything is
/// no more useful than one that flags nothing, and the captured forecast is a
/// hot, dry late-August spell — genuinely poor weather for the fungal diseases
/// and genuinely good weather for the heat and drought problems.
void main() {
  late List<DailyForecast> forecast;
  late List<Crop> crops;
  const evaluator = CropRiskEvaluator();

  setUpAll(() {
    final raw = File('test/fixtures/met_locationforecast_compact.json')
        .readAsStringSync();
    forecast = ForecastParser(
      localize: (utc) => utc.add(const Duration(hours: 2)).toUtc(),
    )
        .parse(
          jsonDecode(raw) as Map<String, dynamic>,
          coordinates: Coordinates(latitude: 44.8078, longitude: 20.5656),
          fetchedAt: DateTime.utc(2026, 8, 25, 14, 43),
        )
        .days;

    crops = CropCatalogCodec.catalogFromJson(
      jsonDecode(File('assets/content/crops_sr.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  test('the forecast is the hot dry spell these expectations assume', () {
    // If the fixture is ever replaced, this fails first and explains why the
    // rest of the group started failing too.
    expect(forecast, hasLength(10));
    expect(forecast.every((d) => d.maxTemperature > 25), isTrue);
    expect(forecast.every((d) => d.minHumidity < 55), isTrue);
  });

  test('every crop is assessed without error', () {
    final assessments = evaluator.assessAll(crops: crops, forecast: forecast);

    expect(assessments, hasLength(crops.length));
    for (final assessment in assessments) {
      expect(assessment.days, hasLength(forecast.length));
    }
  });

  test('blight never reaches high risk in dry heat', () {
    // The web version's `maxHumidity > 80` fires on seven of these ten days,
    // which on its own would read as raised blight risk through a heatwave.
    // Requiring the temperature window and a leaf that never dried, together,
    // does not fire at all here.
    //
    // A *moderate* signal is still expected and correct: 9.3 mm fell on the
    // 25th, and rain is genuine evidence even when the air is otherwise dry.
    for (final crop in crops) {
      final assessment = evaluator.assess(crop: crop, forecast: forecast);
      final blight = assessment.days
          .expand((d) => d.threats)
          .where((t) => t.threat.id == 'plamenjaca')
          .toList();

      expect(
        blight.every((t) => t.level == RiskLevel.moderate),
        isTrue,
        reason: '${crop.id} reports high blight risk in a dry heatwave',
      );
      expect(
        blight.every(
          (t) => t.matches.every((m) => m.rule.id.endsWith('.padavine')),
        ),
        isTrue,
        reason: '${crop.id} blight fired on something other than rainfall',
      );
    }
  });

  test('the heat and drought problems do fire, which is the point', () {
    final assessments = evaluator.assessAll(crops: crops, forecast: forecast);

    final firing = assessments
        .expand((a) => a.days)
        .expand((d) => d.threats)
        .map((t) => t.threat.id)
        .toSet();

    expect(
      firing,
      isNotEmpty,
      reason: 'a model that never fires is as useless as one that always does',
    );
    // Hot and dry is exactly spider mite and blossom-end rot weather.
    expect(firing, contains('paucinar'));
  });

  test('risk is not uniform across crops', () {
    final assessments = evaluator.assessAll(crops: crops, forecast: forecast);
    final levels = assessments.map((a) => a.overall).toSet();

    expect(
      levels.length,
      greaterThan(1),
      reason: 'every crop landing on the same level suggests the rules are '
          'keying off something that is always true',
    );
  });

  test('no crop is at high risk on every single day', () {
    for (final crop in crops) {
      final assessment = evaluator.assess(crop: crop, forecast: forecast);
      final highDays =
          assessment.days.where((d) => d.risk.level == RiskLevel.high).length;

      expect(
        highDays,
        lessThan(forecast.length),
        reason: '${crop.id} is at high risk for the entire ten days',
      );
    }
  });

  test('crops out of season in late August stay silent', () {
    // Onion runs March to August, so it is still in; nothing here is dormant,
    // but the gating still has to hold on the September days for onion.
    final onion = crops.firstWhere((c) => c.id == 'luk');
    final assessment = evaluator.assess(crop: onion, forecast: forecast);

    final september = assessment.days.where((d) => d.date.month == 9);
    expect(september, isNotEmpty);
    expect(september.every((d) => !d.inSeason), isTrue);
    expect(september.every((d) => d.threats.isEmpty), isTrue);
  });

  test('every reported threat carries advice and an explanation', () {
    final assessments = evaluator.assessAll(crops: crops, forecast: forecast);

    for (final assessment in assessments) {
      for (final day in assessment.days) {
        for (final threat in day.threats) {
          expect(threat.threat.response, isNotEmpty);
          expect(threat.matches, isNotEmpty);
          expect(
            threat.matches.expand((m) => m.observations),
            isNotEmpty,
            reason: '${assessment.crop.id}/${threat.threat.id} on ${day.date} '
                'was flagged with nothing to show the grower',
          );
        }
      }
    }
  });
}
