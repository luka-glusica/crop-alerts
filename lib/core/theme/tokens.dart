import 'package:flutter/widgets.dart';

import 'color_scale.dart';

/// Colour ramps, taken from the Tailwind palette the web version of this app
/// uses so the two stay visually consistent.
abstract final class AppColors {
  /// Primary brand ramp. The logo's highlights are [emerald] 50/100/200.
  static const ColorScale emerald = ColorScale(
    shade50: Color(0xFFECFDF5),
    shade100: Color(0xFFD1FAE5),
    shade200: Color(0xFFA7F3D0),
    shade300: Color(0xFF6EE7B7),
    shade400: Color(0xFF34D399),
    shade500: Color(0xFF10B981),
    shade600: Color(0xFF059669),
    shade700: Color(0xFF047857),
    shade800: Color(0xFF065F46),
    shade900: Color(0xFF064E3B),
    shade950: Color(0xFF022C22),
  );

  /// Secondary ramp, used for foliage accents. The logo's leaves are 700/800.
  static const ColorScale green = ColorScale(
    shade50: Color(0xFFF0FDF4),
    shade100: Color(0xFFDCFCE7),
    shade200: Color(0xFFBBF7D0),
    shade300: Color(0xFF86EFAC),
    shade400: Color(0xFF4ADE80),
    shade500: Color(0xFF22C55E),
    shade600: Color(0xFF16A34A),
    shade700: Color(0xFF15803D),
    shade800: Color(0xFF166534),
    shade900: Color(0xFF14532D),
    shade950: Color(0xFF052E16),
  );

  /// Moderate-risk ramp.
  static const ColorScale amber = ColorScale(
    shade50: Color(0xFFFFFBEB),
    shade100: Color(0xFFFEF3C7),
    shade200: Color(0xFFFDE68A),
    shade300: Color(0xFFFCD34D),
    shade400: Color(0xFFFBBF24),
    shade500: Color(0xFFF59E0B),
    shade600: Color(0xFFD97706),
    shade700: Color(0xFFB45309),
    shade800: Color(0xFF92400E),
    shade900: Color(0xFF78350F),
    shade950: Color(0xFF451A03),
  );

  /// High-risk ramp.
  static const ColorScale red = ColorScale(
    shade50: Color(0xFFFEF2F2),
    shade100: Color(0xFFFEE2E2),
    shade200: Color(0xFFFECACA),
    shade300: Color(0xFFFCA5A5),
    shade400: Color(0xFFF87171),
    shade500: Color(0xFFEF4444),
    shade600: Color(0xFFDC2626),
    shade700: Color(0xFFB91C1C),
    shade800: Color(0xFF991B1B),
    shade900: Color(0xFF7F1D1D),
    shade950: Color(0xFF450A0A),
  );

  /// Warm neutral ramp. Reads better against green than a blue-grey would.
  static const ColorScale stone = ColorScale(
    shade50: Color(0xFFFAFAF9),
    shade100: Color(0xFFF5F5F4),
    shade200: Color(0xFFE7E5E4),
    shade300: Color(0xFFD6D3D1),
    shade400: Color(0xFFA8A29E),
    shade500: Color(0xFF78716C),
    shade600: Color(0xFF57534E),
    shade700: Color(0xFF44403C),
    shade800: Color(0xFF292524),
    shade900: Color(0xFF1C1917),
    shade950: Color(0xFF0C0A09),
  );

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// App background, matching the web app's `background_color`.
  static const Color canvasLight = Color(0xFFF3F7EC);

  /// Brand colour, matching the web app's `theme_color`.
  static const Color brand = Color(0xFF2F6F3E);
}

/// Spacing scale on a 4px grid, named after the Tailwind step it corresponds to
/// (`s4` is Tailwind's `p-4`, i.e. 16 logical pixels).
abstract final class AppSpacing {
  static const double sHalf = 2;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;

  /// Horizontal page padding, matching the web app's `px-4 sm:px-6`.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: s4);
}

/// Corner radii.
abstract final class AppRadii {
  static const double sm = 2;
  static const double base = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xl2 = 16;
  static const double xl3 = 24;
  static const double full = 9999;

  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xl2All = BorderRadius.all(Radius.circular(xl2));
  static const BorderRadius xl3All = BorderRadius.all(Radius.circular(xl3));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Elevation, expressed as Tailwind's box-shadow steps rather than Material's
/// numeric elevation, so cards match the web app's flatter look.
abstract final class AppShadows {
  static const Color _tint = Color(0x14000000);
  static const Color _tintSoft = Color(0x0D000000);

  static const List<BoxShadow> sm = [
    BoxShadow(color: _tintSoft, blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> base = [
    BoxShadow(color: _tint, blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: _tintSoft, blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: _tint, blurRadius: 6, offset: Offset(0, 4)),
    BoxShadow(color: _tintSoft, blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: _tint, blurRadius: 15, offset: Offset(0, 10)),
    BoxShadow(color: _tintSoft, blurRadius: 6, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: _tint, blurRadius: 25, offset: Offset(0, 20)),
    BoxShadow(color: _tintSoft, blurRadius: 10, offset: Offset(0, 8)),
  ];
}

/// Font sizes paired with the line heights Tailwind gives them, plus the
/// letter-spacing steps used for the app's small uppercase labels.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 30;
  static const double xl4 = 36;

  /// Line heights as a multiple of the font size, since Flutter's `height` is
  /// a ratio where Tailwind's is absolute.
  static const double leadingXs = 16 / xs;
  static const double leadingSm = 20 / sm;
  static const double leadingBase = 24 / base;
  static const double leadingLg = 28 / lg;
  static const double leadingXl = 28 / xl;
  static const double leadingXl2 = 32 / xl2;
  static const double leadingXl3 = 36 / xl3;
  static const double leadingXl4 = 40 / xl4;

  /// Tailwind tracking, converted from `em` to the logical pixels Flutter wants
  /// by multiplying against the size it is applied to.
  static double trackingTight(double size) => size * -0.025;
  static double trackingWide(double size) => size * 0.025;
  static double trackingWider(double size) => size * 0.05;
  static double trackingWidest(double size) => size * 0.1;
}

/// Animation timings, matching the web app's transitions.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 400);
}
