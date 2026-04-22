import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';

class ActionTile extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final bool isDashed;
  final Color color;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDashed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDashed
            ? color.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: isDashed
            ? null
            : Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon is IconData
              ? Icon(icon, size: 18, color: color)
              : HugeIcon(icon: icon, color: color, size: 18, strokeWidth: 2),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: isDashed
          ? DashedBorder(
              color: color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              strokeWidth: 1.5,
              dashWidth: 6,
              gap: 4,
              child: content,
            )
          : content,
    );
  }
}
