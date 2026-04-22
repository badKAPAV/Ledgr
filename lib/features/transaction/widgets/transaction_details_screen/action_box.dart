import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ActionBox extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const ActionBox({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = isDestructive
        ? colorScheme.errorContainer.withValues(alpha: 0.15)
        : colorScheme.primaryContainer.withValues(alpha: 0.6);

    final fgColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon is IconData
                  ? Icon(icon, size: 20, color: fgColor)
                  : HugeIcon(
                      icon: icon,
                      color: fgColor,
                      size: 20,
                      strokeWidth: 2,
                    ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
