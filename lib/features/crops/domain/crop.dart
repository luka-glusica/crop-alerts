import 'package:flutter/foundation.dart';

import '../../rules/domain/rule.dart';
import 'growing_season.dart';
import 'threat.dart';

/// Where a crop's definition came from.
///
/// Present from the start so community-contributed crops can be marked, sorted
/// or filtered once accounts exist, without a migration.
enum CropSource {
  builtIn,
  community;

  static CropSource byName(String name) {
    for (final source in values) {
      if (source.name == name) return source;
    }
    return CropSource.builtIn;
  }
}

/// A crop, its growing season, and everything that threatens it.
@immutable
class Crop {
  const Crop({
    required this.id,
    required this.name,
    required this.season,
    required this.threats,
    this.source = CropSource.builtIn,
    this.authorId,
  });

  /// Stable identifier, also the key for artwork.
  final String id;

  /// Localized display name.
  final String name;

  final GrowingSeason season;

  final List<Threat> threats;

  final CropSource source;

  /// Who contributed the crop, once accounts exist.
  final String? authorId;

  /// Every rule across every threat, which is what the engine consumes.
  List<Rule> get rules => [
        for (final threat in threats) ...threat.rules,
      ];

  /// The threat with [id], or `null`.
  ///
  /// Used to put names and advice back onto the engine's output, which deals
  /// only in threat ids.
  Threat? threatById(String id) {
    for (final threat in threats) {
      if (threat.id == id) return threat;
    }
    return null;
  }

  /// The threats of a given kind, for grouping in the UI.
  List<Threat> threatsOfType(ThreatType type) =>
      threats.where((t) => t.type == type).toList();

  /// Whether the crop is in the ground on [date].
  bool isInSeasonOn(DateTime date) => season.containsDate(date);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season.toJson(),
        'source': source.name,
        if (authorId != null) 'authorId': authorId,
        'threats': threats.map((t) => t.toJson()).toList(),
      };

  @override
  String toString() => 'Crop($id, ${threats.length} threats)';
}
