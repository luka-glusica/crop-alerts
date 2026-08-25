import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/data/local_crop_repository.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/threat.dart';
import 'package:crop_alerts/features/rules/domain/rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

List<Crop> readCatalog(String language) {
  final raw =
      File('${LocalCropRepository.assetFolder}/crops_$language.json')
          .readAsStringSync();
  return CropCatalogCodec.catalogFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
}

void main() {
  late List<Crop> sr;
  late List<Crop> en;

  setUpAll(() {
    sr = readCatalog('sr');
    en = readCatalog('en');
  });

  group('the shipped catalogue loads', () {
    test('every language parses and validates', () {
      // The codec rejects misfiled rules, unknown threat types, bad months and
      // empty rule lists, so simply getting here is the real assertion.
      expect(sr, isNotEmpty);
      expect(en, isNotEmpty);
    });

    test('holds the five seed crops', () {
      expect(
        sr.map((c) => c.id).toList(),
        ['paradajz', 'krompir', 'krastavac', 'kupus', 'luk'],
      );
    });

    test('every asset referenced by the repository exists', () {
      for (final language in LocalCropRepository.availableLanguages) {
        final path = '${LocalCropRepository.assetFolder}/crops_$language.json';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('the content folder is declared in pubspec', () {
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
      final assets =
          ((pubspec['flutter'] as Map)['assets'] as List).cast<String>();

      expect(
        assets.any((a) => a == '${LocalCropRepository.assetFolder}/'),
        isTrue,
      );
    });
  });

  group('the two languages stay in step', () {
    test('same crops, in the same order', () {
      expect(en.map((c) => c.id).toList(), sr.map((c) => c.id).toList());
    });

    test('same seasons', () {
      for (var i = 0; i < sr.length; i++) {
        expect(en[i].season, sr[i].season, reason: sr[i].id);
      }
    });

    test('same threats, of the same kind, in the same order', () {
      for (var i = 0; i < sr.length; i++) {
        expect(
          en[i].threats.map((t) => t.id).toList(),
          sr[i].threats.map((t) => t.id).toList(),
          reason: sr[i].id,
        );
        expect(
          en[i].threats.map((t) => t.type).toList(),
          sr[i].threats.map((t) => t.type).toList(),
          reason: sr[i].id,
        );
      }
    });

    test('identical rules — a translation must never change behaviour', () {
      for (var i = 0; i < sr.length; i++) {
        expect(
          jsonEncode(en[i].rules.map((r) => r.toJson()).toList()),
          jsonEncode(sr[i].rules.map((r) => r.toJson()).toList()),
          reason: '${sr[i].id} evaluates differently in English',
        );
      }
    });

    test('same number of prevention and response steps', () {
      for (var i = 0; i < sr.length; i++) {
        for (var j = 0; j < sr[i].threats.length; j++) {
          expect(
            en[i].threats[j].prevention.length,
            sr[i].threats[j].prevention.length,
            reason: '${sr[i].id}/${sr[i].threats[j].id} prevention',
          );
          expect(
            en[i].threats[j].response.length,
            sr[i].threats[j].response.length,
            reason: '${sr[i].id}/${sr[i].threats[j].id} response',
          );
        }
      }
    });

    test('nothing is left untranslated', () {
      for (var i = 0; i < sr.length; i++) {
        expect(en[i].name, isNotEmpty);
        for (var j = 0; j < sr[i].threats.length; j++) {
          final srThreat = sr[i].threats[j];
          final enThreat = en[i].threats[j];

          expect(enThreat.name, isNotEmpty);
          expect(enThreat.description, isNotNull);
          expect(
            enThreat.description,
            isNot(srThreat.description),
            reason: '${sr[i].id}/${srThreat.id} description was not translated',
          );
          for (var k = 0; k < srThreat.prevention.length; k++) {
            expect(
              enThreat.prevention[k],
              isNot(srThreat.prevention[k]),
              reason: '${sr[i].id}/${srThreat.id} prevention $k',
            );
          }
        }
      }
    });
  });

  group('every crop is complete', () {
    test('has a name, a season and at least one threat', () {
      for (final crop in sr) {
        expect(crop.name.trim(), isNotEmpty, reason: crop.id);
        expect(crop.season.length, greaterThan(0), reason: crop.id);
        expect(crop.threats, isNotEmpty, reason: crop.id);
      }
    });

    test('covers diseases, pests and other problems', () {
      // The whole point of widening the web version's model.
      for (final crop in sr) {
        expect(
          crop.threatsOfType(ThreatType.fungalDisease),
          isNotEmpty,
          reason: '${crop.id} has no disease',
        );
        expect(
          crop.threatsOfType(ThreatType.pest),
          isNotEmpty,
          reason: '${crop.id} has no pest',
        );
        expect(
          crop.threatsOfType(ThreatType.other),
          isNotEmpty,
          reason: '${crop.id} has no other problem',
        );
      }
    });

    test('every threat carries advice a grower can act on', () {
      for (final crop in sr) {
        for (final threat in crop.threats) {
          expect(
            threat.prevention,
            isNotEmpty,
            reason: '${crop.id}/${threat.id} has no prevention',
          );
          expect(
            threat.response,
            isNotEmpty,
            reason: '${crop.id}/${threat.id} has no response',
          );
          expect(
            threat.description?.trim(),
            isNotEmpty,
            reason: '${crop.id}/${threat.id} has no description',
          );
        }
      }
    });

    test('every threat can actually be reported', () {
      for (final crop in sr) {
        for (final threat in crop.threats) {
          expect(threat.rules, isNotEmpty, reason: '${crop.id}/${threat.id}');
          for (final rule in threat.rules) {
            expect(rule.threatId, threat.id);
          }
        }
      }
    });

    test('rule ids are unique across the whole catalogue', () {
      final ids = <String>[];
      for (final crop in sr) {
        ids.addAll(crop.rules.map((r) => r.id));
      }

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('rule ids name the crop and threat they belong to', () {
      for (final crop in sr) {
        for (final threat in crop.threats) {
          for (final rule in threat.rules) {
            expect(rule.id, startsWith('${crop.id}.${threat.id}.'));
          }
        }
      }
    });

    test('every crop has artwork', () {
      // CropAvatar falls back to a seedling, but a shipped crop should not
      // need the fallback.
      const withArtwork = {
        'paradajz', 'krastavac', 'grasak', 'boranija', 'tikvica', 'lubenica',
        'luk', 'praziluk', 'beli-luk', 'zelena-salata', 'kupus',
        'prokelj-kelj', 'pasulj', 'krompir', 'batat', 'sargarepa', 'spanac',
        'blitva', //
      };

      for (final crop in sr) {
        expect(withArtwork, contains(crop.id));
      }
    });

    test('everything ships as built-in', () {
      for (final crop in sr) {
        expect(crop.source, CropSource.builtIn);
        expect(crop.authorId, isNull);
        for (final rule in crop.rules) {
          expect(rule.source, RuleSource.builtIn);
        }
      }
    });
  });

  group('seasons are plausible for Serbia', () {
    test('each crop is out of the ground for part of the year', () {
      // A season covering all twelve months would silence the dormancy logic
      // entirely, which is usually a sign someone did not fill it in.
      for (final crop in sr) {
        expect(
          crop.season.length,
          lessThan(12),
          reason: '${crop.id} is in season all year',
        );
      }
    });

    test('nothing is in season in deep winter', () {
      for (final crop in sr) {
        expect(
          crop.season.contains(1),
          isFalse,
          reason: '${crop.id} claims to grow outdoors in January',
        );
      }
    });

    test('every crop is in season in July', () {
      for (final crop in sr) {
        expect(crop.season.contains(7), isTrue, reason: crop.id);
      }
    });
  });
}
