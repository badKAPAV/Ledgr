import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final dynamic icon;
  final bool isDashed;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.bgColor,
    this.icon,
    // ignore: unused_element_parameter
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: isDashed
            ? Border.all(color: color.withValues(alpha: 0.5))
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (icon is IconData)
              Icon(icon, color: color, size: 14)
            else
              HugeIcon(icon: icon, color: color, size: 14, strokeWidth: 2),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
