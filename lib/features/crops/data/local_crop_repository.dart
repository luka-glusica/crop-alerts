import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

import '../domain/crop.dart';
import '../domain/crop_repository.dart';
import 'crop_catalog_codec.dart';

/// Reads the crop catalogue from the localized JSON assets bundled with the app.
///
/// Crop and advice text lives in content files rather than in the ARB
/// localizations because Flutter's generated localizations are typed getters:
/// a dynamic key like `crop_paradajz_name` cannot be looked up at runtime. The
/// file shape is also exactly what a server would return for community
/// contributions, so the remote implementation is a swap rather than a rewrite.
class LocalCropRepository implements CropRepository {
  LocalCropRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetFolder = 'assets/content';

  /// The language the app falls back to, matching the primary locale.
  static const String fallbackLanguage = 'sr';

  /// Languages a catalogue exists for.
  static const Set<String> availableLanguages = {'sr', 'en'};

  final AssetBundle _bundle;

  /// Parsed catalogues, keyed by language. The content is bundled and cannot
  /// change while the app runs, so parsing it once is enough.
  final Map<String, List<Crop>> _cache = {};

  /// The asset path for [locale].
  static String assetPathFor(Locale locale) {
    final language = availableLanguages.contains(locale.languageCode)
        ? locale.languageCode
        : fallbackLanguage;
    return '$assetFolder/crops_$language.json';
  }

  @override
  Future<List<Crop>> load(Locale locale) async {
    final path = assetPathFor(locale);

    final cached = _cache[path];
    if (cached != null) return cached;

    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw CropCatalogException('$path is not a catalogue object.');
    }

    final crops = CropCatalogCodec.catalogFromJson(decoded);
    _cache[path] = crops;
    return crops;
  }

  /// Drops the parsed catalogues, so the next load parses again.
  ///
  /// Note that `rootBundle` caches asset bytes itself, so this re-parses rather
  /// than re-reading from disk — which is all that is wanted for content that
  /// ships with the build and cannot change while it runs.
  void invalidate() => _cache.clear();
}
