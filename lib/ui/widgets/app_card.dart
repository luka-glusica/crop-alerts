import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// The app's standard surface: a flat, emerald-bordered panel.
///
/// Matches the web version, which uses borders rather than Material's shadows
/// to separate content.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.s4),
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: color ?? palette.surface,
      borderRadius: AppRadii.xl2All,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.xl2All,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadii.xl2All,
            border: Border.all(color: borderColor ?? palette.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
