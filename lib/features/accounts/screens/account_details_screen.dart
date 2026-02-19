// ignore_for_file: unused_field

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/chart/custom_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

import '../widgets/account_info_modal_sheet.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;

  _MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class AccountDetailsScreen extends StatefulWidget {
  final Account account;

  const AccountDetailsScreen({super.key, required this.account});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  List<TransactionModel> _accountTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxAmount = 0;
  double _maxIncome = 0;
  double _maxExpense = 0;
  double _meanIncome = 0;
  double _meanExpense = 0;

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
    _accountTransactions = allTransactions
        .where((tx) => tx.accountId == widget.account.id)
        .toList();

    if (_accountTransactions.isNotEmpty) {
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
      _displayTransactions = _accountTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _accountTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    final summaries = groupedByMonth.entries.map((entry) {
      final income = entry.value
          .where((tx) => tx.type == 'income')
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final expense = entry.value
          .where((tx) => tx.type == 'expense')
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return _MonthlySummary(
        month: entry.key,
        totalIncome: income,
        totalExpense: expense,
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b);
      _maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b);
      _maxAmount = _maxIncome > _maxExpense ? _maxIncome : _maxExpense;

      final totalIncomeSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalIncome,
      );
      _meanIncome = totalIncomeSum / summaries.length;

      final totalExpenseSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalExpense,
      );
      _meanExpense = totalExpenseSum / summaries.length;
    }

    setState(() {
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        _selectMonth(_monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  void _showAccountInfo(Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AccountInfoModalSheet(account: account, passedContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final currentAccount = accountProvider.accounts.firstWhere(
      (acc) => acc.id == widget.account.id,
      orElse: () => widget.account,
    );
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
            Text(currentAccount.bankName),
            const SizedBox(height: 4),
            Text(
              currentAccount.accountNumber,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            onPressed: () => _showAccountInfo(currentAccount),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                // Changed to show total transactions for the month
                _selectedMonth != null
                    ? '${_displayTransactions.length} Transactions in ${DateFormat('MMMM').format(_selectedMonth!)}'
                    : '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyReportPlaceholder(
                message: "Your transactions for this account will appear here.",
                icon: HugeIcons.strokeRoundedInvoice01,
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

    // Map your monthly summaries into the data format the new chart expects
    final chartData = _monthlySummaries.map((summary) {
      return CustomChartData(
        label: DateFormat('MMM \'yy').format(summary.month),
        barValue: summary.totalExpense, // Expenses as the Bars
        lineValue: summary.totalIncome, // Income as the Line
        barTooltip: currencyFormat.format(summary.totalExpense),
        lineTooltip: currencyFormat.format(summary.totalIncome),
      );
    }).toList();

    // Find the index of the currently selected month to highlight it
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

  Widget _buildSummaryCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final appColors = Theme.of(context).extension<AppColors>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selectedSummary = _monthlySummaries.firstWhereOrNull(
      (summary) => summary.month == _selectedMonth,
    );

    if (selectedSummary == null) {
      return const SizedBox.shrink();
    }

    final income = selectedSummary.totalIncome;
    final expense = selectedSummary.totalExpense;
    final balance = income - expense;
    final totalVolume = income + expense;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Using surfaceContainer for distinct card look
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MONTHLY OVERVIEW",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Hero Net Balance
            Text(
              "Net Balance",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currencyFormat.format(balance),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: balance >= 0 ? appColors.income : appColors.expense,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 24),

            // Visual Ratio Bar (SegmentedProgressBar)
            SegmentedProgressBar(
              height: 12,
              gap: 6,
              segments: [
                if (income > 0) Segment(value: income, color: appColors.income),
                if (expense > 0)
                  Segment(value: expense, color: appColors.expense),
              ],
            ),

            if (totalVolume > 0) const SizedBox(height: 20),

            // 4. Detailed Numbers
            Row(
              children: [
                // Income Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.income,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "INCOME",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(income),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 30,
                  width: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 24),
                // Expense Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: appColors.expense,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "EXPENSE",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(expense),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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

  // _groupTransactionsByDate removed
}
