import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

// --- APP IMPORTS (Adjust paths if necessary) ---
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/category_transactions_screen.dart';
import 'package:wallzy/common/widgets/date_filter_selector.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/common/widgets/animated_gauge_chart.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

// --- DATA MODEL ---
class CategorySummary {
  final String name;
  final double totalAmount;
  final int transactionCount;
  final String type;

  CategorySummary({
    required this.name,
    required this.totalAmount,
    required this.transactionCount,
    required this.type,
  });
}

class CategoriesTabScreen extends StatefulWidget {
  const CategoriesTabScreen({super.key});

  @override
  State<CategoriesTabScreen> createState() => _CategoriesTabScreenState();
}

class _CategoriesTabScreenState extends State<CategoriesTabScreen> {
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String _selectedType = 'expense';
  List<int> _availableYears = [];
  FilterResult? _filterResult;
  Map<String, CategorySummary> _categorySummaries = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    if (allTransactions.isNotEmpty) {
      final years = allTransactions
          .map((tx) => tx.timestamp.year)
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a));
      _availableYears = years;
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    } else {
      _availableYears = [_selectedYear];
    }
    _runFilter();
  }

  void _runFilter() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final range = _getFilterRange();
    final filter = TransactionFilter(
      startDate: range.start,
      endDate: range.end.add(const Duration(days: 1)),
    );
    final result = provider.getFilteredResults(filter);

    // Filter out internal transfers for analysis
    final analysisTransactions = result.transactions.where((tx) {
      final isInternal =
          tx.category == 'Transfer' || tx.category == 'Credit Repayment';
      return !isInternal;
    }).toList();

    final summaries = _calculateCategorySummaries(analysisTransactions);

    // Handle transfer exclusion from totals
    double debitToDebitTransfers = 0;
    for (var tx in result.transactions) {
      if (tx.type == 'income' && tx.category == 'Transfer') {
        debitToDebitTransfers += tx.amount;
      }
    }

    final totalExpenseForSelector = result.totalExpense - debitToDebitTransfers;
    final totalIncomeForSelector = result.totalIncome - debitToDebitTransfers;

    setState(() {
      _filterResult = FilterResult(
        transactions: result.transactions,
        totalExpense: totalExpenseForSelector,
        totalIncome: totalIncomeForSelector,
      );
      _categorySummaries = summaries;
    });
  }

  Map<String, CategorySummary> _calculateCategorySummaries(
    List<TransactionModel> transactions,
  ) {
    final Map<String, List<TransactionModel>> groupedByCategoryAndType = {};
    for (var tx in transactions) {
      final key = '${tx.category}_${tx.type}';
      (groupedByCategoryAndType[key] ??= []).add(tx);
    }

    final Map<String, CategorySummary> summaries = {};
    groupedByCategoryAndType.forEach((key, txList) {
      final total = txList.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final firstTx = txList.first;
      summaries[key] = CategorySummary(
        name: firstTx.category,
        totalAmount: total,
        transactionCount: txList.length,
        type: firstTx.type,
      );
    });
    return summaries;
  }

  DateTimeRange _getFilterRange() {
    if (_selectedMonth != null) {
      final firstDay = DateTime(_selectedYear, _selectedMonth!, 1);
      final lastDay = (_selectedMonth == 12)
          ? DateTime(_selectedYear + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(
              _selectedYear,
              _selectedMonth! + 1,
              1,
            ).subtract(const Duration(days: 1));
      return DateTimeRange(start: firstDay, end: lastDay);
    } else {
      return DateTimeRange(
        start: DateTime(_selectedYear, 1, 1),
        end: DateTime(_selectedYear, 12, 31),
      );
    }
  }

  Future<Map<int, String>> _fetchMonthlyStats(int year) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    Map<int, String> stats = {};
    for (int month = 1; month <= 12; month++) {
      final range = DateTimeRange(
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
      );
      final filter = TransactionFilter(
        startDate: range.start,
        endDate: range.end.add(const Duration(days: 1)),
        type: _selectedType,
      );
      final result = provider.getFilteredResults(filter);
      final total = _selectedType == 'expense'
          ? result.totalExpense
          : result.totalIncome;

      if (total > 0) {
        stats[month] = currencyFormat.format(total);
      }
    }
    return stats;
  }

  void _showDateFilterModal() {
    showDateFilterModal(
      context: context,
      availableYears: _availableYears,
      initialYear: _selectedYear,
      initialMonth: _selectedMonth,
      onApply: (year, month) {
        setState(() {
          _selectedYear = year;
          _selectedMonth = month;
        });
        _runFilter();
      },
      onStatsRequired: _fetchMonthlyStats,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_filterResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentTypeSummaries =
        _categorySummaries.values.where((s) => s.type == _selectedType).toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final totalForPieChart = currentTypeSummaries.fold<double>(
      0.0,
      (sum, summary) => sum + summary.totalAmount,
    );

    // Empty State
    if (_categorySummaries.isEmpty && currentTypeSummaries.isEmpty) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Center(
                child: DateNavigationControl(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  onTapPill: _showDateFilterModal,
                  onDateChanged: (year, month) {
                    setState(() {
                      _selectedYear = year;
                      _selectedMonth = month;
                    });
                    _runFilter();
                  },
                ),
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyReportPlaceholder(
              message: "No transactions found",
              icon: HugeIcons.strokeRoundedAnalytics01,
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Date Pill
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            child: Center(
              child: DateNavigationControl(
                selectedYear: _selectedYear,
                selectedMonth: _selectedMonth,
                onTapPill: _showDateFilterModal,
                onDateChanged: (year, month) {
                  setState(() {
                    _selectedYear = year;
                    _selectedMonth = month;
                  });
                  _runFilter();
                },
              ),
            ),
          ),
        ),

        // 2. The Custom Semi-Circle Chart Pod
        if (currentTypeSummaries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
              child: _ChartDashboardPod(
                summaries: currentTypeSummaries,
                totalAmount: totalForPieChart,
                selectedType: _selectedType,
              ),
            ),
          ),

        // 3. Segmented Control
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _SegmentedTypeSelector(
              selectedType: _selectedType,
              totalExpense: _filterResult!.totalExpense,
              totalIncome: _filterResult!.totalIncome,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
            ),
          ),
        ),

        // 4. Breakdown Header
        if (currentTypeSummaries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'BREAKDOWN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),

        // 5. Funky List Items (RESTORED)
        if (currentTypeSummaries.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final summary = currentTypeSummaries[index];
              return _FunkyCategoryTile(
                summary: summary,
                totalForPeriod: totalForPieChart,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryTransactionsScreen(
                        categoryName: summary.name,
                        categoryType: summary.type,
                        initialSelectedDate: DateTime(
                          _selectedYear,
                          _selectedMonth ?? DateTime.now().month,
                        ),
                      ),
                    ),
                  );
                },
              );
            }, childCount: currentTypeSummaries.length),
          ),

        // Bottom Padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// --- WIDGETS ---

