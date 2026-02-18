// ignore_for_file: unused_field

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/chart/custom_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/widgets/account_info_modal_sheet.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

class _MonthlySummary {
  final DateTime month;
  final double totalIncome; // Mapped to Repayments
  final double totalExpense; // Mapped to Purchases

  _MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class AccountIncomeDetailsScreen extends StatefulWidget {
  final Account account;

  const AccountIncomeDetailsScreen({super.key, required this.account});

  @override
  State<AccountIncomeDetailsScreen> createState() =>
      _AccountIncomeDetailsScreenState();
}

class _AccountIncomeDetailsScreenState
    extends State<AccountIncomeDetailsScreen> {
  List<TransactionModel> _accountTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _maxAmount = 0;
  double _maxIncome = 0; // Max Repayment
  double _maxExpense = 0; // Max Purchase
  double _meanIncome = 0; // Mean Repayment
  double _meanExpense = 0; // Mean Purchase
  double _totalCreditDue = 0;

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

    // Calculate total due for the entire account history
    double totalDue = 0;
    for (final tx in _accountTransactions) {
      if (tx.category == 'Credit Repayment') {
        // Repayments (from any type) decrease the due amount.
        totalDue -= tx.amount;
      } else if (tx.type == 'expense') {
        // Regular purchases increase the due amount.
        totalDue += tx.amount;
      } else if (tx.type == 'income') {
        // This handles refunds
        totalDue -= tx.amount;
      }
    }

    final summaries = groupedByMonth.entries.map((entry) {
      double purchases = 0;
      double repayments = 0;
      for (var tx in entry.value) {
        if (tx.category == 'Credit Repayment') {
          repayments += tx.amount;
        } else if (tx.type == 'expense') {
          purchases += tx.amount;
        } else if (tx.type == 'income') {
          // Refunds
          repayments += tx.amount;
        }
      }
      return _MonthlySummary(
        month: entry.key,
        totalIncome: repayments, // Mapped to 'income' for chart reuse
        totalExpense: purchases, // Mapped to 'expense' for chart reuse
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    if (summaries.isNotEmpty) {
      _maxIncome = summaries
          .map((s) => s.totalIncome)
          .reduce((a, b) => a > b ? a : b); // Max Repayment
      _maxExpense = summaries
          .map((s) => s.totalExpense)
          .reduce((a, b) => a > b ? a : b); // Max Purchase
      _maxAmount = _maxIncome > _maxExpense ? _maxIncome : _maxExpense;

      final totalRepaymentSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalIncome,
      );
      _meanIncome = totalRepaymentSum / summaries.length; // Mean Repayment

      final totalPurchaseSum = summaries.fold<double>(
        0.0,
        (sum, s) => sum + s.totalExpense,
      );
      _meanExpense = totalPurchaseSum / summaries.length; // Mean Purchase
    }

    setState(() {
      _totalCreditDue = totalDue;
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        _selectMonth(_monthlySummaries.last.month);
      } else {
        _displayTransactions = [];
      }
    });
  }

  Widget _buildCreditLimitBlock(Account currentAccount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final limit = currentAccount.creditLimit ?? 0.0;

    // Safety check
    if (limit <= 0) return const SizedBox.shrink();

    final used = _totalCreditDue;
    final available = limit - used;
    // Clamp utilization between 0.0 and 1.0 for visual safety
    final utilization = (used / limit).clamp(0.0, 1.0);

    // Logic: High utilization (> 75%) is "Bad" (Error color), otherwise "Good" (Primary color)
    final isHighUtilization = utilization > 0.75;
    final healthColor = isHighUtilization
        ? colorScheme.error
        : colorScheme.primary;
    // The "Empty" space color needs to be visible on the dark 'inverseSurface' background
    final emptyColor = colorScheme.onSurface.withAlpha(38);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CREDIT HEALTH",
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(178),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHighUtilization
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: healthColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHighUtilization ? "High Usage" : "Good",
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero: Available Credit
          Text(
            currencyFormat.format(available),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Available Limit",
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(130),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 12),

          // Visual Ratio Bar (SegmentedProgressBar)
          SegmentedProgressBar(
            height: 12,
            gap: 6,
            segments: [
              if (used > 0) Segment(value: used, color: healthColor),
              if (available > 0) Segment(value: available, color: emptyColor),
            ],
          ),

          const SizedBox(height: 16),

          // Footer Stats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "USED",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(used),
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 24,
                width: 1,
                color: colorScheme.onSurface.withAlpha(50),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL LIMIT",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(limit),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    // Keep your currencyFormat definition
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
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAccountInfo(currentAccount),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Credit Utilization Block (New, like Net Worth)
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 16),
                child: _buildCreditLimitBlock(currentAccount),
              ),
            ),

          // 2. Graph
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildGraphSection(currencyFormat)),

          // 3. Monthly Summary Card (Redesigned)
          if (_monthlySummaries.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard()),

          // 4. Transaction List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                // Dynamic header based on selection
                _selectedMonth != null
                    ? '${_displayTransactions.length} Transactions in ${DateFormat('MMM').format(_selectedMonth!)}'
                    : 'Transactions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 5. Grouped Transactions
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No transactions found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            _buildTransactionList(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  // --- REDESIGNED MONTHLY SUMMARY (Split Container Style) ---
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

    if (selectedSummary == null) return const SizedBox.shrink();

    // Map logic: Income = Payments, Expense = Spends
    final payments = selectedSummary.totalIncome;
    final spends = selectedSummary.totalExpense;
    // Net Change: Positive means we paid off more than we spent (Good)
    final netChange = payments - spends;
    final totalVolume = payments + spends;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MONTHLY ACTIVITY",
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
                    DateFormat('MMM yyyy').format(_selectedMonth!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hero Number
            Text(
              "Net Repayment",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currencyFormat.format(netChange),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: netChange >= 0 ? appColors.income : appColors.expense,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            // Visual Ratio Bar (SegmentedProgressBar)
            SegmentedProgressBar(
              height: 12,
              gap: 6,
              segments: [
                if (payments > 0)
                  Segment(value: payments, color: appColors.income),
                if (spends > 0)
                  Segment(value: spends, color: appColors.expense),
              ],
            ),

            if (totalVolume > 0) const SizedBox(height: 20),

            // Stats Columns
            Row(
              children: [
                // Payments
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
                            "PAYMENTS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(payments),
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
                  color: colors.outlineVariant.withOpacity(0.5),
                ),
                const SizedBox(width: 24),
                // Spends
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
                            "SPENDS",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(spends),
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
}
