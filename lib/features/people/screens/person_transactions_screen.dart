import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/chart/custom_chart.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

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

class PersonTransactionsScreen extends StatefulWidget {
  final Person person;
  final DateTime initialSelectedDate;
  final String transactionType; // 'income' or 'expense'

  const PersonTransactionsScreen({
    super.key,
    required this.person,
    required this.initialSelectedDate,
    required this.transactionType,
  });

  @override
  State<PersonTransactionsScreen> createState() =>
      _PersonTransactionsScreenState();
}

class _PersonTransactionsScreenState extends State<PersonTransactionsScreen> {
  List<TransactionModel> _allPersonTransactions = [];
  List<_MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];

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

    _allPersonTransactions = allTransactions.where((tx) {
      // Filter for all transactions associated with the specific person.
      final isPersonMatch =
          tx.people?.any((p) => p.id == widget.person.id) ?? false;
      return isPersonMatch;
    }).toList();

    if (_allPersonTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
      });
    }
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _allPersonTransactions,
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

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _allPersonTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
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
            Text(widget.person.fullName),
            const SizedBox(height: 4),
            Text(
              // Use the initial transaction type for the subtitle
              widget.transactionType == 'expense'
                  ? 'Payments Made'
                  : 'Payments Received',
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
              child: Text(
                '${_displayTransactions.length} Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_displayTransactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions with this person for the selected period.',
                ),
              ),
            )
          else
            _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildGraphSection(NumberFormat currencyFormat) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    final chartData = _monthlySummaries.map((summary) {
      return CustomChartData(
        label: DateFormat('MMM \'yy').format(summary.month),
        barValue: summary.totalExpense,
        lineValue: summary.totalIncome,
        barTooltip: currencyFormat.format(summary.totalExpense),
        lineTooltip: currencyFormat.format(summary.totalIncome),
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
