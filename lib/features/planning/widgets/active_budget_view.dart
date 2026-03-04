import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/planning/provider/budget_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/common/progress_bar/slider_progress_bar.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

class ActiveBudgetView extends StatefulWidget {
  const ActiveBudgetView({super.key});

  @override
  State<ActiveBudgetView> createState() => _ActiveBudgetViewState();
}

class _ActiveBudgetViewState extends State<ActiveBudgetView> {
  bool _isEditing = false;
  final Map<String, double> _editableBudgets = {};

  double get _totalAllocated {
    return _editableBudgets.values.fold(0.0, (sum, amt) => sum + amt);
  }

  void _showEditBudgetSheet(BuildContext context, double currentBudget) {
    final theme = Theme.of(context);
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(0),
    );
    final currencySymbol = context.read<SettingsProvider>().currencySymbol;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit Monthly Budget",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: currencySymbol,
                  prefixStyle: TextStyle(
                    fontFamily: 'momo',
                    fontSize: 24,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final newBudget = double.tryParse(controller.text) ?? 0.0;
                    final budgetProvider = context.read<BudgetProvider>();
                    await budgetProvider.updateMonthlyBudget(newBudget);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final authProvider = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final catProvider = context.watch<CategoryProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final double totalBudget = authProvider.user?.monthlyBudget ?? 0;
    final currencySymbol = settingsProvider.currencySymbol;

    // 1. Calculate Cycle
    final now = DateTime.now();
    final cycle = BudgetCycleHelper.getCycleRange(
      targetMonth: now.month,
      targetYear: now.year,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );

    // 2. Calculate Spend
    final double totalSpent = txProvider.getNetTotal(
      start: cycle.start,
      end: cycle.end,
      type: 'expense',
    );

    // 3. Category Spends
    Map<String, double> catSpends = {};
    final cycleTxs = txProvider.transactions.where(
      (t) =>
          t.type == 'expense' &&
          t.timestamp.isAfter(
            cycle.start.subtract(const Duration(seconds: 1)),
          ) &&
          t.timestamp.isBefore(cycle.end.add(const Duration(seconds: 1))),
    );
    for (var tx in cycleTxs) {
      if (tx.categoryId != null) {
        catSpends[tx.categoryId!] =
            (catSpends[tx.categoryId!] ?? 0) + tx.amount;
      }
    }

    // 4. Safe to Spend Math
    final int daysInCycle = cycle.end.difference(cycle.start).inDays + 1;
    final int daysPassed = now.difference(cycle.start).inDays;
    final int daysLeft = daysInCycle - daysPassed;

    final double remainingBudget = totalBudget - totalSpent;
    final double safeToSpendDaily = daysLeft > 0 && remainingBudget > 0
        ? remainingBudget / daysLeft
        : 0;

    final double progress = totalBudget > 0 ? (totalSpent / totalBudget) : 0;
    final bool isOverBudget = totalSpent > totalBudget;

    // 5. Filter Active Budget Categories
    final expenseCats = catProvider.categories.where((c) {
      if (c.mode != TransactionMode.expense || c.isDeleted) return false;
      // When editing, show all expense categories. When not, only show those with budgets > 0.
      if (_isEditing) return true;
      return c.budget != null && c.budget! > 0;
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // --- MASTER GAUGE ---
              SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(250, 250),
                      painter: _BudgetGauge(
                        progress: progress,
                        isOverBudget: isOverBudget,
                        accentColor: isOverBudget
                            ? theme.extension<AppColors>()!.expense
                            : theme.extension<AppColors>()!.income,
                        backgroundColor: theme.colorScheme.surfaceContainer
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverBudget
                              ? Icons.warning_rounded
                              : Icons.check_rounded,
                          color: isOverBudget
                              ? theme.extension<AppColors>()!.expense
                              : theme.extension<AppColors>()!.income,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currencySymbol,
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              totalSpent.toStringAsFixed(0),
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          " / ${totalBudget.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- SAFE TO SPEND PILL ---
              Row(
                mainAxisAlignment: .center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () {
                      _showEditBudgetSheet(context, totalBudget);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedEdit03,
                        strokeWidth: 2,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Safe to spend today",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "$currencySymbol${safeToSpendDaily.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () async {
                      final budgetProvider = context.read<BudgetProvider>();
                      await budgetProvider.updateMonthlyBudget(0);
                      for (var cat in catProvider.categories) {
                        if (cat.mode == TransactionMode.expense &&
                            cat.budget != null &&
                            cat.budget! > 0) {
                          await catProvider.editCategory(
                            cat.copyWith(budget: 0),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedRefresh,
                        strokeWidth: 2,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // --- CATEGORY ENVELOPES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Text(
                      'BUDGET CATEGORIES',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.normal,
                        letterSpacing: 2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_isEditing) {
                          // Save Changes
                          for (var entry in _editableBudgets.entries) {
                            final cat = catProvider.categories.firstWhere(
                              (c) => c.id == entry.key,
                            );
                            if (cat.budget != entry.value) {
                              await catProvider.editCategory(
                                cat.copyWith(budget: entry.value),
                              );
                            }
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Budgets updated",
                                  style: TextStyle(
                                    color: theme.colorScheme.onTertiary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: theme.colorScheme.tertiary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            setState(() {
                              _isEditing = false;
                            });
                          }
                        } else {
                          // Enter Edit Mode
                          setState(() {
                            _editableBudgets.clear();
                            // Populate with current budgets
                            final allExpenseCats = catProvider.categories.where(
                              (c) =>
                                  c.mode == TransactionMode.expense &&
                                  !c.isDeleted,
                            );
                            for (var c in allExpenseCats) {
                              _editableBudgets[c.id] = c.budget ?? 0.0;
                            }
                            _isEditing = true;
                          });
                        }
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isEditing ? 'SAVE' : 'EDIT',
                          key: ValueKey(_isEditing),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: expenseCats.map((cat) {
                    final budget = _isEditing
                        ? (_editableBudgets[cat.id] ?? 0.0)
                        : (cat.budget ?? 0.0);
                    final spent = catSpends[cat.id] ?? 0.0;
                    final catProgress = budget > 0
                        ? (spent / budget).clamp(0.0, 1.0)
                        : 0.0;
                    final isCatOverBudget = budget > 0 && spent >= budget;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              HugeIcon(
                                icon: GoalIconRegistry.getIcon(cat.iconKey),
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isEditing
                                    ? Row(
                                        key: const ValueKey('edit'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            currencySymbol,
                                            style: TextStyle(
                                              fontFamily: 'momo',
                                              fontSize: 16,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          IntrinsicWidth(
                                            child: TextField(
                                              controller:
                                                  TextEditingController(
                                                      text: budget
                                                          .toStringAsFixed(0),
                                                    )
                                                    ..selection =
                                                        TextSelection.collapsed(
                                                          offset: budget
                                                              .toStringAsFixed(
                                                                0,
                                                              )
                                                              .length,
                                                        ),
                                              keyboardType:
                                                  TextInputType.number,
                                              style: TextStyle(
                                                fontFamily: 'momo',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (val) {
                                                final cleanStr = val.replaceAll(
                                                  ',',
                                                  '',
                                                );
                                                final newAmt =
                                                    double.tryParse(cleanStr) ??
                                                    0.0;
                                                setState(() {
                                                  _editableBudgets[cat.id] =
                                                      newAmt;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        key: const ValueKey('display'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            currencySymbol,
                                            style: TextStyle(
                                              fontFamily: 'momo',
                                              fontSize: 16,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            spent.toStringAsFixed(0),
                                            style: TextStyle(
                                              fontFamily: 'momo',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            " / ${budget.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              fontFamily: 'momo',
                                              fontSize: 16,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          if (isCatOverBudget) ...[
                                            const SizedBox(width: 4),
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Icon(
                                                Icons.warning_rounded,
                                                color: Colors.redAccent,
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isEditing
                                ? SizedBox(
                                    height: 32, // Height of the slider area
                                    child: TallSegmentedSlider(
                                      value: budget,
                                      min: 0,
                                      max: math.max(
                                        math.max(
                                          1.0,
                                          totalBudget -
                                              (_totalAllocated - budget),
                                        ),
                                        budget,
                                      ),
                                      activeColor: theme.colorScheme.primary,
                                      inactiveColor: theme.colorScheme.primary
                                          .withValues(alpha: 0.2),
                                      trackHeight: 4.0,
                                      thumbHeight: 18.0,
                                      gap: 2.0,
                                      onChanged: (val) {
                                        setState(() {
                                          _editableBudgets[cat.id] = val
                                              .roundToDouble();
                                        });
                                      },
                                    ),
                                  )
                                : SegmentedProgressBar(
                                    height: 6,
                                    gap: 4,
                                    segments: [
                                      Segment(
                                        value: catProgress,
                                        color: isCatOverBudget
                                            ? theme
                                                  .extension<AppColors>()!
                                                  .expense
                                            : theme.colorScheme.primary,
                                      ),
                                      Segment(
                                        value: 1.0 - catProgress,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.1),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetGauge extends CustomPainter {
  final double progress;
  final bool isOverBudget;
  final Color accentColor;
  final Color backgroundColor;

  _BudgetGauge({
    required this.progress,
    required this.isOverBudget,
    required this.accentColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    canvas.drawCircle(center, radius, bgPaint);

    if (isOverBudget) {
      final overPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, overPaint);
    } else {
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      // Start from top (-pi/2), sweep 2*pi * progress
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BudgetGauge oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isOverBudget != isOverBudget ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
