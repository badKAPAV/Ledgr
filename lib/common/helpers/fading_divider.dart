import 'package:flutter/material.dart';

class FadingDivider extends StatelessWidget {
  final Color color;
  final Alignment fadeTowards;
  final double thickness;

  const FadingDivider({
    super.key,
    required this.color,
    this.fadeTowards = Alignment.centerRight,
    this.thickness = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the starting point dynamically based on where it needs to fade towards.
    // If fading towards the right (centerRight), we must start at the left (centerLeft).
    final Alignment beginAlignment = fadeTowards == Alignment.centerRight
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      height: thickness,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: beginAlignment,
          end: fadeTowards,
          colors: [
            color,
            color.withValues(alpha: 0.0), // Fades to completely transparent
          ],
        ),
      ),
    );
  }
}
