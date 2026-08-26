import 'dart:ui';

import 'package:flutter/foundation.dart';

/// An eleven-step colour ramp, indexed the way Tailwind names its shades.
///
/// Steps run 50, 100, 200 … 900, 950 from lightest to darkest, so a call site
/// reads as `AppColors.emerald[700]` and matches the palette the web version of
/// this app is built on.
@immutable
class ColorScale {
  const ColorScale({
    required this.shade50,
    required this.shade100,
    required this.shade200,
    required this.shade300,
    required this.shade400,
    required this.shade500,
    required this.shade600,
    required this.shade700,
    required this.shade800,
    required this.shade900,
    required this.shade950,
  });

  final Color shade50;
  final Color shade100;
  final Color shade200;
  final Color shade300;
  final Color shade400;
  final Color shade500;
  final Color shade600;
  final Color shade700;
  final Color shade800;
  final Color shade900;
  final Color shade950;

  /// The steps in order, lightest first.
  static const List<int> steps = [
    50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950, //
  ];

  /// The colour at [step], which must be one of [steps].
  Color operator [](int step) {
    return switch (step) {
      50 => shade50,
      100 => shade100,
      200 => shade200,
      300 => shade300,
      400 => shade400,
      500 => shade500,
      600 => shade600,
      700 => shade700,
      800 => shade800,
      900 => shade900,
      950 => shade950,
      _ => throw ArgumentError.value(
          step,
          'step',
          'Not a palette step; expected one of $steps',
        ),
    };
  }
}
