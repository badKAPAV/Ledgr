import 'package:flutter/material.dart';

class TallSegmentedSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final Color inactiveColor;
  final Color? thumbColor;

  // Dimensional Properties
  final double trackHeight; // Thickness of the horizontal tracks
  final double thumbHeight; // Height of the vertical separator pill
  final double thumbWidth; // Thickness of the vertical separator
  final double gap; // Transparent space around the thumb

  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const TallSegmentedSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.activeColor,
    required this.inactiveColor,
    this.thumbColor,
    this.trackHeight = 16.0,
    this.thumbHeight = 32.0,
    this.thumbWidth = 6.0,
    this.gap = 4.0,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    // We wrap the native Flutter Slider in a custom Theme
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: trackHeight,
        activeTrackColor: activeColor,
        inactiveTrackColor: inactiveColor,
        thumbColor: thumbColor ?? activeColor,
        // The overlay is the splash effect when you hold the slider
        overlayColor: activeColor.withValues(alpha: 0.1),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),

        // Inject our custom painting logic
        trackShape: _M3GapTrackShape(
          trackHeight: trackHeight,
          gap: gap,
          thumbWidth: thumbWidth,
        ),
        thumbShape: _M3TallThumbShape(
          thumbWidth: thumbWidth,
          thumbHeight: thumbHeight,
        ),
      ),
      child: GestureDetector(
        // Ensure horizontal drags are captured by the slider and not parent scrollables
        onHorizontalDragStart: (_) {},
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      )
    );
  }
}

// --- CUSTOM TRACK SHAPE (DRAWS THE GAP) ---
class _M3GapTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final double trackHeight;
  final double gap;
  final double thumbWidth;

  const _M3GapTrackShape({
    required this.trackHeight,
    required this.gap,
    required this.thumbWidth,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete
    );

    final Canvas canvas = context.canvas;
    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!;

    // Calculate gap boundaries
    final double activeTrackRight = thumbCenter.dx - (thumbWidth / 2) - gap;
    final double inactiveTrackLeft = thumbCenter.dx + (thumbWidth / 2) + gap;

    final Radius trackRadius = Radius.circular(trackHeight / 2);

    // 1. Draw Active Track (Left side)
    if (activeTrackRight > trackRect.left) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            trackRect.left,
            trackRect.top,
            activeTrackRight.clamp(trackRect.left, trackRect.right),
            trackRect.bottom,
          ),
          trackRadius,
        ),
        activePaint,
      );
    }

    // 2. Draw Inactive Track (Right side)
    if (inactiveTrackLeft < trackRect.right) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            inactiveTrackLeft.clamp(trackRect.left, trackRect.right),
            trackRect.top,
            trackRect.right,
            trackRect.bottom,
          ),
          trackRadius,
        ),
        inactivePaint,
      );
    }
  }
}

// --- CUSTOM THUMB SHAPE (DRAWS THE TALL PILL) ---
class _M3TallThumbShape extends SliderComponentShape {
  final double thumbWidth;
  final double thumbHeight;

  const _M3TallThumbShape({
    required this.thumbWidth,
    required this.thumbHeight,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()..color = sliderTheme.thumbColor!;

    // Draw the tall rounded rectangle at the exact touch center
    final RRect thumbRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: thumbWidth, height: thumbHeight),
      Radius.circular(thumbWidth / 2)
    );

    canvas.drawRRect(thumbRRect, paint);
  }
}
