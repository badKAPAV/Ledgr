import 'package:flutter/material.dart';

class Segment {
  final double value;
  final Color color;

  const Segment({required this.value, required this.color});
}

class SegmentedProgressBar extends StatefulWidget {
  final List<Segment> segments;
  final double height;
  final double gap;
  final BorderRadiusGeometry? borderRadius;

  const SegmentedProgressBar({
    super.key,
    required this.segments,
    this.height = 12,
    this.gap = 4.0,
    this.borderRadius,
  });

  @override
  State<SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<SegmentedProgressBar> {
  @override
  Widget build(BuildContext context) {
    // 1. Filter out empty segments
    final visibleSegments = widget.segments.where((s) => s.value > 0).toList();
    if (visibleSegments.isEmpty) return const SizedBox.shrink();

    // 2. Calculate total value for percentages
    final totalValue = visibleSegments.fold(0.0, (sum, s) => sum + s.value);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If unconstrained, we can't calculate precise widths for animation.
          // Fallback to standard non-animated flex if width is infinite (rare).
          if (constraints.maxWidth.isInfinite) {
            return Row(
              children: [
                for (int i = 0; i < visibleSegments.length; i++) ...[
                  Expanded(
                    flex: (visibleSegments[i].value * 1000).toInt(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: visibleSegments[i].color,
                        borderRadius:
                            widget.borderRadius ??
                            BorderRadius.circular(widget.height),
                      ),
                    ),
                  ),
                  if (i != visibleSegments.length - 1)
                    SizedBox(width: widget.gap),
                ],
              ],
            );
          }

          // 3. Calculate pixel widths
          final totalGapWidth = (visibleSegments.length - 1) * widget.gap;
          final availableWidth = (constraints.maxWidth - totalGapWidth).clamp(
            0.0,
            double.infinity,
          );

          // 4. Entrance Animation (0.0 -> 1.0)
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            builder: (context, entranceValue, child) {
              return Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  for (int i = 0; i < visibleSegments.length; i++) ...[
                    // 5. Data Change Animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      // Calculate width based on percentage of available space
                      // Multiply by entranceValue to grow from 0 on first load
                      width:
                          (availableWidth *
                              (visibleSegments[i].value / totalValue)) *
                          entranceValue,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: visibleSegments[i].color,
                        borderRadius:
                            widget.borderRadius ??
                            BorderRadius.circular(widget.height),
                      ),
                    ),
                    // The Gap
                    if (i != visibleSegments.length - 1)
                      SizedBox(width: widget.gap),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
