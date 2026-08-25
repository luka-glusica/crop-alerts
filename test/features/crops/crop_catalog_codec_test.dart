import 'dart:convert';

import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/domain/crop.dart';
import 'package:crop_alerts/features/crops/domain/threat.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> humidityRule(String id, String threatId) => {
      'id': id,
      'threatId': threatId,
      'condition': {
        'type': 'metricThreshold',
        'metric': 'maxHumidity',
        'comparator': 'greaterThan',
        'value': 90,
      },
    };

Map<String, dynamic> threat({
  String id = 'plamenjaca',
  String type = 'fungalDisease',
  List<Map<String, dynamic>>? rules,
}) =>
    {
      'id': id,
      'type': type,
      'name': 'Plamenjača',
      'description': 'Gljivično oboljenje lista i krtole.',
      'prevention': ['Sertifikovano seme.'],
      'response': ['Prskanje bakarnim preparatima.'],
      'rules': rules ?? [humidityRule('$id.vlaznost', id)],
    };

Map<String, dynamic> crop({
  String id = 'krompir',
  List<Map<String, dynamic>>? threats,
  Map<String, dynamic>? season,
}) =>
    {
      'id': id,
      'name': 'Krompir',
      'season': season ?? {'fromMonth': 3, 'toMonth': 9},
      'threats': threats ?? [threat()],
    };

Map<String, dynamic> catalog({List<Map<String, dynamic>>? crops, int version = 1}) =>
    {
      'version': version,
      'crops': crops ?? [crop()],
    };

