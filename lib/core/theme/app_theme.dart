import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'tokens.dart';

/// Builds the app's [ThemeData] from the design tokens.
abstract final class AppTheme {
  /// The light theme. This is the app's primary look.
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  /// The dark theme, offered for system dark mode.
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.emerald[600],
      brightness: brightness,
    ).copyWith(
      primary: palette.brand,
      onPrimary: palette.textOnBrand,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: palette.riskHigh.accent,
    );

    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.xl2All,
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        space: AppSpacing.s4,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: palette.textOnBrand,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.brand,
          side: BorderSide(color: palette.borderStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide(color: palette.brand, width: 2),
        ),
        labelStyle: textTheme.bodySmall,
        hintStyle: textTheme.bodySmall?.copyWith(color: palette.textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        side: BorderSide(color: palette.border),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.fullAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.canvas),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.brand
              : palette.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.brandMuted
              : palette.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.brand),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// The Tailwind type scale, mapped onto Material's slots.
  ///
  /// `Display`/`headline` carry the tighter tracking Tailwind gives large text;
  /// `labelSmall` carries the wide tracking used for the small uppercase
  /// eyebrow labels that appear above each card.
  static TextTheme _textTheme(AppPalette palette) {
    TextStyle style(
      double size,
      double leading,
      FontWeight weight, {
      Color? color,
      double? tracking,
    }) {
      return TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        height: leading,
        // Inter ships as a variable font, so the weight has to be driven
        // through the `wght` axis; `fontWeight` alone only picks a static face.
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
        letterSpacing: tracking,
        color: color ?? palette.textPrimary,
      );
    }

    return TextTheme(
      displaySmall: style(
        AppTypography.xl4,
        AppTypography.leadingXl4,
        FontWeight.w600,
        tracking: AppTypography.trackingTight(AppTypography.xl4),
      ),
      headlineMedium: style(
        AppTypography.xl3,
        AppTypography.leadingXl3,
        FontWeight.w600,
        tracking: AppTypography.trackingTight(AppTypography.xl3),
      ),
      headlineSmall: style(
        AppTypography.xl2,
        AppTypography.leadingXl2,
        FontWeight.w600,
      ),
      titleLarge: style(
        AppTypography.xl,
        AppTypography.leadingXl,
        FontWeight.w600,
      ),
      titleMedium: style(
        AppTypography.lg,
        AppTypography.leadingLg,
        FontWeight.w600,
      ),
      titleSmall: style(
        AppTypography.base,
        AppTypography.leadingBase,
        FontWeight.w600,
      ),
      bodyLarge: style(
        AppTypography.base,
        AppTypography.leadingBase,
        FontWeight.w400,
      ),
      bodyMedium: style(
        AppTypography.sm,
        AppTypography.leadingSm,
        FontWeight.w400,
      ),
      bodySmall: style(
        AppTypography.xs,
        AppTypography.leadingXs,
        FontWeight.w400,
        color: palette.textSecondary,
      ),
      labelLarge: style(
        AppTypography.sm,
        AppTypography.leadingSm,
        FontWeight.w500,
      ),
      labelMedium: style(
        AppTypography.xs,
        AppTypography.leadingXs,
        FontWeight.w500,
      ),
      labelSmall: style(
        AppTypography.xs,
        AppTypography.leadingXs,
        FontWeight.w600,
        color: palette.textSecondary,
        tracking: AppTypography.trackingWidest(AppTypography.xs),
      ),
    );
  }
}
