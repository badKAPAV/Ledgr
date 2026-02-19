import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/planning/screens/planning_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/dashboard/widgets/analytics_widget.dart';

class HomeSliverAppBar extends StatefulWidget {
  final Timeframe selectedTimeframe;

  const HomeSliverAppBar({super.key, required this.selectedTimeframe});

  @override
  State<HomeSliverAppBar> createState() => _HomeSliverAppBarState();
}

class _HomeSliverAppBarState extends State<HomeSliverAppBar> {
  final PageController _pageController = PageController();
  int _currentPage = 0; // 0 = Month, 1 = Today

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);

    // 1. Setup Data & Formatters
    final monthlyBudget = authProvider.user?.monthlyBudget ?? 0.0;
    final currencySymbol = settingsProvider.currencySymbol;
    final compactFmt = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    // 2. Calculate MONTHLY Expenses
    final now = DateTime.now();
    final cycle = BudgetCycleHelper.getCycleRange(
      targetMonth: now.month,
      targetYear: now.year,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );

    final monthResult = transactionProvider.getFilteredResults(
      TransactionFilter(startDate: cycle.start, endDate: cycle.end),
    );
    double monthExpense = monthResult.totalExpense;

    // 3. Calculate DAILY Expenses (Context Aware)
    // Daily budget = (Monthly Budget - Spent BEFORE Today) / (Days Remaining incl Today)
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Calculate spent BEFORE today in the current cycle
    final beforeTodayResult = transactionProvider.getFilteredResults(
      TransactionFilter(startDate: cycle.start, endDate: todayStart),
    );
    final spentBeforeToday = beforeTodayResult.totalExpense;

    // Calculate Remaining Budget for the rest of the month
    final remainingMonthBudget = monthlyBudget - spentBeforeToday;

    // Calculate Days Remaining (Inclusive of Today)
    final daysRemaining = cycle.end.difference(todayStart).inDays;

    // Context Aware Daily Budget
    // If remaining budget is <= 0, daily budget is 0.
    // If daysRemaining is somehow 0 or less (shouldn't happen in valid cycle), handle it.
    final double dailyBudget =
        (monthlyBudget > 0 && remainingMonthBudget > 0 && daysRemaining > 0)
        ? remainingMonthBudget / daysRemaining
        : 0.0;

    final todayResult = transactionProvider.getFilteredResults(
      TransactionFilter(startDate: todayStart, endDate: todayEnd),
    );
    double todayExpense = todayResult.totalExpense;

    // 4. Determine Progress for Gauges (0.0 to 1.0)
    final double monthProgress = monthlyBudget > 0
        ? (monthExpense / monthlyBudget).clamp(0.0, 1.0)
        : 0.0;
    final double dailyProgress = monthlyBudget > 0
        ? (dailyBudget > 0
              ? (todayExpense / dailyBudget).clamp(0.0, 1.0)
              : (todayExpense > 0 ? 1.0 : 0.0))
        : 0.0;

    final bool isMonthOverspent =
        monthlyBudget > 0 && monthExpense > monthlyBudget;

    // Fix: If monthly budget exists but daily budget is 0 (e.g. run out),
    // any expense today is overspending.
    final bool isTodayOverspent =
        monthlyBudget > 0 && todayExpense > dailyBudget;

    return SliverAppBar(
      expandedHeight: 320, // Taller to accommodate the large gauge
      collapsedHeight: 60,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // --- Background Glow ---
            Positioned(
              top: -200,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: SvgPicture.asset(
                  'assets/vectors/home_gradient_vector.svg',
                  width: 500,
                  height: 500,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary.withAlpha(100),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),

            // --- Main Content ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 140, bottom: 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (monthlyBudget > 0)
                      SizedBox(
                        height: 180, // Canvas Size Increased
                        width: 180, // Canvas Size Increased
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // 1. The Dual Radial Gauge
                            DualRadialGauge(
                              outerValue: dailyProgress, // Outer is now DAILY
                              innerValue: monthProgress, // Inner is now MONTHLY
                              outerColor: isTodayOverspent
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              innerColor: isMonthOverspent
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.tertiary,
                              trackColor: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ), // Subtle track
                            ),

                            // 2. The Swipeable Content (PageView)
                            Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              bottom: 36,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 120, // Height for text content
                                    width:
                                        170, // Constrain width to fit inside inner gauge (Safe for 103px radius)
                                    child: PageView(
                                      physics: BouncingScrollPhysics(),
                                      controller: _pageController,
                                      onPageChanged: (index) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _currentPage = index);
                                      },
                                      children: [
                                        _GaugeInfoContent(
                                          label: "TODAY",
                                          amount: todayExpense,
                                          limit: dailyBudget,
                                          isOverspent: isTodayOverspent,
                                          theme: theme,
                                          formatter: compactFmt,
                                        ),
                                        // Page 0: THIS MONTH
                                        _GaugeInfoContent(
                                          label: "THIS MONTH",
                                          amount: monthExpense,
                                          limit: monthlyBudget,
                                          isOverspent: isMonthOverspent,
                                          theme: theme,
                                          formatter: compactFmt,
                                        ),

                                        // Page 1: TODAY
                                      ],
                                    ),
                                  ),

                                  // const SizedBox(height: 8),

                                  // Page Indicator Dots
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Dot(
                                        isActive: _currentPage == 0,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      _Dot(
                                        isActive: _currentPage == 1,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Empty State
                      _NoBudgetState(theme: theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // --- Standard App Bar Title ---
      title: Row(
        children: [
          Expanded(
            child: Text(
              'ledgr',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchTransactionsScreen(),
              ),
            ),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
      centerTitle: true,
      titleSpacing: 20,
    );
  }
}

// --- 1. THE DUAL RADIAL GAUGE WIDGET ---
class DualRadialGauge extends StatefulWidget {
  final double outerValue; // 0.0 to 1.0
  final double innerValue; // 0.0 to 1.0
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;

  const DualRadialGauge({
    super.key,
    required this.outerValue,
    required this.innerValue,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
  });

  @override
  State<DualRadialGauge> createState() => _DualRadialGaugeState();
}

class _DualRadialGaugeState extends State<DualRadialGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Smooth, slow entry
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(DualRadialGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outerValue != widget.outerValue ||
        oldWidget.innerValue != widget.innerValue) {
      _controller.reset();
      _controller.forward();
    }
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
          size: const Size(360, 320), // Increased Size
          painter: _DualGaugePainter(
            outerProgress: widget.outerValue * _animation.value,
            innerProgress: widget.innerValue * _animation.value,
            outerColor: widget.outerColor,
            innerColor: widget.innerColor,
            trackColor: widget.trackColor,
          ),
        );
      },
    );
  }
}

