import 'package:flutter/foundation.dart';

import 'condition.dart';

/// Where a rule came from.
///
/// Present from the start so that community-contributed rules can be told apart
/// from the ones the app ships — shown differently, weighted differently, or
/// filtered out entirely — without a migration later.
enum RuleSource {
  builtIn,
  community;

  static RuleSource byName(String name) {
    for (final source in values) {
      if (source.name == name) return source;
    }
    return RuleSource.builtIn;
  }
}

/// One weather pattern that favours a particular threat.
///
/// A threat usually has several: a temperature rule and a humidity rule, each
/// contributing its own weight, so that one favourable factor reads as moderate
/// risk and both together as high. That mirrors how the web version scores, and
/// leaves room for a decisive combination to be written as a single rule with a
/// larger weight.
@immutable
class Rule {
  const Rule({
    required this.id,
    required this.threatId,
    required this.condition,
    this.weight = 1,
    this.source = RuleSource.builtIn,
    this.authorId,
  }) : assert(weight > 0, 'a rule that contributes nothing is not a rule');

  final String id;

  /// The threat this rule is evidence for.
  final String threatId;

  final Condition condition;

  /// How much this rule contributes to the threat's score when it matches.
  final int weight;

  final RuleSource source;

  /// Who contributed the rule, once accounts exist.
  final String? authorId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'threatId': threatId,
        'weight': weight,
        'source': source.name,
        if (authorId != null) 'authorId': authorId,
        'condition': condition.toJson(),
      };

  @override
  String toString() => 'Rule($id → $threatId, weight $weight)';
}
