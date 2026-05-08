import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/chart/custom_chart.dart';
import 'package:wallzy/common/helpers/fading_divider.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/widgets/account_info_modal_sheet.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/recurring_payment/models/recurring_payment.dart';
import 'package:wallzy/features/recurring_payment/provider/recurring_payment_provider.dart';
import 'package:wallzy/features/recurring_payment/services/recurring_payment_info.dart';
import 'package:wallzy/features/recurring_payment/widgets/recurring_payment_info_modal_sheet.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';
import 'package:wallzy/features/transaction/widgets/transactions_screen/account_summary_card.dart';
import 'package:wallzy/features/transaction/widgets/transactions_screen/credit_account_summary_card.dart';
import 'package:wallzy/features/transaction/widgets/transactions_screen/credit_limit_block.dart';

class MonthlySummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;

  MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });
}

enum TransactionScreenType {
  category,
  subscription,
  account,
  creditAccount,
  person,
}

class TransactionsScreenArgs {
  final TransactionScreenType type;

  // Category arguments
  final String? categoryName;
  final String? categoryId;
  final String? categoryType;

  // Subscription arguments
  final Subscription? subscription;
  final List<TransactionModel>? subscriptionTransactions;

  // Account arguments
  final Account? account;

  // Person arguments
  final Person? person;
  final String? transactionType; // 'income' or 'expense'

  // Common
  final DateTime? initialSelectedDate;

  TransactionsScreenArgs({
    required this.type,
    this.categoryName,
    this.categoryId,
    this.categoryType,
    this.subscription,
    this.subscriptionTransactions,
    this.account,
    this.person,
    this.transactionType,
    this.initialSelectedDate,
  });
}

class TransactionsScreen extends StatefulWidget {
  final TransactionsScreenArgs args;

  const TransactionsScreen({super.key, required this.args});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> _allFilteredTransactions = [];
  List<MonthlySummary> _monthlySummaries = [];
  DateTime? _selectedMonth;
  List<TransactionModel> _displayTransactions = [];
  double _totalCreditDue = 0;
  bool _hideCreditTransactions = false;

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

    // 1. Filter Transactions based on type
    switch (widget.args.type) {
      case TransactionScreenType.category:
        _allFilteredTransactions = allTransactions.where((tx) {
          final isSameType = tx.type == widget.args.categoryType;
          final hasSameId =
              widget.args.categoryId != null &&
              tx.categoryId == widget.args.categoryId;
          final hasSameName = tx.category == widget.args.categoryName;
          return isSameType && (hasSameId || hasSameName);
        }).toList();
        break;
      case TransactionScreenType.subscription:
        _allFilteredTransactions = widget.args.subscriptionTransactions ?? [];
        break;
      case TransactionScreenType.account:
      case TransactionScreenType.creditAccount:
        _allFilteredTransactions = allTransactions
            .where((tx) => tx.accountId == widget.args.account?.id)
            .toList();
        break;
      case TransactionScreenType.person:
        _allFilteredTransactions = allTransactions.where((tx) {
          return tx.people?.any((p) => p.id == widget.args.person?.id) ?? false;
        }).toList();
        break;
    }

