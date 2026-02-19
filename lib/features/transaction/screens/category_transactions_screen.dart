import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/chart/custom_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalAmount;

  _MonthlySummary({required this.month, required this.totalAmount});
}

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryName;
  final String? categoryId; // Added categoryId
  final String categoryType;
  final DateTime initialSelectedDate;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryName,
    this.categoryId, // Added categoryId
    required this.categoryType,
    required this.initialSelectedDate,
  });

  @override
  State<CategoryTransactionsScreen> createState() =>
      _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState
    extends State<CategoryTransactionsScreen> {
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  List<TransactionModel> _allCategoryTransactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndProcessTransactions();
    });
  }

  void _loadAndProcessTransactions() {
    final allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;

    _allCategoryTransactions = allTransactions.where((tx) {
      final isTypeMatch = tx.type == widget.categoryType;
      if (!isTypeMatch) return false;

      if (widget.categoryId != null) {
        // If we have an ID, prioritize matching by ID
        if (tx.categoryId == widget.categoryId) return true;
        // Fallback: If transaction has no ID but name matches (legacy)
        if (tx.categoryId == null && tx.category == widget.categoryName)
          return true;
        return false;
      } else {
        // Legacy behavior: match by name
        return tx.category == widget.categoryName;
      }
    }).toList();

    if (_allCategoryTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
      });
    }
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _allCategoryTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  // _groupTransactionsByDate removed

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _allCategoryTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    final summaries = groupedByMonth.entries.map((entry) {
      final total = entry.value.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return _MonthlySummary(month: entry.key, totalAmount: total);
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    setState(() {
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        final initialMonthDate = DateTime(
          widget.initialSelectedDate.year,
          widget.initialSelectedDate.month,
        );
        final hasDataInInitialMonth = _monthlySummaries.any(
          (s) => s.month == initialMonthDate,
        );

        _selectMonth(
          hasDataInInitialMonth
              ? initialMonthDate
              : _monthlySummaries.last.month,
        );
      } else {
        _displayTransactions = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.categoryName),
            const SizedBox(height: 4),
            Text(
              widget.categoryType == 'expense' ? 'Expense' : 'Income',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_displayTransactions.length} Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions in this category for the selected period.',
                ),
              ),
            )
          else
            _buildTransactionList(),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isExpense = widget.categoryType == 'expense';

    final chartData = _monthlySummaries.map((summary) {
      return CustomChartData(
        label: DateFormat('MMM \'yy').format(summary.month),
        barValue: isExpense ? summary.totalAmount : 0,
        lineValue: isExpense ? 0 : summary.totalAmount,
        barTooltip: currencyFormat.format(isExpense ? summary.totalAmount : 0),
        lineTooltip: currencyFormat.format(isExpense ? 0 : summary.totalAmount),
      );
    }).toList();

    final selectedIdx = _monthlySummaries.indexWhere(
      (s) => s.month == _selectedMonth,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: CustomComboChart(
        data: chartData,
        selectedIndex: selectedIdx >= 0 ? selectedIdx : null,
        barColor: appColors.expense,
        lineColor: appColors.income,
        onSelectedIndexChanged: (index) {
          _selectMonth(_monthlySummaries[index].month);
        },
      ),
    );
  }

  Widget _buildTransactionList() {
    return GroupedTransactionList(
      transactions: _displayTransactions,
      onTap: (tx) => _showTransactionDetails(context, tx),
      useSliver: true,
    );
  }
}
