import '../../rules/domain/risk.dart';
import '../../rules/domain/rule_engine.dart';
import '../../weather/domain/daily_forecast.dart';
import 'crop.dart';
import 'crop_assessment.dart';

/// Runs the rule engine for a crop and dresses the result in the crop's own
/// threats and growing season.
///
/// The engine deals in rules, weights and threat ids and knows nothing about
/// crops; this is the layer that gates on the season and puts names and advice
/// back onto the ids.
class CropRiskEvaluator {
  const CropRiskEvaluator({this.engine = const RuleEngine()});

  final RuleEngine engine;

  /// Assesses [crop] against [forecast].
  CropAssessment assess({
    required Crop crop,
    required List<DailyForecast> forecast,
  }) {
    final risks = engine.evaluate(rules: crop.rules, forecast: forecast);

    final days = <CropDayAssessment>[];
    for (final risk in risks) {
      final inSeason = crop.isInSeasonOn(risk.date);

      // Out of season the rules still ran, but their verdict is discarded: the
      // weather may well suit late blight in January, and saying so about a
      // crop that is not in the ground is noise that teaches a grower to ignore
      // the app. The day is kept so the timeline stays continuous.
      if (!inSeason) {
        days.add(
          CropDayAssessment(
            date: risk.date,
            inSeason: false,
            risk: DayRisk(
              date: risk.date,
              level: RiskLevel.low,
              threats: const [],
            ),
            threats: const [],
          ),
        );
        continue;
      }

      days.add(
        CropDayAssessment(
          date: risk.date,
          inSeason: true,
          risk: risk,
          threats: _resolve(crop, risk),
        ),
      );
    }

    return CropAssessment(
      crop: crop,
      days: days,
      overall: RuleEngine.worstOf(days.map((d) => d.risk)),
    );
  }

  /// Assesses several crops at once, worst first.
  List<CropAssessment> assessAll({
    required List<Crop> crops,
    required List<DailyForecast> forecast,
  }) {
    final assessments = [
      for (final crop in crops) assess(crop: crop, forecast: forecast),
    ];

    assessments.sort((a, b) {
      // Dormant crops sink below everything, however alarming their rules
      // would have been.
      if (a.isDormant != b.isDormant) return a.isDormant ? 1 : -1;
      final bySeverity = b.overall.severity.compareTo(a.overall.severity);
      if (bySeverity != 0) return bySeverity;
      return a.crop.name.compareTo(b.crop.name);
    });

    return assessments;
  }

  List<AssessedThreat> _resolve(Crop crop, DayRisk risk) {
    final resolved = <AssessedThreat>[];
    for (final threatRisk in risk.threats) {
      final threat = crop.threatById(threatRisk.threatId);
      // A rule naming a threat the crop does not define is a content bug that
      // the catalogue validator rejects at load time; skip rather than crash if
      // one ever reaches here from a remote source.
      if (threat == null) continue;

      resolved.add(
        AssessedThreat(
          threat: threat,
          level: threatRisk.level,
          score: threatRisk.score,
          matches: threatRisk.matches,
        ),
      );
    }
    return resolved;
  }
}
