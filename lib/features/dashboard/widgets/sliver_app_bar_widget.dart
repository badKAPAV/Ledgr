import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/illumated_border.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/planning/provider/budget_provider.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
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
    final budgetProvider = Provider.of<BudgetProvider>(context);

    // 1. Setup Data & Formatters
    final monthlyBudget = authProvider.user?.monthlyBudget ?? 0.0;
    final currencySymbol = settingsProvider.currencySymbol;
    final compactFmt = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    // 2. Calculate MONTHLY Expenses
    final now = DateTime.now();
    final cycle = BudgetCycleHelper.currentCycleRange(
      now,
      settingsProvider.budgetCycleMode,
      settingsProvider.budgetCycleStartDay,
    );

    final monthResult = transactionProvider.getFilteredResults(
      TransactionFilter(startDate: cycle.start, endDate: cycle.end),
    );
    double monthExpense = monthResult.totalExpense;

    // 3. Calculate DAILY Expenses (Context Aware)
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final double dailyBudget = budgetProvider.calculateCurrentDailyBudget(
      settingsProvider,
    );

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
      expandedHeight: 300, // Taller to accommodate the large gauge
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
                padding: const EdgeInsets.only(top: 120, bottom: 0),
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
                                  : theme.colorScheme.secondary,
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
                                        140, // Constrain width to fit inside inner gauge (Safe for 103px radius)
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
      duration: const Duration(milliseconds: 1500),
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
          // Reduced canvas size to pull the layout footprint in
          size: const Size(200, 200),
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
    final center = Offset(size.width / 2, size.height / 2);

    // CONFIGURATION
    const double startAngle = 135.0 + 30;
    const double sweepAngle = 210.0;

    // OUTER BAR - Smaller radius, wider stroke
    const double outerRadius = 126; // Was 140
    const double outerStroke = 28; // Was 26

    // INNER BAR - Smaller radius, significantly wider stroke
    const double innerRadius = 100; // Was 115
    const double innerStroke = 6; // Was 8

    // 1. Draw Tracks
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke;

    // Outer Track -> SQUARE
    trackPaint.strokeWidth = outerStroke;
    trackPaint.strokeCap = StrokeCap.square;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      _degToRad(startAngle),
      _degToRad(sweepAngle),
      false,
      trackPaint,
    );

    // Inner Track -> ROUND
    trackPaint.strokeWidth = innerStroke;
    trackPaint.strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      _degToRad(startAngle),
      _degToRad(sweepAngle),
      false,
      trackPaint,
    );

    // 2. Draw Progress
    final outerProgressPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..strokeCap = StrokeCap.square;

    if (outerProgress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        _degToRad(startAngle),
        _degToRad(sweepAngle * outerProgress),
        false,
        outerProgressPaint,
      );
    }

    final innerProgressPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke
      ..strokeCap = StrokeCap.round;

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
        const SizedBox(height: 6),
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
                    style: theme.textTheme.bodyLarge?.copyWith(
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
                    text: " / ${formatter.format(limit)}",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
          // const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: .all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                "You're doing good!",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
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
    return SizedBox(
      height: 240, // MATCHES THE NEW GAUGE SIZE
      width: 240, // MATCHES THE NEW GAUGE SIZE
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "What's your budget?",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'momo',
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 14, // Slightly smaller to fit the new cozy center
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: IlluminatedBorder(
                  borderWidth: 2, // Adjusted to match the chunkier UI nicely
                  glowColor: theme.colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(20),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AllTransactionsScreen(initialTabIndex: 2),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.onSurface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      side: BorderSide.none,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text("Set Budgets"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
