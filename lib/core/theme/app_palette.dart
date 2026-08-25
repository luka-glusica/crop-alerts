import 'package:flutter/material.dart';

import 'tokens.dart';

/// The three colours a risk state needs: a filled background, readable text on
/// top of it, and a saturated dot for compact indicators.
@immutable
class RiskColors {
  const RiskColors({
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color accent;

  RiskColors lerpTo(RiskColors other, double t) {
    return RiskColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// Semantic colours, resolved per theme brightness.
///
/// Widgets should read these rather than reaching into [AppColors] directly, so
/// that dark mode is a matter of swapping the extension rather than auditing
/// every call site.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnBrand,
    required this.brand,
    required this.brandMuted,
    required this.riskHigh,
    required this.riskModerate,
    required this.riskLow,
    required this.dormant,
  });

  /// Page background behind everything.
  final Color canvas;

  /// Card and sheet background.
  final Color surface;

  /// A tinted panel inside a card, e.g. the coordinate form on the web app.
  final Color surfaceMuted;

  /// A card that should read as sitting above its neighbours.
  final Color surfaceRaised;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Text drawn on top of [brand].
  final Color textOnBrand;

  final Color brand;
  final Color brandMuted;

  final RiskColors riskHigh;
  final RiskColors riskModerate;
  final RiskColors riskLow;

  /// Used for crops that are outside their growing season.
  final RiskColors dormant;

  /// Light theme, matching the web app: an off-white green canvas, white cards,
  /// emerald borders and emerald-950 headings.
  static const AppPalette light = AppPalette(
    canvas: AppColors.canvasLight,
    surface: AppColors.white,
    surfaceMuted: Color(0xFFECFDF5),
    surfaceRaised: AppColors.white,
    border: Color(0xFFA7F3D0),
    borderStrong: Color(0xFF6EE7B7),
    textPrimary: Color(0xFF022C22),
    textSecondary: Color(0xFF065F46),
    textMuted: Color(0xFF57534E),
    textOnBrand: AppColors.white,
    brand: Color(0xFF047857),
    brandMuted: Color(0xFFD1FAE5),
    riskHigh: RiskColors(
      background: Color(0xFFFEE2E2),
      foreground: Color(0xFF991B1B),
      accent: Color(0xFFEF4444),
    ),
    riskModerate: RiskColors(
      background: Color(0xFFFEF3C7),
      foreground: Color(0xFF92400E),
      accent: Color(0xFFF59E0B),
    ),
    riskLow: RiskColors(
      background: Color(0xFFD1FAE5),
      foreground: Color(0xFF065F46),
      accent: Color(0xFF10B981),
    ),
    dormant: RiskColors(
      background: Color(0xFFE7E5E4),
      foreground: Color(0xFF57534E),
      accent: Color(0xFFA8A29E),
    ),
  );

  /// Dark theme. Risk backgrounds become deep tints with light text, keeping the
  /// same hue relationships so the states stay recognisable.
  static const AppPalette dark = AppPalette(
    canvas: Color(0xFF0C0A09),
    surface: Color(0xFF1C1917),
    surfaceMuted: Color(0xFF022C22),
    surfaceRaised: Color(0xFF292524),
    border: Color(0xFF064E3B),
    borderStrong: Color(0xFF065F46),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFFA7F3D0),
    textMuted: Color(0xFFA8A29E),
    textOnBrand: Color(0xFF022C22),
    brand: Color(0xFF34D399),
    brandMuted: Color(0xFF064E3B),
    riskHigh: RiskColors(
      background: Color(0xFF450A0A),
      foreground: Color(0xFFFECACA),
      accent: Color(0xFFF87171),
    ),
    riskModerate: RiskColors(
      background: Color(0xFF451A03),
      foreground: Color(0xFFFDE68A),
      accent: Color(0xFFFBBF24),
    ),
    riskLow: RiskColors(
      background: Color(0xFF064E3B),
      foreground: Color(0xFFA7F3D0),
      accent: Color(0xFF34D399),
    ),
    dormant: RiskColors(
      background: Color(0xFF292524),
      foreground: Color(0xFFD6D3D1),
      accent: Color(0xFF78716C),
    ),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnBrand,
    Color? brand,
    Color? brandMuted,
    RiskColors? riskHigh,
    RiskColors? riskModerate,
    RiskColors? riskLow,
    RiskColors? dormant,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      brand: brand ?? this.brand,
      brandMuted: brandMuted ?? this.brandMuted,
      riskHigh: riskHigh ?? this.riskHigh,
      riskModerate: riskModerate ?? this.riskModerate,
      riskLow: riskLow ?? this.riskLow,
      dormant: dormant ?? this.dormant,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      riskHigh: riskHigh.lerpTo(other.riskHigh, t),
      riskModerate: riskModerate.lerpTo(other.riskModerate, t),
      riskLow: riskLow.lerpTo(other.riskLow, t),
      dormant: dormant.lerpTo(other.dormant, t),
    );
  }
}

/// `Theme.of(context).palette`-style access to [AppPalette].
extension AppPaletteX on BuildContext {
  /// The semantic palette for the current theme.
  ///
  /// Falls back to [AppPalette.light] rather than throwing, so a widget can be
  /// pumped in a bare `MaterialApp` in tests without extra setup.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
