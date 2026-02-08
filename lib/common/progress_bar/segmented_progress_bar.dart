import 'package:flutter/material.dart';

class Segment {
  final double value;
  final Color color;

  const Segment({required this.value, required this.color});
}

class SegmentedProgressBar extends StatelessWidget {
  final List<Segment> segments;
  final double height;
  final double gap;
  final BorderRadiusGeometry? borderRadius;

  const SegmentedProgressBar({
    super.key,
    required this.segments,
    this.height = 12,
    this.gap = 4.0, // Slightly larger gap looks better with fully rounded ends
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Filter out empty segments to prevent weird 0-width dots
    final visibleSegments = segments.where((s) => s.value > 0).toList();
    if (visibleSegments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (int i = 0; i < visibleSegments.length; i++) ...[
            // The Segment
            Expanded(
              flex: (visibleSegments[i].value * 1000).toInt(),
              child: Container(
                decoration: BoxDecoration(
                  color: visibleSegments[i].color,
                  // Apply radius to EVERY segment individually
                  borderRadius: borderRadius ?? BorderRadius.circular(height),
                ),
              ),
            ),
            // The Gap
            if (i != visibleSegments.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }
}
