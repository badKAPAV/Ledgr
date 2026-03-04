import 'dart:math' as math;
import 'package:flutter/material.dart';

class IlluminatedBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final Color glowColor;
  final BorderRadius borderRadius;

  const IlluminatedBorder({
    super.key,
    required this.child,
    this.borderWidth = 1.5,
    required this.glowColor,
    required this.borderRadius,
  });

  @override
  State<IlluminatedBorder> createState() => _IlluminatedBorderState();
}

class _IlluminatedBorderState extends State<IlluminatedBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 2.5 seconds feels smooth and subtle. Drop to 1500 for a faster orbit.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IlluminatedBorderPainter(
        animation: _controller,
        borderWidth: widget.borderWidth,
        glowColor: widget.glowColor,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
  }
}

class _IlluminatedBorderPainter extends CustomPainter {
  final Animation<double> animation;
  final double borderWidth;
  final Color glowColor;
  final BorderRadius borderRadius;

  _IlluminatedBorderPainter({
    required this.animation,
    required this.borderWidth,
    required this.glowColor,
    required this.borderRadius,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 1. Draw a very faint static track underneath so the border isn't entirely invisible
    final trackPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, trackPaint);

    // 2. Create the sweeping "comet" gradient
    final gradient = SweepGradient(
      colors: [
        Colors.transparent,
        glowColor.withValues(alpha: 0.8),
        glowColor,
        Colors.transparent,
      ],
      // The tight stops create a short tail and a sharp head
      stops: const [0.0, 0.15, 0.2, 0.25],
      transform: GradientRotation(animation.value * 2 * math.pi),
    );

    final glowPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _IlluminatedBorderPainter old) => false;
}
