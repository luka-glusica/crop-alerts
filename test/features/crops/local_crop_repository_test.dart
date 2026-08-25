import 'dart:convert';
import 'dart:ui';

import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/features/crops/data/crop_catalog_codec.dart';
import 'package:crop_alerts/features/crops/data/local_crop_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned catalogue assets and counts how often each is read.
///
/// Deliberately extends the non-caching [AssetBundle] rather than
/// [CachingAssetBundle], so the counts measure the repository's own caching
/// instead of the bundle's.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.assets);

  final Map<String, String> assets;
  final Map<String, int> loads = {};

  @override
  Future<ByteData> load(String key) async {
    loads[key] = (loads[key] ?? 0) + 1;
    final content = assets[key];
    if (content == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    final bytes = utf8.encode(content);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

String catalogJson(String cropId, String cropName) => jsonEncode({
      'version': CropCatalogCodec.version,
      'crops': [
        {
          'id': cropId,
          'name': cropName,
          'season': {'fromMonth': 3, 'toMonth': 9},
          'threats': [
            {
              'id': 'plamenjaca',
              'type': 'fungalDisease',
              'name': 'Plamenjača',
              'prevention': <String>[],
              'response': <String>[],
              'rules': [
                {
                  'id': 'r1',
                  'threatId': 'plamenjaca',
                  'condition': {
                    'type': 'metricThreshold',
                    'metric': 'maxHumidity',
                    'comparator': 'greaterThan',
                    'value': 90,
                  },
                },
              ],
            },
          ],
        },
      ],
    });

void main() {
  late _FakeBundle bundle;
  late LocalCropRepository repository;

  setUp(() {
    bundle = _FakeBundle({
      'assets/content/crops_sr.json': catalogJson('krompir', 'Krompir'),
      'assets/content/crops_en.json': catalogJson('krompir', 'Potato'),
    });
    repository = LocalCropRepository(bundle: bundle);
  });

  group('choosing a catalogue', () {
    test('loads Serbian for a Serbian locale', () async {
      final crops = await repository.load(LocaleController.serbianLatin);

      expect(crops.single.name, 'Krompir');
    });

    test('loads English for an English locale', () async {
      final crops = await repository.load(LocaleController.english);

      expect(crops.single.name, 'Potato');
    });

    test('ignores the script and country subtags', () {
      expect(
        LocalCropRepository.assetPathFor(
          const Locale.fromSubtags(
            languageCode: 'sr',
            scriptCode: 'Latn',
            countryCode: 'RS',
          ),
        ),
        'assets/content/crops_sr.json',
      );
    });

    test('falls back to Serbian for a language with no catalogue', () async {
      final crops = await repository.load(const Locale('de'));

      expect(crops.single.name, 'Krompir');
      expect(
        LocalCropRepository.assetPathFor(const Locale('de')),
        'assets/content/crops_sr.json',
      );
    });
  });

  group('caching', () {
    test('reads each asset once however often it is asked for', () async {
      await repository.load(LocaleController.serbianLatin);
      await repository.load(LocaleController.serbianLatin);
      await repository.load(const Locale('sr'));

      expect(bundle.loads['assets/content/crops_sr.json'], 1);
    });

    test('caches each language separately', () async {
      await repository.load(LocaleController.serbianLatin);
      await repository.load(LocaleController.english);

      expect(bundle.loads['assets/content/crops_sr.json'], 1);
      expect(bundle.loads['assets/content/crops_en.json'], 1);
    });

    test('invalidate forces a re-read', () async {
      await repository.load(LocaleController.serbianLatin);
      repository.invalidate();
      await repository.load(LocaleController.serbianLatin);

      expect(bundle.loads['assets/content/crops_sr.json'], 2);
    });
  });

  group('bad content', () {
    test('a catalogue that is not an object is rejected', () async {
      final broken = LocalCropRepository(
        bundle: _FakeBundle({'assets/content/crops_sr.json': '[]'}),
      );

      expect(
        () => broken.load(LocaleController.serbianLatin),
        throwsA(isA<CropCatalogException>()),
      );
    });

    test('a validation failure surfaces rather than loading nothing', () async {
      final broken = LocalCropRepository(
        bundle: _FakeBundle({
          'assets/content/crops_sr.json': jsonEncode({
            'version': 1,
            'crops': [
              {
                'id': 'krompir',
                'name': 'Krompir',
                'season': {'fromMonth': 3, 'toMonth': 9},
                'threats': [
                  {
                    'id': 'plamenjaca',
                    'type': 'fungalDisease',
                    'name': 'Plamenjača',
                    'rules': [
                      {
                        'id': 'r1',
                        'threatId': 'pogresna',
                        'condition': {
                          'type': 'metricThreshold',
                          'metric': 'maxHumidity',
                          'comparator': 'greaterThan',
                          'value': 90,
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          }),
        }),
      );

      expect(
        () => broken.load(LocaleController.serbianLatin),
        throwsA(isA<CropCatalogException>()),
      );
    });

    test('malformed JSON surfaces as a format error', () async {
      final broken = LocalCropRepository(
        bundle: _FakeBundle({'assets/content/crops_sr.json': '{"version": '}),
      );

      expect(
        () => broken.load(LocaleController.serbianLatin),
        throwsA(isA<FormatException>()),
      );
    });

    test('a broken load is not cached as success', () async {
      final bundle = _FakeBundle({'assets/content/crops_sr.json': '[]'});
      final broken = LocalCropRepository(bundle: bundle);

      await expectLater(
        broken.load(LocaleController.serbianLatin),
        throwsA(isA<CropCatalogException>()),
      );
      await expectLater(
        broken.load(LocaleController.serbianLatin),
        throwsA(isA<CropCatalogException>()),
      );
    });
  });
}