    if (_hideCreditTransactions) {
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );
      _allFilteredTransactions = _allFilteredTransactions.where((tx) {
        if (tx.accountId == null) return true;
        final account = accountProvider.accounts.firstWhereOrNull(
          (a) => a.id == tx.accountId,
        );
        return account?.accountType != 'credit';
      }).toList();
    }

    if (_allFilteredTransactions.isNotEmpty) {
      _processTransactions();
    } else {
      setState(() {
        _displayTransactions = [];
        _monthlySummaries = [];
      });
    }
  }

  void _processTransactions() {
    final groupedByMonth = groupBy(
      _allFilteredTransactions,
      (TransactionModel tx) => DateTime(tx.timestamp.year, tx.timestamp.month),
    );

    double totalDue = 0;
    if (widget.args.type == TransactionScreenType.creditAccount) {
      for (final tx in _allFilteredTransactions) {
        if (tx.category == 'Credit Repayment') {
          totalDue -= tx.amount;
        } else if (tx.type == 'expense') {
          totalDue += tx.amount;
        } else if (tx.type == 'income') {
          totalDue -= tx.amount;
        }
      }
    }

    final summaries = groupedByMonth.entries.map((entry) {
      double income = 0;
      double expense = 0;

      if (widget.args.type == TransactionScreenType.creditAccount) {
        for (var tx in entry.value) {
          if (tx.category == 'Credit Repayment') {
            income += tx.amount; // Mapped as Repayments
          } else if (tx.type == 'expense') {
            expense += tx.amount; // Mapped as Purchases
          } else if (tx.type == 'income') {
            income += tx.amount; // Refunds
          }
        }
      } else if (widget.args.type == TransactionScreenType.subscription) {
        expense = entry.value.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      } else {
        income = entry.value
            .where((tx) => tx.type == 'income')
            .fold<double>(0.0, (sum, tx) => sum + tx.amount);
        expense = entry.value
            .where((tx) => tx.type == 'expense')
            .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      }

      return MonthlySummary(
        month: entry.key,
        totalIncome: income,
        totalExpense: expense,
      );
    }).toList();

    summaries.sort((a, b) => a.month.compareTo(b.month));

    setState(() {
      _totalCreditDue = totalDue;
      _monthlySummaries = summaries;
      if (_monthlySummaries.isNotEmpty) {
        if (widget.args.initialSelectedDate != null) {
          final initialMonthDate = DateTime(
            widget.args.initialSelectedDate!.year,
            widget.args.initialSelectedDate!.month,
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
          _selectMonth(_monthlySummaries.last.month);
        }
      } else {
        _displayTransactions = [];
      }
    });
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _displayTransactions = _allFilteredTransactions.where((tx) {
        return tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month;
      }).toList();
    });
  }

  // Helper Methods for Subscription
  Subscription _getCurrentSubscription() {
    if (widget.args.subscription == null) {
      return Subscription(
        id: '',
        name: '',
        amount: 0,
        frequency: SubscriptionFrequency.monthly,
        nextDueDate: DateTime.now(),
        paymentMethod: '',
        category: '',
      );
    }
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    return provider.allSubscriptions.firstWhere(
      (s) => s.id == widget.args.subscription!.id,
      orElse: () => widget.args.subscription!,
    );
  }

  String _getCategoryName(Subscription sub) {
    if (sub.categoryId != null) {
      final category = context
          .read<CategoryProvider>()
          .categories
          .firstWhereOrNull((c) => c.id == sub.categoryId);
      if (category != null) return category.name;
    }
    return sub.category;
  }

  void _restoreSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: 'Restore Subscription?',
        description:
            'This will move the subscription back to your active list and re-enable payment reminders.',
        icon: HugeIcons.strokeRoundedRotate01,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              "Restore",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              provider.restoreSubscription(widget.args.subscription!.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _resumeSubscription() {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final currentObj = _getCurrentSubscription();
    provider.updateSubscription(
      currentObj.copyWith(pauseState: SubscriptionPauseState.active),
    );
  }

  void _showSubscriptionInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SubscriptionInfoModalSheet(subscription: _getCurrentSubscription()),
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

  List<Widget> _buildCommonActions() {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.more_vert_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ),
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (value) {
          HapticFeedback.lightImpact();

          if (value == 'toggle_credit') {
            setState(() {
              _hideCreditTransactions = !_hideCreditTransactions;
              _loadAndProcessTransactions();
            });
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'toggle_credit',
            child: Row(
              children: [
                Icon(
                  _hideCreditTransactions
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  _hideCreditTransactions
                      ? 'Show credit transactions'
                      : 'Hide credit transactions',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),
    ];
  }

  // App Bar Builder
  PreferredSizeWidget _buildAppBar() {
    // Helper to build the "Button Style" title
    Widget buildTappableTitle({
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return UnconstrainedBox(
        // Prevents the button from stretching to full width
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons
                        .info_outline_rounded, // Better visual distinction from back arrow
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    switch (widget.args.type) {
      case TransactionScreenType.category:
        return AppBar(
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.args.categoryName ?? 'Category'),
              Text(
                widget.args.categoryType == 'expense' ? 'Expense' : 'Income',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: _buildCommonActions(),
        );

      case TransactionScreenType.subscription:
        final currentSub = _getCurrentSubscription();
        return AppBar(
          surfaceTintColor: Colors.transparent,
          title: buildTappableTitle(
            title: currentSub.name,
            subtitle: _getCategoryName(currentSub),
            onTap: _showSubscriptionInfoModal,
          ),
          actions: _buildCommonActions(),
        );

      case TransactionScreenType.account:
      case TransactionScreenType.creditAccount:
        final accountProvider = Provider.of<AccountProvider>(context);
        final currentAccount = accountProvider.accounts.firstWhere(
          (acc) => acc.id == widget.args.account?.id,
          orElse: () => widget.args.account!,
        );
        return AppBar(
          surfaceTintColor: Colors.transparent,
          title: buildTappableTitle(
            title: currentAccount.bankName,
            subtitle: currentAccount.accountNumber,
            onTap: () => _showAccountInfo(currentAccount),
          ),
          actions: _buildCommonActions(),
        );

      case TransactionScreenType.person:
        return AppBar(
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.args.person?.fullName ?? ''),
              Text(
                widget.args.transactionType == 'expense'
                    ? 'Payments Made'
                    : 'Payments Received',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: _buildCommonActions(),
        );
    }
  }

  // Header Builder
  Widget _buildListHeader() {
    final theme = Theme.of(context);

    if (widget.args.type == TransactionScreenType.subscription) {
      final currentSubscription = _getCurrentSubscription();
      final isPaused =
          currentSubscription.pauseState != SubscriptionPauseState.active;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _displayTransactions.length == 1
                  ? '1 Payment'
                  : '${_displayTransactions.length} Payments',
              style: theme.textTheme.titleLarge,
            ),
            const Spacer(),
            if (isPaused)
              ActionChip(
                avatar: Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                label: const Text('Paused'),
                onPressed: _resumeSubscription,
              ),
          ],
        ),
      );
    }

    if (widget.args.type == TransactionScreenType.person) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          '${_displayTransactions.length} Transactions',
          style: theme.textTheme.titleLarge,
        ),
      );
    }

    // Default header with fading divider (Accounts, Category)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            _selectedMonth != null
                ? '${_displayTransactions.length} TRANSACTIONS IN ${DateFormat('MMM').format(_selectedMonth!).toUpperCase()}'
                : 'TRANSACTIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FadingDivider(
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              thickness: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.args.type == TransactionScreenType.subscription) {
      return const EmptyReportPlaceholder(
        message: 'Payments for this recurring will appear here.',
        icon: HugeIcons.strokeRoundedRotate02,
      );
    }
    if (widget.args.type == TransactionScreenType.account ||
        widget.args.type == TransactionScreenType.creditAccount) {
      return const EmptyReportPlaceholder(
        message: "Your transactions for this account will appear here.",
        icon: HugeIcons.strokeRoundedInvoice01,
      );
    }
    if (widget.args.type == TransactionScreenType.person) {
      return const Center(
        child: Text(
          'No transactions with this person for the selected period.',
        ),
      );
    }
    return const Center(
      child: Text(
        'No transactions found for the selected period.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, child) {
        Subscription? currentSubscription;
        bool isPaused = false;
        bool isArchived = false;

        if (widget.args.type == TransactionScreenType.subscription &&
            widget.args.subscription != null) {
          currentSubscription = subProvider.subscriptions.firstWhere(
            (s) => s.id == widget.args.subscription!.id,
            orElse: () => widget.args.subscription!,
          );
          isPaused =
              currentSubscription.pauseState != SubscriptionPauseState.active;
          isArchived = !currentSubscription.isActive;
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: CustomScrollView(
            slivers: [
              // Credit Limit Block (Only for Credit Accounts)
              if (widget.args.type == TransactionScreenType.creditAccount &&
                  _monthlySummaries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 16),
                    child: CreditLimitBlock(
                      account: widget.args.account!,
                      totalCreditDue: _totalCreditDue,
                    ),
                  ),
                ),

              // Graph Section
              if (_monthlySummaries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: CustomComboChart(
                      data: _monthlySummaries.map((summary) {
                        return CustomChartData(
                          label: summary.month.year == DateTime.now().year
                              ? DateFormat('MMM').format(summary.month)
                              : DateFormat("MMM ''yy").format(summary.month),
                          barValue:
                              widget.args.type ==
                                  TransactionScreenType.subscription
                              ? summary.totalExpense
                              : summary.totalExpense,
                          lineValue:
                              widget.args.type ==
                                      TransactionScreenType.category &&
                                  widget.args.categoryType == 'income'
                              ? summary.totalIncome
                              : widget.args.type ==
                                    TransactionScreenType.subscription
                              ? 0
                              : summary.totalIncome,
                          barTooltip: currencyFormat.format(
                            widget.args.type ==
                                        TransactionScreenType.category &&
                                    widget.args.categoryType == 'income'
                                ? summary.totalIncome
                                : summary.totalExpense,
                          ),
                          lineTooltip:
                              widget.args.type ==
                                  TransactionScreenType.subscription
                              ? ''
                              : currencyFormat.format(summary.totalIncome),
                        );
                      }).toList(),
                      selectedIndex:
                          _monthlySummaries.indexWhere(
                                (s) => s.month == _selectedMonth,
                              ) >=
                              0
                          ? _monthlySummaries.indexWhere(
                              (s) => s.month == _selectedMonth,
                            )
                          : null,
                      barColor:
                          widget.args.type == TransactionScreenType.category &&
                              widget.args.categoryType == 'income'
                          ? appColors.income
                          : appColors.expense,
                      lineColor:
                          widget.args.type == TransactionScreenType.category &&
                              widget.args.categoryType == 'income'
                          ? appColors.income
                          : appColors.income,
                      onSelectedIndexChanged: (index) {
                        _selectMonth(_monthlySummaries[index].month);
                      },
                    ),
                  ),
                ),

              // Summary Cards
              if (_monthlySummaries.isNotEmpty &&
                  widget.args.type == TransactionScreenType.account)
                SliverToBoxAdapter(
                  child: AccountSummaryCard(
                    selectedMonth: _selectedMonth!,
                    summary: _monthlySummaries.firstWhere(
                      (s) => s.month == _selectedMonth,
                    ),
                  ),
                ),
              if (_monthlySummaries.isNotEmpty &&
                  widget.args.type == TransactionScreenType.creditAccount)
                SliverToBoxAdapter(
                  child: CreditAccountSummaryCard(
                    selectedMonth: _selectedMonth!,
                    summary: _monthlySummaries.firstWhere(
                      (s) => s.month == _selectedMonth,
                    ),
                  ),
                ),

              // List Header
              if (_displayTransactions.isNotEmpty ||
                  widget.args.type == TransactionScreenType.account ||
                  widget.args.type == TransactionScreenType.creditAccount)
                SliverToBoxAdapter(child: _buildListHeader()),

              // Transaction List
              if (_displayTransactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                GroupedTransactionList(
                  transactions: _displayTransactions,
                  onTap: (tx) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TransactionDetailScreen(transaction: tx),
                    );
                  },
                  useSliver: true,
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar:
              (widget.args.type == TransactionScreenType.subscription &&
                  (isPaused || isArchived))
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    icon: Icon(
                      isArchived
                          ? Icons.settings_backup_restore_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      isArchived
                          ? 'Restore Subscription'
                          : 'Resume Subscription',
                    ),
                    onPressed: isArchived
                        ? _restoreSubscription
                        : _resumeSubscription,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
