import 'dart:math' as math;
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';
import 'package:wallzy/common/progress_bar/slider_progress_bar.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/planning/provider/budget_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class BudgetSetupWizard extends StatefulWidget {
  const BudgetSetupWizard({super.key});

  @override
  State<BudgetSetupWizard> createState() => _BudgetSetupWizardState();
}

class _BudgetSetupWizardState extends State<BudgetSetupWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Intro State
  bool _showIntro = true;

  // Analysis Data
  double _averageExpense = 0;
  bool _isAnalyzing = true;

  // Arc Slider State
  final TextEditingController _budgetController = TextEditingController();
  double _intensity = 0.15;

  // Allocation State
  final Map<String, double> _categoryBudgets = {};
  List<CategoryModel> _sortedExpenseCats = [];

  double get _totalAllocated =>
      _categoryBudgets.values.fold(0.0, (sum, val) => sum + val);

  @override
  void initState() {
    super.initState();
  }

  void _startWizard() {
    setState(() {
      _showIntro = false;
    });
    _runAnalysis();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    _averageExpense = budgetProvider.calculateAverageExpenses(
      3,
      settingsProvider,
    );

    if (_averageExpense <= 0) {
      _averageExpense = 50000;
    }

    final suggested = _averageExpense * (1 - _intensity);
    _budgetController.text = suggested.toStringAsFixed(0);

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      setState(() => _isAnalyzing = false);
      _nextStep();
    }
  }

  void _prepareAllocation() {
    final catProvider = context.read<CategoryProvider>();
    final txProvider = context.read<TransactionProvider>();
    final globalStr = _budgetController.text.replaceAll(',', '');
    final globalBudget = double.tryParse(globalStr) ?? 0;

    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 90));
    final txs = txProvider.transactions.where(
      (t) => t.type == 'expense' && t.timestamp.isAfter(past),
    );

    Map<String, double> catTotals = {};
    double totalPastExpense = 0;
    for (var tx in txs) {
      if (tx.categoryId != null) {
        catTotals[tx.categoryId!] =
            (catTotals[tx.categoryId!] ?? 0) + tx.amount;
        totalPastExpense += tx.amount;
      }
    }

    _categoryBudgets.clear();
    final expenseCats = catProvider.categories
        .where((c) => c.mode == TransactionMode.expense && !c.isDeleted)
        .toList();

    // Base allocation on 80% of the global budget
    final allocationBudget = globalBudget * 0.8;

    for (var cat in expenseCats) {
      if (totalPastExpense > 0 && catTotals.containsKey(cat.id)) {
        final ratio = catTotals[cat.id]! / totalPastExpense;
        _categoryBudgets[cat.id] = (allocationBudget * ratio).roundToDouble();
      } else {
        _categoryBudgets[cat.id] = 0.0;
      }
    }

    _sortCategories(expenseCats);
  }

  // Extracted to allow live resorting when sliders move
  void _sortCategories(List<CategoryModel> cats) {
    cats.sort((a, b) {
      final valA = _categoryBudgets[a.id] ?? 0;
      final valB = _categoryBudgets[b.id] ?? 0;
      if (valA != valB) {
        return valB.compareTo(valA); // Highest budget first
      }
      return a.name.compareTo(b.name); // Alphabetical tie-breaker
    });
    setState(() {
      _sortedExpenseCats = cats;
    });
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep == 1) {
      _prepareAllocation();
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishSetup() async {
    HapticFeedback.heavyImpact();
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final catProvider = Provider.of<CategoryProvider>(context, listen: false);
    final globalStr = _budgetController.text.replaceAll(',', '');
    final finalBudget = double.tryParse(globalStr) ?? 0;

    if (finalBudget > 0) {
      await budgetProvider.updateMonthlyBudget(finalBudget);

      for (var entry in _categoryBudgets.entries) {
        final cat = catProvider.categories.firstWhere((c) => c.id == entry.key);
        await catProvider.editCategory(cat.copyWith(budget: entry.value));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _showIntro
            ? _buildIntroStep(theme)
            : Column(
                children: [
                  // --- NEW: SLEEK DOT PROGRESS INDICATOR ---
                  if (!_isAnalyzing)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 24,
                        left: 16,
                        right: 16,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Back button (left aligned)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _currentStep == 2
                                ? IconButton(
                                    icon: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 20,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    onPressed: _previousStep,
                                  )
                                : const SizedBox(width: 48, height: 48),
                          ),

                          // Centered Step Indicator
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLineStep(1, _currentStep >= 1, theme),
                                  const SizedBox(width: 8),
                                  _buildLineStep(2, _currentStep >= 2, theme),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "STEP $_currentStep OF 2",
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),

                          // Spacer for symmetry
                          const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(width: 48, height: 48),
                          ),
                        ],
                      ),
                    ),

                  // Page Content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAnalysisStep(theme),
                        _buildTargetStep(theme),
                        _buildAllocationStep(theme),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildIntroStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedPiggyBank,
              size: 80,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            "Take Control of Your Spending",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'momo',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Set a master monthly budget and allocate funds across different categories to save more money effectively.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startWizard,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Text(
                "Let's Get Started",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLineStep(int step, bool isActive, ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 6,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // --- STEP 0: Analysis ---
  Widget _buildAnalysisStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DotLottieLoader.fromAsset(
          'assets/lottie/loader.lottie',
          frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
            if (dotlottie != null) {
              return Lottie.memory(
                dotlottie.animations.values.single,
                width: 250,
                height: 250,
                delegates: LottieDelegates(
                  values: [
                    ValueDelegate.color(const [
                      '**',
                    ], value: theme.colorScheme.primary),
                  ],
                ),
              );
            } else {
              return const SizedBox(width: 250, height: 250);
            }
          },
        ),
        const SizedBox(height: 32),
        Text(
          "Analyzing your transaction history",
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'momo',
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Building a personalized baseline",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  // --- STEP 1: Target ---
  Widget _buildTargetStep(ThemeData theme) {
    final currencySymbol = Provider.of<SettingsProvider>(
      context,
    ).currencySymbol;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Set your monthly budget",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'momo',
              fontSize: 24,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Based on your recent average of $currencySymbol${(_averageExpense / 1000).toStringAsFixed(1)}K,\nwe suggest aiming to save:",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.4,
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(constraints.maxWidth, 320.0);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: _ArcSlider(
                          value: _intensity / 0.5,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _intensity = val * 0.5;
                              final newBudget =
                                  _averageExpense * (1 - _intensity);
                              _budgetController.text = newBudget
                                  .toStringAsFixed(0);
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 140.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  currencySymbol,
                                  style: TextStyle(
                                    fontFamily: 'momo',
                                    fontSize: 48,
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
                                      final newBudget = double.tryParse(val);
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
                                      fontSize: 64,
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
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
                          const SizedBox(height: 50),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .extension<AppColors>()!
                                  .income
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "+${(_intensity * 100).toStringAsFixed(0)}% SAVINGS",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).extension<AppColors>()!.income,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _nextStep,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: Allocation with Smooth Reordering ---
  Widget _buildAllocationStep(ThemeData theme) {
    final currencySymbol = Provider.of<SettingsProvider>(
      context,
    ).currencySymbol;
    final globalStr = _budgetController.text.replaceAll(',', '');
    final globalBudget = double.tryParse(globalStr) ?? 0;

    final double remaining = globalBudget - _totalAllocated;
    final bool isOverAllocated = remaining < 0;

    return Column(
      children: [
        // New Sticky Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(color: theme.colorScheme.surface),
          child: Column(
            children: [
              Text(
                "Set your monthly category budgets",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'momo',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              // Segmented Progress Bar Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer.withValues(
                    alpha: 0.3,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    SegmentedProgressBar(
                      segments: [
                        Segment(
                          value: _totalAllocated,
                          color: theme.colorScheme.primary,
                        ),
                        Segment(
                          value: math.max(0.0, remaining),
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        if (isOverAllocated)
                          Segment(
                            value: remaining.abs(),
                            color: theme.colorScheme.error,
                          ),
                      ],
                      height: 8,
                      gap: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ALLOCATED",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$currencySymbol${_totalAllocated.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "TOTAL",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$currencySymbol${globalBudget.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOverAllocated
                                  ? "OVER ALLOCATED"
                                  : "NOT ALLOCATED",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$currencySymbol${remaining.abs().toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isOverAllocated
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Animated Sliders List
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: _sortedExpenseCats.length,
            // Disable manual drag-and-drop; we are using ReorderableListView purely
            // for its built-in smooth position animations when the list order changes in state.
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {},
            itemBuilder: (context, index) {
              final cat = _sortedExpenseCats[index];
              final amount = _categoryBudgets[cat.id] ?? 0.0;
              final otherAllocated = _totalAllocated - amount;
              final maxAllowed = math.max(0.0, globalBudget - otherAllocated);

              if (amount == 0 && index > 6)
                return SizedBox.shrink(key: ValueKey(cat.id));

              return _AnimatedCategorySlider(
                key: ValueKey(cat.id),
                category: cat,
                amount: amount,
                globalBudget: globalBudget,
                maxAllowed: maxAllowed,
                currencySymbol: currencySymbol,
                onChanged: (val) {
                  setState(() {
                    _categoryBudgets[cat.id] = val.roundToDouble();
                  });
                },
                onChangeEnd: (_) {
                  // Re-sort the list when they let go of the slider
                  _sortCategories(List.from(_sortedExpenseCats));
                },
              );
            },
          ),
        ),

        // Action Button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _finishSetup,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Text(
                "Activate Budget",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- EXTRACTED CATEGORY SLIDER WIDGET ---
class _AnimatedCategorySlider extends StatefulWidget {
  final CategoryModel category;
  final double amount;
  final double globalBudget;
  final double maxAllowed;
  final String currencySymbol;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _AnimatedCategorySlider({
    super.key,
    required this.category,
    required this.amount,
    required this.globalBudget,
    required this.maxAllowed,
    required this.currencySymbol,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_AnimatedCategorySlider> createState() =>
      _AnimatedCategorySliderState();
}

class _AnimatedCategorySliderState extends State<_AnimatedCategorySlider> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.amount.toStringAsFixed(0));
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onChangeEnd(widget.amount);
        if (_controller.text != widget.amount.toStringAsFixed(0)) {
          _controller.text = widget.amount.toStringAsFixed(0);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedCategorySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.amount != widget.amount) {
      _controller.text = widget.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: HugeIcon(
              icon: GoalIconRegistry.getIcon(widget.category.iconKey),
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.category.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.currencySymbol,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              final cleanStr = val.replaceAll(',', '');
                              final newAmt = double.tryParse(cleanStr) ?? 0.0;
                              widget.onChanged(newAmt);
                            },
                            onSubmitted: (val) {
                              _focusNode.unfocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TallSegmentedSlider(
                  value: widget.amount,
                  min: 0,
                  max: math.max(
                    math.max(1.0, widget.maxAllowed),
                    widget.amount,
                  ),
                  activeColor: theme.colorScheme.primary,
                  inactiveColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  trackHeight: 4.0,
                  thumbHeight: 18.0,
                  gap: 2.0,
                  onChanged: (val) {
                    widget.onChanged(val);
                    if (_focusNode.hasFocus) {
                      _focusNode.unfocus();
                    }
                  },
                  onChangeEnd: widget.onChangeEnd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ... Keep your _ArcSlider and _ArcPainter classes exactly as they were ...
class _ArcSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ArcSlider({required this.value, required this.onChanged});

  void _handleInteraction(BuildContext context, Offset localPosition) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset center = Offset(box.size.width / 2, box.size.height / 2);
    final Offset pos = localPosition - center;

    double angle = math.atan2(pos.dy, pos.dx);

    // Map angle into [0, 2*pi] where 0 is Right (Bottom-Right end)
    // and we sweep counter-clockwise to Left (Bottom-Left end).
    // Bottom-Right is at 0.25 * pi.
    double transformed = (0.25 * math.pi - angle) % (2 * math.pi);

    // Total sweep is 270 degrees = 1.5 * pi.
    const sweepRange = 1.5 * math.pi;

    double normalized;
    if (transformed > sweepRange) {
      // We are in the 90-degree "dead zone" at the bottom center.
      // Snap to whichever end is closer.
      normalized = (transformed > sweepRange + (2 * math.pi - sweepRange) / 2)
          ? 0.0
          : 1.0;
    } else {
      normalized = transformed / sweepRange;
    }

    onChanged(normalized.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 1. Explicitly claim Horizontal Drags to block parent TabBarView
      onHorizontalDragStart: (details) =>
          _handleInteraction(context, details.localPosition),
      onHorizontalDragUpdate: (details) =>
          _handleInteraction(context, details.localPosition),

      // 2. Explicitly claim Vertical Drags to handle full arc motion
      onVerticalDragStart: (details) =>
          _handleInteraction(context, details.localPosition),
      onVerticalDragUpdate: (details) =>
          _handleInteraction(context, details.localPosition),

      // 3. Handle simple taps
      onTapDown: (details) =>
          _handleInteraction(context, details.localPosition),

      child: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: CustomPaint(
          painter: _ArcPainter(
            value: value,
            colorScheme: Theme.of(context).colorScheme,
            appColors: Theme.of(context).extension<AppColors>()!,
          ),
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

    final trackPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Static track: 270 degrees from Bottom-Left (0.75 * pi) to Bottom-Right (0.25 * pi)
    // Sweeping clockwise (positive).
    canvas.drawArc(rect, 0.75 * math.pi, 1.5 * math.pi, false, trackPaint);

    final progressPaint = Paint()
      ..color = appColors.income
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Progress: Start at Bottom-Right (0.25 * pi) and sweep counter-clockwise (negative)
    // proportional to 'value'.
    canvas.drawArc(
      rect,
      0.25 * math.pi,
      -1.5 * math.pi * value,
      false,
      progressPaint,
    );

    // Thumb position (relative to Right End)
    final thumbAngle = 0.25 * math.pi - (1.5 * math.pi * value);
    final thumbPos = Offset(
      center.dx + radius * math.cos(thumbAngle),
      center.dy + radius * math.sin(thumbAngle),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(thumbPos, 24, shadowPaint);

    canvas.drawCircle(thumbPos, 18, Paint()..color = Colors.white);
    canvas.drawCircle(thumbPos, 7, Paint()..color = appColors.income);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.colorScheme != colorScheme;
}
