import '../../rules/data/condition_codec.dart';
import '../../rules/domain/rule.dart';
import '../domain/crop.dart';
import '../domain/growing_season.dart';
import '../domain/threat.dart';

/// Raised when a crop catalogue cannot be read.
class CropCatalogException implements Exception {
  const CropCatalogException(this.message);

  final String message;

  @override
  String toString() => 'CropCatalogException: $message';
}

/// Reads a crop catalogue from the JSON shape used by both the bundled content
/// files and, later, a server serving community contributions.
///
/// Validation is strict and happens at load time rather than at the point of
/// use: a crop whose rule points at a threat it does not define would evaluate
/// to permanent silence, which looks exactly like good weather.
abstract final class CropCatalogCodec {
  /// Catalogue format version. Bumped if the shape changes incompatibly.
  static const int version = 1;

  static List<Crop> catalogFromJson(Map<String, dynamic> json) {
    final declaredVersion = json['version'];
    if (declaredVersion is! num) {
      throw const CropCatalogException('Catalogue has no "version".');
    }
    if (declaredVersion.toInt() != version) {
      throw CropCatalogException(
        'Catalogue is version $declaredVersion; this build reads version $version.',
      );
    }

    final rawCrops = json['crops'];
    if (rawCrops is! List) {
      throw const CropCatalogException('Catalogue has no "crops" list.');
    }

    final crops = <Crop>[];
    final seenIds = <String>{};
    for (final raw in rawCrops) {
      if (raw is! Map<String, dynamic>) {
        throw const CropCatalogException('A crop entry is not an object.');
      }
      final crop = cropFromJson(raw);
      if (!seenIds.add(crop.id)) {
        throw CropCatalogException('Duplicate crop id "${crop.id}".');
      }
      crops.add(crop);
    }

    return crops;
  }

  static Crop cropFromJson(Map<String, dynamic> json) {
    final id = _nonEmptyString(json, 'id');
    final rawThreats = json['threats'];
    if (rawThreats is! List) {
      throw CropCatalogException('Crop "$id" has no "threats" list.');
    }

    final threats = <Threat>[];
    final seenThreatIds = <String>{};
    for (final raw in rawThreats) {
      if (raw is! Map<String, dynamic>) {
        throw CropCatalogException('A threat of "$id" is not an object.');
      }
      final threat = threatFromJson(raw, cropId: id);
      if (!seenThreatIds.add(threat.id)) {
        throw CropCatalogException(
          'Crop "$id" defines threat "${threat.id}" twice.',
        );
      }
      threats.add(threat);
    }

    final source = json['source'];

    return Crop(
      id: id,
      name: _nonEmptyString(json, 'name'),
      season: seasonFromJson(_object(json, 'season'), cropId: id),
      threats: threats,
      source: source is String ? CropSource.byName(source) : CropSource.builtIn,
      authorId: json['authorId'] as String?,
    );
  }

  static Threat threatFromJson(
    Map<String, dynamic> json, {
    required String cropId,
  }) {
    final id = _nonEmptyString(json, 'id');

    final typeName = json['type'];
    if (typeName is! String) {
      throw CropCatalogException('Threat "$id" has no "type".');
    }
    final type = ThreatType.byName(typeName);
    if (type == null) {
      throw CropCatalogException(
        'Threat "$id" has unknown type "$typeName"; '
        'expected one of ${ThreatType.values.map((t) => t.name).join(', ')}.',
      );
    }

    final rawRules = json['rules'];
    if (rawRules is! List || rawRules.isEmpty) {
      throw CropCatalogException(
        'Threat "$id" of crop "$cropId" has no rules, so it could never be '
        'reported.',
      );
    }

    final List<Rule> rules;
    try {
      rules = ConditionCodec.rulesFromJson(rawRules);
    } on RuleFormatException catch (error) {
      throw CropCatalogException(
        'Threat "$id" of crop "$cropId": ${error.message}',
      );
    }

    // A rule filed under one threat but naming another would simply never be
    // attributed, which reads to a grower as "no problem here".
    for (final rule in rules) {
      if (rule.threatId != id) {
        throw CropCatalogException(
          'Rule "${rule.id}" sits under threat "$id" but names '
          '"${rule.threatId}".',
        );
      }
    }

    return Threat(
      id: id,
      type: type,
      name: _nonEmptyString(json, 'name'),
      description: json['description'] as String?,
      prevention: _stringList(json, 'prevention'),
      response: _stringList(json, 'response'),
      rules: rules,
    );
  }

  static GrowingSeason seasonFromJson(
    Map<String, dynamic> json, {
    required String cropId,
  }) {
    final from = json['fromMonth'];
    final to = json['toMonth'];

    if (from is! num || from < 1 || from > 12) {
      throw CropCatalogException(
        'Crop "$cropId" has an out-of-range "fromMonth": $from.',
      );
    }
    if (to is! num || to < 1 || to > 12) {
      throw CropCatalogException(
        'Crop "$cropId" has an out-of-range "toMonth": $to.',
      );
    }

    return GrowingSeason(fromMonth: from.toInt(), toMonth: to.toInt());
  }

  static Map<String, dynamic> catalogToJson(List<Crop> crops) => {
        'version': version,
        'crops': crops.map((c) => c.toJson()).toList(),
      };

  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw CropCatalogException('Expected an object at "$key".');
    }
    return value;
  }

  static String _nonEmptyString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw CropCatalogException('Expected a non-empty string at "$key".');
    }
    return value;
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List) {
      throw CropCatalogException('Expected a list of strings at "$key".');
    }
    return value.map((entry) {
      if (entry is! String) {
        throw CropCatalogException('"$key" contains something that is not text.');
      }
      return entry;
    }).toList();
  }
}
