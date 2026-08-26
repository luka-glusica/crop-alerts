import '../domain/condition.dart';
import '../domain/rule.dart';
import '../domain/weather_metric.dart';

/// Raised when a rule document cannot be read.
class RuleFormatException implements Exception {
  const RuleFormatException(this.message);

  final String message;

  @override
  String toString() => 'RuleFormatException: $message';
}

/// Reads conditions and rules back from JSON.
///
/// This is the half of the rule engine that makes the future work possible:
/// rules corrected centrally or contributed by other growers arrive as data.
/// It is deliberately strict — an unknown condition type or metric is an error,
/// never a condition that quietly never matches, because a rule that silently
/// does nothing is worse than one that fails loudly.
abstract final class ConditionCodec {
  static Condition conditionFromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) {
      throw const RuleFormatException('Condition has no "type".');
    }

    return switch (type) {
      'metricThreshold' => MetricThreshold(
          metric: _metric(json, 'metric'),
          comparator: _comparator(json, 'comparator'),
          value: _number(json, 'value'),
        ),
      'metricBand' => MetricBand(
          metric: _metric(json, 'metric'),
          min: _number(json, 'min'),
          max: _number(json, 'max'),
        ),
      'rangeOverlap' => RangeOverlap(
          lower: _metric(json, 'lower'),
          upper: _metric(json, 'upper'),
          min: _number(json, 'min'),
          max: _number(json, 'max'),
        ),
      'sumOverDays' => SumOverDays(
          metric: _metric(json, 'metric'),
          days: _positiveInt(json, 'days'),
          comparator: _comparator(json, 'comparator'),
          value: _number(json, 'value'),
        ),
      'consecutiveDays' => ConsecutiveDays(
          days: _positiveInt(json, 'days'),
          condition: conditionFromJson(_object(json, 'condition')),
        ),
      'monthRange' => MonthRange(
          fromMonth: _month(json, 'fromMonth'),
          toMonth: _month(json, 'toMonth'),
        ),
      'allOf' => AllOf(_conditions(json)),
      'anyOf' => AnyOf(_conditions(json)),
      'not' => Not(conditionFromJson(_object(json, 'condition'))),
      _ => throw RuleFormatException('Unknown condition type "$type".'),
    };
  }

  static Rule ruleFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final threatId = json['threatId'];
    if (id is! String || id.isEmpty) {
      throw const RuleFormatException('Rule has no "id".');
    }
    if (threatId is! String || threatId.isEmpty) {
      throw RuleFormatException('Rule "$id" has no "threatId".');
    }

    final weight = json['weight'];
    if (weight != null && (weight is! num || weight <= 0)) {
      throw RuleFormatException('Rule "$id" has a weight that is not positive.');
    }

    final source = json['source'];

    return Rule(
      id: id,
      threatId: threatId,
      condition: conditionFromJson(_object(json, 'condition')),
      weight: (weight as num?)?.toInt() ?? 1,
      source: source is String ? RuleSource.byName(source) : RuleSource.builtIn,
      authorId: json['authorId'] as String?,
    );
  }

  static List<Rule> rulesFromJson(List<dynamic> json) {
    return json.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const RuleFormatException('A rule entry is not an object.');
      }
      return ruleFromJson(raw);
    }).toList();
  }

  static List<Condition> _conditions(Map<String, dynamic> json) {
    final raw = json['conditions'];
    if (raw is! List || raw.isEmpty) {
      throw RuleFormatException(
        'A "${json['type']}" needs a non-empty "conditions" list.',
      );
    }
    return raw.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const RuleFormatException('A nested condition is not an object.');
      }
      return conditionFromJson(entry);
    }).toList();
  }

  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw RuleFormatException('Expected an object at "$key".');
    }
    return value;
  }

  static WeatherMetric _metric(Map<String, dynamic> json, String key) {
    final name = json[key];
    if (name is! String) {
      throw RuleFormatException('Expected a metric name at "$key".');
    }
    final metric = WeatherMetric.byName(name);
    if (metric == null) {
      throw RuleFormatException('Unknown weather metric "$name".');
    }
    return metric;
  }

  static Comparator _comparator(Map<String, dynamic> json, String key) {
    final name = json[key];
    if (name is! String) {
      throw RuleFormatException('Expected a comparator at "$key".');
    }
    final comparator = Comparator.byName(name);
    if (comparator == null) {
      throw RuleFormatException('Unknown comparator "$name".');
    }
    return comparator;
  }

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw RuleFormatException('Expected a number at "$key".');
    }
    return value.toDouble();
  }

  static int _positiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || value <= 0 || value != value.roundToDouble()) {
      throw RuleFormatException('Expected a positive whole number at "$key".');
    }
    return value.toInt();
  }

  static int _month(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num ||
        value != value.roundToDouble() ||
        value < 1 ||
        value > 12) {
      throw RuleFormatException('Expected a month 1–12 at "$key".');
    }
    return value.toInt();
  }
}
