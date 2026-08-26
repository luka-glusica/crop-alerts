import 'package:flutter/foundation.dart';

import '../../rules/domain/rule.dart';

/// What kind of problem a threat is.
///
/// The web version only models diseases; pests and the rest are the whole point
/// of widening it, since the weather that brings aphids is not the weather that
/// brings blight.
enum ThreatType {
  /// Blight, mildew, rots — anything fungal.
  fungalDisease,

  /// Insects, mites, slugs.
  pest,

  /// Physiological problems: blossom-end rot, splitting, sunscald, frost.
  other;

  static ThreatType? byName(String name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// Something that can go wrong with a crop, and what to do about it.
@immutable
class Threat {
  const Threat({
    required this.id,
    required this.type,
    required this.name,
    required this.rules,
    this.description,
    this.prevention = const [],
    this.response = const [],
  });

  /// Stable identifier, referenced by [Rule.threatId].
  final String id;

  final ThreatType type;

  /// Localized display name, e.g. "Plamenjača".
  final String name;

  /// Localized explanation of what the problem is.
  final String? description;

  /// What to do before it happens.
  final List<String> prevention;

  /// What to do once conditions already favour it.
  final List<String> response;

  /// The weather patterns that make this threat likely.
  final List<Rule> rules;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        if (description != null) 'description': description,
        'prevention': prevention,
        'response': response,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  @override
  String toString() => 'Threat($id, ${type.name}, ${rules.length} rules)';
}