class _DualGaugePainter extends CustomPainter {
  final double outerProgress;
  final double innerProgress;
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;

  _DualGaugePainter({
    required this.outerProgress,
    required this.innerProgress,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); // Center exactly

    // CONFIGURATION
    const double startAngle =
        135.0 + 30; // Start at ~165 degrees (Bottom Left ish)
    const double sweepAngle = 210.0; // Sweep 210 degrees to Right

    // OUTER BAR (Thicker) - INCREASED RADIUS
    const double outerRadius = 140;
    const double outerStroke = 26; // Thick

    // INNER BAR (Thinner) - INCREASED RADIUS
    const double innerRadius = 115;
    const double innerStroke = 8; // Thin

    // 1. Draw Tracks
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer Track
    trackPaint.strokeWidth = outerStroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      _degToRad(startAngle),
      _degToRad(sweepAngle),
      false,
      trackPaint,
    );

    // Inner Track
    trackPaint.strokeWidth = innerStroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      _degToRad(startAngle),
      _degToRad(sweepAngle),
      false,
      trackPaint,
    );

    // 2. Draw Progress (With "pixel perfect" caps)

    // Outer Progress
    final outerProgressPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..strokeCap = StrokeCap.round; // Radius ~4ish visually relative to size

    if (outerProgress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        _degToRad(startAngle),
        _degToRad(sweepAngle * outerProgress),
        false,
        outerProgressPaint,
      );
    }

    // Inner Progress
    final innerProgressPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke
      ..strokeCap = StrokeCap.round; // Radius 20ish visually (fully rounded)

    if (innerProgress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        _degToRad(startAngle),
        _degToRad(sweepAngle * innerProgress),
        false,
        innerProgressPaint,
      );
    }
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  @override
  bool shouldRepaint(covariant _DualGaugePainter old) =>
      old.outerProgress != outerProgress || old.innerProgress != innerProgress;
}

// --- 2. INFO CONTENT WIDGET (Text in Middle) ---
class _GaugeInfoContent extends StatelessWidget {
  final String label;
  final double amount;
  final double limit;
  final bool isOverspent;
  final ThemeData theme;
  final NumberFormat formatter;

  const _GaugeInfoContent({
    required this.label,
    required this.amount,
    required this.limit,
    required this.isOverspent,
    required this.theme,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: theme.colorScheme.outline,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  // The Large Amount
                  TextSpan(
                    text: formatter.format(amount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isOverspent
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontSize: 36,
                      letterSpacing: -1.0,
                    ),
                  ),
                  // The Small Limit
                  TextSpan(
                    text: "  / ${formatter.format(limit)}",
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isOverspent)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: theme.colorScheme.error, size: 16),
              const SizedBox(width: 4),
              Text(
                "OVERLIMIT",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        else if (!isOverspent) ...[
          const SizedBox(height: 8),
          Text(
            "You're doing good!",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

// --- 3. HELPER WIDGETS ---
class _Dot extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _Dot({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 4,
      width: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color: isActive ? color : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _NoBudgetState extends StatelessWidget {
  final ThemeData theme;
  const _NoBudgetState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ghost Gauge
        Opacity(
          opacity: 0.1,
          child: DualRadialGauge(
            outerValue: 1.0,
            innerValue: 0.6,
            outerColor: theme.colorScheme.onSurface,
            innerColor: theme.colorScheme.onSurface,
            trackColor: Colors.transparent,
          ),
        ),
        // Action
        Transform.translate(
          offset: const Offset(0, -120), // Pull up into the ghost gauge
          child: Column(
            children: [
              Text(
                "No Budget Set",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PlanningScreen(initialTabIndex: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Set Goals"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
