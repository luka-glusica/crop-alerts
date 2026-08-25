import 'package:flutter/foundation.dart';

/// The glyph drawn inside a crop avatar.
///
/// The web version of this app draws six crops as hand-made SVG and falls back
/// to an emoji for the rest; this keeps that split explicit rather than hiding
/// it behind a single asset lookup that would silently render nothing.
@immutable
sealed class CropGlyph {
  const CropGlyph();
}

/// Vector artwork bundled under `assets/crops/`.
class CropSvgGlyph extends CropGlyph {
  const CropSvgGlyph(this.assetPath);

  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is CropSvgGlyph && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;
}

/// A single emoji, rendered as text.
class CropEmojiGlyph extends CropGlyph {
  const CropEmojiGlyph(this.emoji);

  final String emoji;

  @override
  bool operator ==(Object other) =>
      other is CropEmojiGlyph && other.emoji == emoji;

  @override
  int get hashCode => emoji.hashCode;
}

/// Maps a crop id to the artwork that represents it.
abstract final class CropArtwork {
  /// Crops with hand-drawn artwork extracted from the web app.
  static const Map<String, String> _svgAssets = {
    'boranija': 'assets/crops/boranija.svg',
    'kupus': 'assets/crops/kupus.svg',
    'praziluk': 'assets/crops/praziluk.svg',
    'prokelj-kelj': 'assets/crops/prokelj-kelj.svg',
    'tikvica': 'assets/crops/tikvica.svg',
    'zelena-salata': 'assets/crops/zelena-salata.svg',
  };

  /// Crops the web app represents with an emoji.
  static const Map<String, String> _emoji = {
    'paradajz': '🍅',
    'krastavac': '🥒',
    'grasak': '🫛',
    'lubenica': '🍉',
    'luk': '🧅',
    'beli-luk': '🧄',
    'pasulj': '🫘',
    'krompir': '🥔',
    'batat': '🍠',
    'sargarepa': '🥕',
    'spanac': '🥬',
    'blitva': '🥬',
  };

  /// Used for a crop with no artwork of its own — a community-contributed one,
  /// for instance.
  static const CropGlyph fallback = CropEmojiGlyph('🌱');

  /// The glyph for [cropId], or [fallback] when the crop is unknown.
  static CropGlyph forCrop(String cropId) {
    final asset = _svgAssets[cropId];
    if (asset != null) return CropSvgGlyph(asset);

    final emoji = _emoji[cropId];
    if (emoji != null) return CropEmojiGlyph(emoji);

    return fallback;
  }

  /// Every crop id that has artwork, for tests and tooling.
  static Set<String> get knownCropIds => {..._svgAssets.keys, ..._emoji.keys};

  /// Every bundled SVG path, for the asset-existence test.
  static Iterable<String> get svgAssetPaths => _svgAssets.values;
}
