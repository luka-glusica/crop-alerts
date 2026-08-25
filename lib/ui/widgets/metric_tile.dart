import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// One current-conditions reading: an eyebrow label, a value, an icon.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: palette.brandMuted,
        borderRadius: AppRadii.xlAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            value,
            style: text.titleMedium?.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}
