import '../../weather/domain/daily_forecast.dart';
import 'risk.dart';
import 'rule.dart';
import 'weather_window.dart';

/// Runs a set of rules over a forecast and reports the resulting risk per day.
///
/// The engine knows nothing about crops, seasons or advice: it takes rules and
/// weather and produces scores. Joining that to a crop's threats and gating it
/// on the growing season happens a layer up, which keeps this testable against
/// hand-built forecasts and keeps crop concerns out of the scoring.
class RuleEngine {
  const RuleEngine({this.scoring = RiskScoring.standard});

  final RiskScoring scoring;

  /// Evaluates [rules] against [forecast], one result per day.
  List<DayRisk> evaluate({
    required List<Rule> rules,
    required List<DailyForecast> forecast,
  }) {
    return WeatherWindow.over(forecast).map((w) => evaluateDay(rules, w)).toList();
  }

  /// Evaluates [rules] for the single day [window] is centred on.
  DayRisk evaluateDay(List<Rule> rules, WeatherWindow window) {
    final matchesByThreat = <String, List<RuleMatch>>{};
    final scoreByThreat = <String, int>{};

    for (final rule in rules) {
      final result = rule.condition.evaluate(window);
      if (!result.matched) continue;

      matchesByThreat.putIfAbsent(rule.threatId, () => []).add(
            RuleMatch(rule: rule, observations: result.observations),
          );
      scoreByThreat[rule.threatId] =
          (scoreByThreat[rule.threatId] ?? 0) + rule.weight;
    }

    final threats = <ThreatRisk>[];
    for (final entry in scoreByThreat.entries) {
      final level = scoring.levelFor(entry.value);
      // A threat that scored below the moderate mark is not news.
      if (level == RiskLevel.low) continue;

      threats.add(
        ThreatRisk(
          threatId: entry.key,
          level: level,
          score: entry.value,
          matches: matchesByThreat[entry.key] ?? const [],
        ),
      );
    }

    // Worst first, then by score, then by id so the order is stable across runs
    // rather than depending on map iteration.
    threats.sort((a, b) {
      final bySeverity = b.level.severity.compareTo(a.level.severity);
      if (bySeverity != 0) return bySeverity;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.threatId.compareTo(b.threatId);
    });

    return DayRisk(
      date: window.date,
      level: threats.isEmpty ? RiskLevel.low : threats.first.level,
      threats: threats,
    );
  }

  /// The worst level across [days], for summarising a crop or a location.
  static RiskLevel worstOf(Iterable<DayRisk> days) {
    var worst = RiskLevel.low;
    for (final day in days) {
      if (day.level > worst) worst = day.level;
    }
    return worst;
  }
}
