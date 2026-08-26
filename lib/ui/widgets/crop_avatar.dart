import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/theme.dart';
import 'crop_artwork.dart';

/// A crop's badge: a soft emerald tile with the crop's artwork on it.
///
/// The tile itself is drawn here rather than baked into each SVG, so the SVG
/// and emoji crops sit on an identical background — the web app builds the
/// badge inside every generated SVG, which would drift the moment one of them
/// is edited.
class CropAvatar extends StatelessWidget {
  const CropAvatar({
    required this.cropId,
    this.size = 48,
    this.semanticLabel,
    super.key,
  });

  final String cropId;

  /// Edge length of the square badge.
  final double size;

  /// Announced by screen readers; usually the crop's localized name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = CropArtwork.forCrop(cropId);

    // Proportions taken from the web app's 96px badge.
    final radius = size * (24 / 96);
    final discDiameter = size * (68 / 96);

    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.emerald[50], AppColors.emerald[100]],
            ),
          ),
          child: Center(
            child: SizedBox.square(
              dimension: discDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _Glyph(glyph: glyph, badgeSize: size),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.glyph, required this.badgeSize});

  final CropGlyph glyph;

  /// Edge length of the whole badge, which both glyph kinds are sized against.
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return switch (glyph) {
      // The extracted artwork is drawn against a 96px viewBox that already
      // insets it, so it is rendered at the badge's full size and lands inside
      // the disc on its own.
      CropSvgGlyph(:final assetPath) => SvgPicture.asset(
          assetPath,
          width: badgeSize,
          height: badgeSize,
          fit: BoxFit.contain,
        ),
      // Emoji have no such inset, so they take the web app's 47/96 glyph size.
      CropEmojiGlyph(:final emoji) => Text(
          emoji,
          style: TextStyle(fontSize: badgeSize * (47 / 96), height: 1),
          textAlign: TextAlign.center,
        ),
    };
  }
}
