import 'dart:math' as math;
import 'package:flutter/material.dart';

class GaugeChartItem {
  final String label;
  final double amount;
  final Color? color;

  GaugeChartItem({required this.label, required this.amount, this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GaugeChartItem &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          amount == other.amount &&
          color == other.color;

  @override
  int get hashCode => label.hashCode ^ amount.hashCode ^ color.hashCode;
}

class AnimatedGaugeChart extends StatefulWidget {
  final List<GaugeChartItem> items;
  final double totalAmount;
  final double gapDegrees;
  final bool useRoundedEdges; // Kept for API compatibility
  final double strokeWidth;
  final Size size;

  const AnimatedGaugeChart({
    super.key,
    required this.items,
    required this.totalAmount,
    this.gapDegrees = 4.0,
    this.useRoundedEdges = true, // Ignored internally now
    this.strokeWidth = 50.0,
    this.size = const Size(280, 140),
  });

  @override
  State<AnimatedGaugeChart> createState() => _AnimatedGaugeChartState();
}

class _AnimatedGaugeChartState extends State<AnimatedGaugeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200)
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedGaugeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smart Compare: Only restart if data ACTUALLY changed
    if (!_isDataEqual(oldWidget.items, widget.items) ||
        oldWidget.totalAmount != widget.totalAmount) {
      _controller.reset();
      _controller.forward();
    }
  }

  // Deep comparison helper
  bool _isDataEqual(
    List<GaugeChartItem> oldList,
    List<GaugeChartItem> newList,
  ) {
    if (oldList.length != newList.length) return false;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i] != newList[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: widget.size,
          painter: GaugeChartPainter(
            items: widget.items,
            totalAmount: widget.totalAmount,
            animationValue: _animation.value,
            gapDegrees: widget.gapDegrees,
            useRoundedEdges: widget.useRoundedEdges,
            strokeWidth: widget.strokeWidth,
          ),
        );
      }
    );
  }
}

class GaugeChartPainter extends CustomPainter {
  final List<GaugeChartItem> items;
  final double totalAmount;
  final double strokeWidth;
  final double startAngleDegrees;
  final double sweepAngleDegrees;
  final double animationValue;
  final double gapDegrees;
  final bool useRoundedEdges;

  GaugeChartPainter({
    required this.items,
    required this.totalAmount,
    required this.animationValue,
    this.strokeWidth = 50,
    this.startAngleDegrees = 180,
    this.sweepAngleDegrees = 180,
    this.gapDegrees = 4.0,
    this.useRoundedEdges = true,
  });

  Color _getDefaultColor(String label) {
    final hash = label.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(
      255,
      (r + 100) % 256,
      (g + 100) % 256,
      (b + 100) % 256
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final startRad = startAngleDegrees * (math.pi / 180);
    final sweepRad = sweepAngleDegrees * (math.pi / 180);
    final gapRad = gapDegrees * (math.pi / 180);

    // Background Track (Always Butt Cap)
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // FORCED FLAT

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      sweepRad,
      false,
      bgPaint
    );

    if (totalAmount <= 0 || items.isEmpty) return;

    final totalGapSpace = (items.length - 1) * gapRad;
    final usableSweepRad = sweepRad - (totalGapSpace > 0 ? totalGapSpace : 0);

    double currentAngle = startRad;

    for (var item in items) {
      final percentage = item.amount / totalAmount;
      double itemSweepRad = percentage * usableSweepRad;
      double animatedSweep = itemSweepRad * animationValue;

      final paint = Paint()
        ..color = item.color ?? _getDefaultColor(item.label)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // FORCED FLAT (Ignoring useRoundedEdges)

      if (animatedSweep > 0.01) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle,
          animatedSweep,
          false,
          paint,
        );
      }

      currentAngle += itemSweepRad + gapRad;
    }
  }

  @override
  bool shouldRepaint(covariant GaugeChartPainter oldDelegate) {
    // Only repaint if animation is playing or data changed structurally
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.items != items ||
        oldDelegate.totalAmount != totalAmount;
  }
}
