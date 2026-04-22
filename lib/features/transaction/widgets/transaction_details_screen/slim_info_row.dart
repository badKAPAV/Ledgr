import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class SlimInfoRow extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isTransferWidget;

  const SlimInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isTransferWidget = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isTransferWidget
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: isTransferWidget
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              )
            : BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: icon is IconData
                ? Icon(icon, size: 18, color: color)
                : HugeIcon(icon: icon, color: color, size: 18, strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