// 2. Dashboard Pod using the Custom Painter (NEW)
class _ChartDashboardPod extends StatelessWidget {
  final List<CategorySummary> summaries;
  final double totalAmount;
  final String selectedType;

  const _ChartDashboardPod({
    required this.summaries,
    required this.totalAmount,
    required this.selectedType,
  });

  Color _getColorForCategory(String category) {
    final hash = category.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromARGB(
      255,
      (r + 100) % 256,
      (g + 100) % 256,
      (b + 100) % 256,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: settingsProvider.currencySymbol,
      decimalDigits: 0,
    );

    final hasData = summaries.isNotEmpty && totalAmount > 0;
    // Show top 4 categories in legend
    final topSummaries = summaries.take(4).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          if (hasData)
            // Explicitly sized container for the chart
            // Width = 280, Height = 140 (Half width) for perfect semi-circle
            SizedBox(
              height: 140,
              width: 280,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedGaugeChart(
                    items: summaries
                        .map(
                          (s) => GaugeChartItem(
                            label: s.name,
                            amount: s.totalAmount,
                          ),
                        )
                        .toList(),
                    totalAmount: totalAmount,
                    gapDegrees: 2, // Gap size
                    useRoundedEdges: false, // Rounded caps
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyFormat.format(totalAmount),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            fontSize: 32,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Total ${selectedType == 'expense' ? 'Spend' : 'Income'}",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  "No Data",
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Legend (Grid Style)
          if (hasData)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: topSummaries.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getColorForCategory(s.name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currencyFormat.format(s.totalAmount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// 3. Segmented Selector (RESTORED)
class _SegmentedTypeSelector extends StatelessWidget {
  final String selectedType;
  final double totalIncome;
  final double totalExpense;
  final ValueChanged<String> onTypeSelected;

  const _SegmentedTypeSelector({
    required this.selectedType,
    required this.totalIncome,
    required this.totalExpense,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = selectedType == 'expense';

    return Container(
      height: 56, // Fixed height for consistent sliding
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Sliding Background
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            alignment: isExpense ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content Buttons
          Row(
            children: [
              _SegmentButtonContent(
                label: "Expense",
                amount: totalExpense,
                isSelected: isExpense,
                onTap: () => onTypeSelected('expense'),
              ),
              _SegmentButtonContent(
                label: "Income",
                amount: totalIncome,
                isSelected: !isExpense,
                onTap: () => onTypeSelected('income'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 4. Button Content for Segmented Selector (RESTORED)
class _SegmentButtonContent extends StatelessWidget {
  final String label;
  final double amount;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButtonContent({
    required this.label,
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final isExpense = label.toLowerCase() == 'expense';

    final iconColor = isSelected
        ? (isExpense ? Colors.red : Colors.green)
        : theme.colorScheme.onSurfaceVariant;

    final textColor = isSelected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    final amountColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withAlpha(179);

    final icon = isExpense ? Icons.call_made : Icons.call_received;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isExpense
                            ? Colors.red.withAlpha(30)
                            : Colors.green.withAlpha(30))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 5. Funky Category Tile (RESTORED)
class _FunkyCategoryTile extends StatelessWidget {
  final CategorySummary summary;
  final double totalForPeriod;
  final VoidCallback onTap;

  const _FunkyCategoryTile({
    required this.summary,
    required this.totalForPeriod,
    required this.onTap,
  });

  IconData _getIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food')) return Icons.lunch_dining_rounded;
    if (c.contains('shop')) return Icons.shopping_bag_rounded;
    if (c.contains('transport')) return Icons.directions_car_rounded;
    if (c.contains('bill')) return Icons.receipt_long_rounded;
    if (c.contains('entertainment')) return Icons.movie_filter_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final percentage = (summary.totalAmount / totalForPeriod);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Icon Bubble
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIcon(summary.name),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          summary.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          currencyFormat.format(summary.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedProgressBar(
                            height: 6,
                            gap: 4.0,
                            borderRadius: BorderRadius.circular(3),
                            segments: [
                              Segment(
                                value: summary.totalAmount,
                                color: summary.type == 'expense'
                                    ? theme.extension<AppColors>()!.expense
                                    : theme.extension<AppColors>()!.income,
                              ),
                              if (summary.totalAmount < totalForPeriod)
                                Segment(
                                  value: totalForPeriod - summary.totalAmount,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${(percentage * 100).toStringAsFixed(1)}%",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${summary.transactionCount} transactions",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
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
}