void main() {
  group('reading a catalogue', () {
    test('parses a crop with its season, threats and rules', () {
      final crops = CropCatalogCodec.catalogFromJson(catalog());

      final potato = crops.single;
      expect(potato.id, 'krompir');
      expect(potato.name, 'Krompir');
      expect(potato.season.fromMonth, 3);
      expect(potato.season.toMonth, 9);
      expect(potato.source, CropSource.builtIn);

      final blight = potato.threats.single;
      expect(blight.id, 'plamenjaca');
      expect(blight.type, ThreatType.fungalDisease);
      expect(blight.prevention, hasLength(1));
      expect(blight.response, hasLength(1));
      expect(blight.rules, hasLength(1));
    });

    test('collects rules from every threat', () {
      final crops = CropCatalogCodec.catalogFromJson(
        catalog(crops: [
          crop(threats: [
            threat(),
            threat(id: 'lisne-vasi', type: 'pest', rules: [
              humidityRule('lisne-vasi.vlaznost', 'lisne-vasi'),
            ]),
          ]),
        ]),
      );

      expect(crops.single.rules, hasLength(2));
      expect(
        crops.single.rules.map((r) => r.threatId),
        ['plamenjaca', 'lisne-vasi'],
      );
    });

    test('groups threats by kind', () {
      final crops = CropCatalogCodec.catalogFromJson(
        catalog(crops: [
          crop(threats: [
            threat(),
            threat(id: 'lisne-vasi', type: 'pest', rules: [
              humidityRule('lisne-vasi.vlaznost', 'lisne-vasi'),
            ]),
            threat(id: 'pucanje-ploda', type: 'other', rules: [
              humidityRule('pucanje.vlaznost', 'pucanje-ploda'),
            ]),
          ]),
        ]),
      );

      final potato = crops.single;
      expect(potato.threatsOfType(ThreatType.fungalDisease), hasLength(1));
      expect(potato.threatsOfType(ThreatType.pest), hasLength(1));
      expect(potato.threatsOfType(ThreatType.other), hasLength(1));
    });

    test('resolves a threat by id', () {
      final potato = CropCatalogCodec.catalogFromJson(catalog()).single;

      expect(potato.threatById('plamenjaca')?.name, 'Plamenjača');
      expect(potato.threatById('nepostojeca'), isNull);
    });

    test('reads community metadata', () {
      final crops = CropCatalogCodec.catalogFromJson(
        catalog(crops: [
          {...crop(), 'source': 'community', 'authorId': 'user-7'},
        ]),
      );

      expect(crops.single.source, CropSource.community);
      expect(crops.single.authorId, 'user-7');
    });

    test('prevention and response default to empty rather than failing', () {
      final threatJson = threat()..remove('prevention');
      threatJson.remove('response');

      final crops = CropCatalogCodec.catalogFromJson(
        catalog(crops: [crop(threats: [threatJson])]),
      );

      expect(crops.single.threats.single.prevention, isEmpty);
      expect(crops.single.threats.single.response, isEmpty);
    });

    test('round-trips through JSON', () {
      final original = CropCatalogCodec.catalogFromJson(
        catalog(crops: [
          crop(threats: [
            threat(),
            threat(id: 'lisne-vasi', type: 'pest', rules: [
              humidityRule('lisne-vasi.vlaznost', 'lisne-vasi'),
            ]),
          ]),
        ]),
      );

      final encoded = jsonEncode(CropCatalogCodec.catalogToJson(original));
      final restored = CropCatalogCodec.catalogFromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(
        jsonEncode(CropCatalogCodec.catalogToJson(restored)),
        encoded,
      );
      expect(restored.single.rules, hasLength(original.single.rules.length));
    });
  });

  group('content bugs are rejected at load time', () {
    void expectRejected(
      Map<String, dynamic> json, {
      required String because,
      String? mentioning,
    }) {
      expect(
        () => CropCatalogCodec.catalogFromJson(json),
        throwsA(
          isA<CropCatalogException>().having(
            (e) => e.message,
            'message',
            mentioning == null ? isNotEmpty : contains(mentioning),
          ),
        ),
        reason: because,
      );
    }

    test('a rule naming a threat other than the one it sits under', () {
      // This is the dangerous one: the rule would evaluate, score nothing that
      // resolves, and read to a grower as "no problem here".
      expectRejected(
        catalog(crops: [
          crop(threats: [
            threat(rules: [humidityRule('r1', 'pepelnica')]),
          ]),
        ]),
        because: 'a misfiled rule is silent, not loud',
        mentioning: 'names',
      );
    });

    test('a threat with no rules at all', () {
      expectRejected(
        catalog(crops: [
          crop(threats: [
            {...threat(), 'rules': <dynamic>[]},
          ]),
        ]),
        because: 'a threat with no rules could never be reported',
      );
    });

    test('duplicate crop ids', () {
      expectRejected(
        catalog(crops: [crop(), crop()]),
        because: 'artwork and lookups key on crop id',
        mentioning: 'Duplicate',
      );
    });

    test('a crop defining the same threat twice', () {
      expectRejected(
        catalog(crops: [
          crop(threats: [threat(), threat()]),
        ]),
        because: 'threatById would silently pick one',
      );
    });

    test('an unknown threat type', () {
      expectRejected(
        catalog(crops: [
          crop(threats: [
            {...threat(), 'type': 'weedPressure'},
          ]),
        ]),
        because: 'the UI groups on the known kinds',
        mentioning: 'weedPressure',
      );
    });

    test('a month outside 1–12', () {
      expectRejected(
        catalog(crops: [
          crop(season: {'fromMonth': 0, 'toMonth': 9}),
        ]),
        because: 'month 0 would silently never match',
      );
      expectRejected(
        catalog(crops: [
          crop(season: {'fromMonth': 3, 'toMonth': 13}),
        ]),
        because: 'month 13 would silently never match',
      );
    });

    test('a missing season', () {
      final without = crop()..remove('season');
      expectRejected(
        catalog(crops: [without]),
        because: 'without a season the crop can never be gated',
      );
    });

    test('a missing or blank name', () {
      expectRejected(
        catalog(crops: [
          {...crop(), 'name': '   '},
        ]),
        because: 'a blank name renders as an empty card',
      );
    });

    test('a malformed rule condition', () {
      expectRejected(
        catalog(crops: [
          crop(threats: [
            threat(rules: [
              {
                'id': 'r1',
                'threatId': 'plamenjaca',
                'condition': {'type': 'leafWetnessHours'},
              },
            ]),
          ]),
        ]),
        because: 'an unknown condition type must not load',
        mentioning: 'leafWetnessHours',
      );
    });

    test('the error names the crop and threat it came from', () {
      expect(
        () => CropCatalogCodec.catalogFromJson(
          catalog(crops: [
            crop(threats: [
              threat(rules: [
                {
                  'id': 'r1',
                  'threatId': 'plamenjaca',
                  'condition': {'type': 'nonsense'},
                },
              ]),
            ]),
          ]),
        ),
        throwsA(
          isA<CropCatalogException>()
              .having((e) => e.message, 'message', contains('plamenjaca'))
              .having((e) => e.message, 'message', contains('krompir')),
        ),
      );
    });

    test('a catalogue with no version', () {
      expectRejected(
        {'crops': <dynamic>[]},
        because: 'the format needs to be identifiable',
      );
    });

    test('a catalogue from a newer format', () {
      expectRejected(
        catalog(version: 99),
        because: 'a future shape must not be half-read',
        mentioning: 'version',
      );
    });

    test('a catalogue with no crops list', () {
      expectRejected(
        {'version': 1},
        because: 'nothing to read',
      );
    });
  });
}
