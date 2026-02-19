import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/planning/provider/budget_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/core/themes/theme.dart';

class BudgetTabScreen extends StatefulWidget {
  const BudgetTabScreen({super.key});

  @override
  State<BudgetTabScreen> createState() => _BudgetTabScreenState();
}

class _BudgetTabScreenState extends State<BudgetTabScreen> {
  final TextEditingController _budgetController = TextEditingController();
  double _averageExpense = 0;
  double _intensity = 0.135;
  bool _isInit = true;
  // ignore: unused_field
  bool _isStudying = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _fetchInitialData();
      _isInit = false;
    }
  }

  Future<void> _fetchInitialData() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final avg = budgetProvider.calculateAverageExpenses(3, settingsProvider);

    setState(() {
      _averageExpense = avg;
      final currentBudget = authProvider.user?.monthlyBudget;

      if (currentBudget != null && currentBudget > 0 && avg > 0) {
        _intensity = (1 - (currentBudget / avg)).clamp(0.0, 0.5);
        _budgetController.text = currentBudget.toStringAsFixed(0);
      } else if (avg > 0) {
        final suggested = avg * (1 - _intensity);
        _budgetController.text = suggested.toStringAsFixed(0);
      }
      _isStudying = false;
    });
  }

  void _updateFromIntensity(double value) {
    setState(() {
      _intensity = value;
      if (_averageExpense > 0) {
        final newBudget = _averageExpense * (1 - _intensity);
        _budgetController.text = newBudget.toStringAsFixed(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // 1. Suggestion Text
              Text(
                "Based on your last 3-month average\nof $currencySymbol${(_averageExpense / 1000).toStringAsFixed(1)}K, we suggest you to save",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                ),
              ),
              // 2. Main Arc Section
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(constraints.maxWidth, 340.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Custom Arc Slider (Behind)
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: SizedBox(
                              width: size,
                              height: size,
                              child: _ArcSlider(
                                value: _intensity / 0.5,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  _updateFromIntensity(val * 0.5);
                                },
                              ),
                            ),
                          ),

                          // 2. Central Content (On Top)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      currencySymbol,
                                      style: TextStyle(
                                        fontFamily: 'momo',
                                        fontSize: 60,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IntrinsicWidth(
                                      child: TextField(
                                        controller: _budgetController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final newBudget = double.tryParse(
                                            val,
                                          );
                                          if (newBudget != null &&
                                              _averageExpense > 0) {
                                            setState(() {
                                              _intensity =
                                                  (1 -
                                                          (newBudget /
                                                              _averageExpense))
                                                      .clamp(0.0, 0.5);
                                            });
                                          }
                                        },
                                        style: TextStyle(
                                          fontSize: 94,
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1,
                                          fontFamily: 'momo',
                                          height: 1.0,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "+${(_intensity * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).extension<AppColors>()!.income,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "SAVINGS GOAL",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.24,
                                  ),
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 4. Action Section
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () => _saveBudget(budgetProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              "Start Savings",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveBudget(BudgetProvider provider) async {
    final val = double.tryParse(_budgetController.text);
    if (val != null) {
      HapticFeedback.mediumImpact();
      try {
        await provider.updateMonthlyBudget(val);
        if (mounted) {
          final appColors = Theme.of(context).extension<AppColors>()!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Goal set successfully!"),
              backgroundColor: appColors.income,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }
}

class _ArcSlider extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;

  const _ArcSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final center = Offset(box.size.width / 2, box.size.height / 2);
        final pos = details.localPosition - center;
        double angle = math.atan2(pos.dy, pos.dx);

        // Handle clamping to the bottom arc:
        // atan2 is 0 at Right, pi at Left, pi/2 at Bottom, -pi/2 at Top.
        if (angle < 0) {
          // If above horizontal, clamp to nearest end
          angle = (pos.dx < 0) ? math.pi : 0;
        }

        // Value 0 is at PI (Left), Value 1 is at 0 (Right)
        double normalized = 1.0 - (angle / math.pi);
        onChanged(normalized.clamp(0.0, 1.0));
      },
      child: CustomPaint(
        painter: _ArcPainter(
          value: value,
          colorScheme: Theme.of(context).colorScheme,
          appColors: Theme.of(context).extension<AppColors>()!,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  final ColorScheme colorScheme;
  final AppColors appColors;

  _ArcPainter({
    required this.value,
    required this.colorScheme,
    required this.appColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Background Track
    final trackPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi, false, trackPaint);

    // 2. Progress Path (Vivid Green)
    final progressPaint = Paint()
      ..color = appColors.income
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Start at pi (Left) and sweep -pi (to Right)
    canvas.drawArc(rect, math.pi, -math.pi * value, false, progressPaint);

    // 3. The Thumb (White Circle)
    // Value 0 is at PI, Value 1 is at 0
    final thumbAngle = math.pi - (math.pi * value);
    final thumbPos = Offset(
      center.dx + radius * math.cos(thumbAngle),
      center.dy + radius * math.sin(thumbAngle),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(thumbPos, 22, shadowPaint);

    canvas.drawCircle(thumbPos, 18, Paint()..color = colorScheme.onSurface);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.appColors != appColors;
}
