import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Data model for the chart
class CustomChartData {
  final String label;
  final double barValue; // Usually Expense
  final double lineValue; // Usually Income
  final String barTooltip;
  final String lineTooltip;

  CustomChartData({
    required this.label,
    required this.barValue,
    required this.lineValue,
    required this.barTooltip,
    required this.lineTooltip,
  });
}

class CustomComboChart extends StatefulWidget {
  final List<CustomChartData> data;
  final int? selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final Color barColor;
  final Color lineColor;
  final double height;
  final double itemWidth;

  const CustomComboChart({
    super.key,
    required this.data,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    this.barColor = Colors.redAccent,
    this.lineColor = Colors.greenAccent,
    this.height = 280.0,
    this.itemWidth = 64.0,
  });

  @override
  State<CustomComboChart> createState() => _CustomComboChartState();
}

class _CustomComboChartState extends State<CustomComboChart> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients && widget.data.length > 5) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // --- 1. DATA ANALYSIS ---
    // Check if we have data for specific series globally
    final bool hasAnyBarData = widget.data.any((d) => d.barValue > 0);
    final bool hasAnyLineData = widget.data.any((d) => d.lineValue > 0);

    // Find max value
    double maxVal = 0.0;
    for (var d in widget.data) {
      if (hasAnyBarData && d.barValue > maxVal) maxVal = d.barValue;
      if (hasAnyLineData && d.lineValue > maxVal) maxVal = d.lineValue;
    }
    if (maxVal == 0) maxVal = 1.0;

    // --- 2. LAYOUT CONSTANTS ---
    const double topPadding = 50.0;
    const double labelZoneHeight = 40.0;

    // Safety check for height
    final double safeHeight =
        widget.height < (topPadding + labelZoneHeight + 50)
        ? (topPadding + labelZoneHeight + 100)
        : widget.height;

    final double chartZoneHeight = safeHeight - labelZoneHeight - topPadding;

    return SizedBox(
      height: safeHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutQuart,
        builder: (context, animValue, child) {
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            clipBehavior: Clip.none,
            child: SizedBox(
              width: widget.data.length * widget.itemWidth,
              height: safeHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Anchor
                  SizedBox(
                    width: widget.data.length * widget.itemWidth,
                    height: safeHeight,
                  ),

                  // --- LAYER 1: BARS & LABELS ---
                  Positioned(
                    top: topPadding,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(widget.data.length, (index) {
                        final item = widget.data[index];
                        final isSelected = widget.selectedIndex == index;

                        // Calculate Bar Height
                        double barHeight = 0;
                        if (hasAnyBarData && item.barValue > 0) {
                          barHeight =
                              (item.barValue / maxVal) *
                              chartZoneHeight *
                              animValue;
                          if (barHeight < 6) barHeight = 6;
                        }

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSelectedIndexChanged(index);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: widget.itemWidth,
                            // Explicit hit test container
                            child: Container(
                              color: Colors.transparent,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // Chart Zone
                                  SizedBox(
                                    height: chartZoneHeight,
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Only render bar if global data exists
                                        if (hasAnyBarData)
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 400,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            width: 56,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: isSelected
                                                    ? [
                                                        widget.barColor,
                                                        widget.barColor
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                      ]
                                                    : [
                                                        widget.barColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        widget.barColor
                                                            .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                      ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Label Zone
                                  SizedBox(
                                    height: labelZoneHeight,
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          item.label,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 10,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // --- LAYER 2: THE SMOOTH LINE OVERLAY ---
                  if (hasAnyLineData)
                    Positioned(
                      top: topPadding,
                      left: 0,
                      right: 0,
                      height: chartZoneHeight,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: Size(
                            widget.data.length * widget.itemWidth,
                            chartZoneHeight,
                          ),
                          painter: _SmoothLinePainter(
                            data: widget.data,
                            maxY: maxVal,
                            animValue: animValue,
                            lineColor: widget.lineColor,
                            itemWidth: widget.itemWidth,
                            selectedIndex: widget.selectedIndex,
                          ),
                        ),
                      ),
                    ),

                  // --- LAYER 3: SMART TOOLTIPS ---
                  if (widget.selectedIndex != null &&
                      widget.selectedIndex! < widget.data.length)
                    _buildSmartTooltip(
                      context,
                      widget.selectedIndex!,
                      maxVal,
                      chartZoneHeight,
                      topPadding,
                      animValue,
                      theme,
                      hasAnyBarData,
                      hasAnyLineData,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSmartTooltip(
    BuildContext context,
    int index,
    double maxVal,
    double chartHeight,
    double topPadding,
    double animValue,
    ThemeData theme,
    bool hasBarData,
    bool hasLineData,
  ) {
    final item = widget.data[index];

    // Determine visibility for this specific item
    final bool showBar = hasBarData && item.barValue > 0;
    final bool showLine = hasLineData && item.lineValue > 0;

    if (!showBar && !showLine) return const SizedBox.shrink();

    // Calculations
    double barTopY = chartHeight; // Default to bottom
    if (showBar) {
      final double barH = (item.barValue / maxVal) * chartHeight * animValue;
      barTopY = chartHeight - math.max(barH, 6.0);
    }

    double lineY = chartHeight; // Default to bottom
    if (showLine) {
      lineY =
          chartHeight - ((item.lineValue / maxVal) * chartHeight * animValue);
    }

    final double xCenter = (index * widget.itemWidth) + (widget.itemWidth / 2);
    final double verticalOffset = topPadding;

    // Check collision ONLY if both are visible
    bool isCollision = false;
    if (showBar && showLine) {
      const double collisionThreshold = 50.0;
      isCollision = (barTopY - lineY).abs() < collisionThreshold;
    }

    return Positioned(
      left: xCenter - 60,
      width: 120,
      top: 0,
      bottom: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Anchor
          const SizedBox(width: 120),

          if (isCollision)
            Positioned(
              top: verticalOffset + math.min(barTopY, lineY) - 55,
              left: 0,
              right: 0,
              child: Center(
                child: _MergedTooltip(
                  barLabel: item.barTooltip,
                  lineLabel: item.lineTooltip,
                  barColor: widget.barColor,
                  lineColor: widget.lineColor,
                  theme: theme,
                ),
              ),
            )
          else ...[
            if (showBar)
              Positioned(
                top: verticalOffset + barTopY - 35,
                left: 0,
                right: 0,
                child: Center(
                  child: _SingleTooltip(
                    text: item.barTooltip,
                    color: widget.barColor,
                    theme: theme,
                  ),
                ),
              ),
            if (showLine)
              Positioned(
                top: verticalOffset + lineY - 35,
                left: 0,
                right: 0,
                child: Center(
                  child: _SingleTooltip(
                    text: item.lineTooltip,
                    color: widget.lineColor,
                    theme: theme,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SmoothLinePainter extends CustomPainter {
  final List<CustomChartData> data;
  final double maxY;
  final double animValue;
  final Color lineColor;
  final double itemWidth;
  final int? selectedIndex;

  _SmoothLinePainter({
    required this.data,
    required this.maxY,
    required this.animValue,
    required this.lineColor,
    required this.itemWidth,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = (i * itemWidth) + (itemWidth / 2);
      final y =
          size.height - ((data[i].lineValue / maxY) * size.height * animValue);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = p0.dx + ((p1.dx - p0.dx) / 2);

      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    final Path fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.3),
        lineColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.9],
    );

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);

    if (selectedIndex != null && selectedIndex! < points.length) {
      final point = points[selectedIndex!];
      // Only draw dot if value is non-zero (optional preference, but looks cleaner)
      if (data[selectedIndex!].lineValue > 0) {
        canvas.drawCircle(
          point,
          8,
          Paint()..color = lineColor.withValues(alpha: 0.3),
        );
        canvas.drawCircle(point, 5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 3, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothLinePainter old) {
    return old.animValue != animValue ||
        old.selectedIndex != selectedIndex ||
        old.data != data;
  }
}

class _SingleTooltip extends StatelessWidget {
  final String text;
  final Color color;
  final ThemeData theme;

  const _SingleTooltip({
    required this.text,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseTooltipContainer(
      theme: theme,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MergedTooltip extends StatelessWidget {
  final String barLabel;
  final String lineLabel;
  final Color barColor;
  final Color lineColor;
  final ThemeData theme;

  const _MergedTooltip({
    required this.barLabel,
    required this.lineLabel,
    required this.barColor,
    required this.lineColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseTooltipContainer(
      theme: theme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: lineColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                lineLabel,
                style: TextStyle(
                  color: lineColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: barColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                barLabel,
                style: TextStyle(
                  color: barColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaseTooltipContainer extends StatelessWidget {
  final Widget child;
  final ThemeData theme;

  const _BaseTooltipContainer({required this.child, required this.theme});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, val, _) {
        return Transform.scale(
          scale: val,
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(
              //   color: theme.colorScheme.primaryContainer,
              //   width: 2,
              // ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
