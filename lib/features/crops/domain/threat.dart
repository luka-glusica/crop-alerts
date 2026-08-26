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
    this.scientificName,
    this.description,
    this.caution,
    this.prevention = const [],
    this.response = const [],
  });

  /// Stable identifier, referenced by [Rule.threatId].
  final String id;

  final ThreatType type;

  /// Localized display name, e.g. "Plamenjača".
  final String name;

  /// The binomial, e.g. "Phytophthora infestans".
  ///
  /// Deliberately not localized: Latin is the same in every language, which
  /// makes this the one piece of threat text that cannot drift between the two
  /// catalogue files. Null for physiological problems, which have no organism
  /// to name.
  final String? scientificName;

  /// Localized explanation of what the problem is.
  final String? description;

  /// What to do before it happens.
  final List<String> prevention;

  /// What to do once conditions already favour it.
  final List<String> response;

  /// A localized warning about the advice itself.
  ///
  /// Organic does not mean harmless: sulphur scorches leaves above roughly
  /// 28 °C, essential oils burn in full sun, and some traditional preparations
  /// are outright banned as plant protection products. Advice that carries a
  /// risk has to say so next to the advice, not in a footnote nobody reads.
  final String? caution;

  /// The weather patterns that make this threat likely.
  final List<Rule> rules;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        if (scientificName != null) 'scientificName': scientificName,
        if (description != null) 'description': description,
        'prevention': prevention,
        'response': response,
        if (caution != null) 'caution': caution,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  @override
  String toString() => 'Threat($id, ${type.name}, ${rules.length} rules)';
}
