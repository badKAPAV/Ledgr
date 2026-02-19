import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

enum Timeframe { weeks, months, years }

class _PeriodSummary {
  final String label;
  final String fullDateLabel;
  final double income;
  final double expense;
  final DateTimeRange range;

  _PeriodSummary({
    required this.label,
    required this.fullDateLabel,
    required this.income,
    required this.expense,
    required this.range,
  });
}

class AnalyticsWidget extends StatefulWidget {
  final Timeframe selectedTimeframe;
  final ValueChanged<Timeframe> onTimeframeChanged;

  const AnalyticsWidget({
    super.key,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
  });

  @override
  State<AnalyticsWidget> createState() => _AnalyticsWidgetState();
}

class _AnalyticsWidgetState extends State<AnalyticsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _selectedIndex = -1; // -1 means show latest/default
  double _maxY = 1.0;
  List<_PeriodSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _calculateSummaries();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimeframe != widget.selectedTimeframe) {
      _calculateSummaries();
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _calculateSummaries() {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final now = DateTime.now();

    List<_PeriodSummary> newSummaries = [];
    double localMax = 0;

    // 7 points for a nice curve
    int pointCount = 7;

    for (int i = pointCount - 1; i >= 0; i--) {
      DateTimeRange range;
      String label;
      String fullLabel;

      switch (widget.selectedTimeframe) {
        case Timeframe.weeks:
          final startDay = now.subtract(
            Duration(days: now.weekday - 1 + (i * 7)),
          );
          range = DateTimeRange(
            start: DateTime(startDay.year, startDay.month, startDay.day),
            end: startDay.add(const Duration(days: 7)),
          );
          label = DateFormat('d MMM').format(startDay);
          fullLabel =
              "${DateFormat('d MMM').format(startDay)} - ${DateFormat('d MMM').format(range.end.subtract(const Duration(days: 1)))}";
          break;

        case Timeframe.months:
          var targetMonth = now.month - i;
          var targetYear = now.year;
          while (targetMonth <= 0) {
            targetMonth += 12;
            targetYear--;
          }
          range = BudgetCycleHelper.getCycleRange(
            targetMonth: targetMonth,
            targetYear: targetYear,
            mode: settings.budgetCycleMode,
            startDay: settings.budgetCycleStartDay,
          );
          final mid = range.start.add(const Duration(days: 15));
          label = DateFormat('MMM').format(mid);
          fullLabel = DateFormat('MMMM yyyy').format(mid);
          break;

        case Timeframe.years:
          final year = DateTime(now.year - i, 1, 1);
          range = DateTimeRange(
            start: year,
            end: DateTime(year.year + 1, 1, 1),
          );
          label = DateFormat('yy').format(year);
          fullLabel = DateFormat('yyyy').format(year);
          break;
      }

      final income = txProvider.getNetTotal(
        start: range.start,
        end: range.end,
        type: 'income',
      );
      final expense = txProvider.getNetTotal(
        start: range.start,
        end: range.end,
        type: 'expense',
      );

      if (income > localMax) localMax = income;
      if (expense > localMax) localMax = expense;

      newSummaries.add(
        _PeriodSummary(
          label: label,
          fullDateLabel: fullLabel,
          income: income,
          expense: expense,
          range: range,
        ),
      );
    }

    setState(() {
      _summaries = newSummaries;
      _maxY = localMax > 0 ? localMax * 1.1 : 1.0; // Add 10% breathing room
      _selectedIndex = _summaries.length - 1; // Default to latest
    });
  }

  void _handleTouch(Offset localPosition, double width) {
    if (_summaries.isEmpty) return;
    final step = width / (_summaries.length - 1);
    // Find closest index
    int index = (localPosition.dx / step).round().clamp(
      0,
      _summaries.length - 1,
    );

    if (index != _selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final currencySymbol = settings.currencySymbol;
    final appColors = theme.extension<AppColors>()!;

    final selectedData = _summaries.isNotEmpty
        ? _summaries[_selectedIndex]
        : _PeriodSummary(
            label: '',
            fullDateLabel: '',
            income: 0,
            expense: 0,
            range: DateTimeRange(start: DateTime.now(), end: DateTime.now()),
          );

    return Container(
      height: 240, // Fixed height as requested
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),

              // 2. The Line Chart
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onHorizontalDragUpdate: (details) => _handleTouch(
                            details.localPosition,
                            constraints.maxWidth,
                          ),
                          onTapDown: (details) => _handleTouch(
                            details.localPosition,
                            constraints.maxWidth,
                          ),
                          child: CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: _SplineChartPainter(
                              data: _summaries,
                              maxY: _maxY,
                              selectedIndex: _selectedIndex,
                              animationValue: _animation.value,
                              theme: theme,
                              incomeColor: appColors.income,
                              expenseColor: appColors.expense,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeframePill(
                  selected: widget.selectedTimeframe,
                  onChanged: widget.onTimeframeChanged,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          currencySymbol: currencySymbol,
                          label: "In",
                          amount: selectedData.income,
                          color: appColors.income,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatColumn(
                          currencySymbol: currencySymbol,
                          label: "Out",
                          amount: selectedData.expense,
                          color: appColors.expense,
                        ),
                      ),
                    ],
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

// --- PAINTER: The Core Visualization ---

class _SplineChartPainter extends CustomPainter {
  final List<_PeriodSummary> data;
  final double maxY;
  final int selectedIndex;
  final double animationValue;
  final ThemeData theme;
  final Color incomeColor;
  final Color expenseColor;

  _SplineChartPainter({
    required this.data,
    required this.maxY,
    required this.selectedIndex,
    required this.animationValue,
    required this.theme,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double w = size.width;
    final double h = size.height;
    // Reserve bottom space for labels
    final double chartH = h - 20;
    final double stepX = w / (data.length - 1);

    // 1. Draw Grid/Baseline
    final linePaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(w, chartH), linePaint);

    // Helper to get Points
    Offset getPoint(int i, double value) {
      final x = i * stepX;
      // Invert Y because canvas 0 is top
      final y = chartH - ((value / maxY) * chartH * animationValue);
      return Offset(x, y);
    }

    // 2. Build Paths (Catmull-Rom Spline for smoothness)
    final Path incomePath = Path();
    final Path expensePath = Path();

    // Fill Paths (for gradients)
    final Path incomeFill = Path();
    final Path expenseFill = Path();

    if (data.isNotEmpty) {
      incomePath.moveTo(
        getPoint(0, data[0].income).dx,
        getPoint(0, data[0].income).dy,
      );
      expensePath.moveTo(
        getPoint(0, data[0].expense).dx,
        getPoint(0, data[0].expense).dy,
      );

      incomeFill.moveTo(0, chartH);
      incomeFill.lineTo(
        getPoint(0, data[0].income).dx,
        getPoint(0, data[0].income).dy,
      );

      expenseFill.moveTo(0, chartH);
      expenseFill.lineTo(
        getPoint(0, data[0].expense).dx,
        getPoint(0, data[0].expense).dy,
      );

      for (int i = 0; i < data.length - 1; i++) {
        final p0 = getPoint(i, data[i].income);
        final p1 = getPoint(i + 1, data[i + 1].income);

        // Simple cubic bezier control points for smooth flow
        final controlPoint1 = Offset(p0.dx + stepX / 2, p0.dy);
        final controlPoint2 = Offset(p1.dx - stepX / 2, p1.dy);

        incomePath.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );
        incomeFill.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );

        final e0 = getPoint(i, data[i].expense);
        final e1 = getPoint(i + 1, data[i + 1].expense);
        final eCp1 = Offset(e0.dx + stepX / 2, e0.dy);
        final eCp2 = Offset(e1.dx - stepX / 2, e1.dy);

        expensePath.cubicTo(eCp1.dx, eCp1.dy, eCp2.dx, eCp2.dy, e1.dx, e1.dy);
        expenseFill.cubicTo(eCp1.dx, eCp1.dy, eCp2.dx, eCp2.dy, e1.dx, e1.dy);
      }

      // Close fills
      incomeFill.lineTo(w, chartH);
      incomeFill.close();

      expenseFill.lineTo(w, chartH);
      expenseFill.close();
    }

    // 3. Draw Fills (Gradients)
    final incomeGradient = LinearGradient(
      colors: [
        incomeColor.withValues(alpha: 0.2),
        incomeColor.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, w, chartH));

    final expenseGradient = LinearGradient(
      colors: [
        expenseColor.withValues(alpha: 0.2),
        expenseColor.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, w, chartH));

    canvas.drawPath(incomeFill, Paint()..shader = incomeGradient);
    canvas.drawPath(expenseFill, Paint()..shader = expenseGradient);

    // 4. Draw Lines
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(incomePath, stroke..color = incomeColor);
    canvas.drawPath(expensePath, stroke..color = expenseColor);

    // 5. Draw Selected Indicator & Labels
    // Scrubber Line
    final selectedX = selectedIndex * stepX;
    final scrubberPaint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dashed line logic
    double dashY = 0;
    while (dashY < chartH) {
      canvas.drawLine(
        Offset(selectedX, dashY),
        Offset(selectedX, dashY + 4),
        scrubberPaint,
      );
      dashY += 8;
    }

    // Dots on selected points
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Income Dot
    final iPos = getPoint(selectedIndex, data[selectedIndex].income);
    canvas.drawCircle(iPos, 6, dotPaint..color = theme.colorScheme.surface);
    canvas.drawCircle(iPos, 4, dotPaint..color = incomeColor);

    // Expense Dot
    final ePos = getPoint(selectedIndex, data[selectedIndex].expense);
    canvas.drawCircle(ePos, 6, dotPaint..color = theme.colorScheme.surface);
    canvas.drawCircle(ePos, 4, dotPaint..color = expenseColor);

    // 6. X-Axis Labels
    final textStyle = TextStyle(
      color: theme.colorScheme.outline,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Draw first, middle, last to avoid crowding, or all if few
    for (int i = 0; i < data.length; i++) {
      // Draw label if it's selected OR it's a key point (first/last)
      // To keep it clean, maybe only start and end? Or all if it fits.
      // Let's draw selected label highlighted, others faded.

      final isSelected = i == selectedIndex;
      final span = TextSpan(
        text: data[i].label,
        style: textStyle.copyWith(
          color: isSelected
              ? theme.colorScheme.onSurface
              : theme.colorScheme.outline.withValues(alpha: 0.5),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();

      // Center text on the x coordinate
      tp.paint(canvas, Offset(i * stepX - tp.width / 2, h - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data;
  }
}

// --- HELPERS (Copied from previous snippet for context) ---

class _StatColumn extends StatelessWidget {
  final String currencySymbol;
  final String label;
  final double amount;
  final Color color;

  const _StatColumn({
    required this.currencySymbol,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = label.toLowerCase().contains('in');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 50,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Switcher for smooth number transitions
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    NumberFormat.compactCurrency(
                      symbol: currencySymbol,
                    ).format(amount),
                    key: ValueKey(amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.0,
                      letterSpacing: -0.5,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _TimeframePill extends StatefulWidget {
  final Timeframe selected;
  final Function(Timeframe) onChanged;

  const _TimeframePill({required this.selected, required this.onChanged});

  @override
  State<_TimeframePill> createState() => _TimeframePillState();
}

class _TimeframePillState extends State<_TimeframePill> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedText =
        widget.selected.name[0].toUpperCase() +
        widget.selected.name.substring(1);

    final decoration = BoxDecoration(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isExpanded ? 0.1 : 0.05),
          blurRadius: _isExpanded ? 12 : 4,
          offset: Offset(0, _isExpanded ? 6 : 2),
        ),
      ],
    );

    return TapRegion(
      onTapOutside: (event) {
        if (_isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isExpanded = !_isExpanded);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          constraints: const BoxConstraints(minHeight: 50),
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isExpanded)
                  SizedBox(
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                if (_isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: Timeframe.values.map((tf) {
                        final isSelected = widget.selected == tf;
                        final text =
                            tf.name[0].toUpperCase() + tf.name.substring(1);
                        return GestureDetector(
                          onTap: () {
                            widget.onChanged(tf);
                            HapticFeedback.lightImpact();
                            setState(() => _isExpanded = false);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.transparent,
                            child: Text(
                              text,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w500,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
