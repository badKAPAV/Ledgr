import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wallzy/common/helpers/fading_divider.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/core/navigation/slide_up_route.dart';
import 'package:wallzy/core/utils/ledgr_max/paywall/paywall_features.dart';
import 'package:wallzy/core/utils/ledgr_max/paywall/paywall_interceptor.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/accounts/screens/add_edit_account_screen.dart';
import 'package:wallzy/features/accounts/widgets/edit_account_balance_sheet.dart';
import 'package:wallzy/features/transaction/screens/transactions_screen.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';
import 'package:wallzy/features/accounts/widgets/account_info_modal_sheet.dart';
import 'package:wallzy/app_drawer.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late PageController _pageController;
  int _selectedAccountIndex = 0;

  final Map<String, double> _cachedBalances = {};
  Account? _selectedWalletAccount;
  bool _hasUserSelectedAccount = false;
  bool _isFanMode = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_selectedAccountIndex != newIndex) {
        setState(() {
          _selectedAccountIndex = newIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final theme = Theme.of(context);

    if (accountProvider.isLoading || transactionProvider.isLoading) {
      return const _AccountsLoadingSkeleton();
    }

    // --- Sorting Logic ---
    List<Account> tempAccounts = [...accountProvider.accounts];
    List<Account> sortedAccounts = [];

    int primaryIndex = tempAccounts.indexWhere(
      (acc) => acc.isPrimary && acc.bankName.toLowerCase() != 'cash',
    );
    if (primaryIndex != -1) {
      sortedAccounts.add(tempAccounts.removeAt(primaryIndex));
    }

    Account? cashAccount;
    int cashIndex = tempAccounts.indexWhere(
      (acc) => acc.bankName.toLowerCase() == 'cash',
    );
    if (cashIndex != -1) cashAccount = tempAccounts.removeAt(cashIndex);

    tempAccounts.sort((a, b) => a.bankName.compareTo(b.bankName));
    sortedAccounts.addAll(tempAccounts);
    if (cashAccount != null) sortedAccounts.add(cashAccount);

    final allAccounts = sortedAccounts;

    if (!_hasUserSelectedAccount &&
        _selectedWalletAccount == null &&
        allAccounts.isNotEmpty) {
      _selectedWalletAccount = allAccounts.firstWhere(
        (acc) => acc.isPrimary,
        orElse: () => allAccounts.first,
      );
    }

    _cachedBalances.clear();
    double totalBalance = 0;
    double totalDue = 0;

    for (final account in allAccounts) {
      final balance = accountProvider.getBalanceForAccount(
        account,
        transactionProvider.transactions,
      );
      _cachedBalances[account.id] = balance;

      if (account.accountType == 'credit') {
        if (balance < 0) totalDue += -balance;
      } else {
        totalBalance += balance;
      }
    }
    final netWorth = totalBalance - totalDue;

    final recentTransactions = _selectedWalletAccount != null
        ? transactionProvider.transactions
              .where((tx) => tx.accountId == _selectedWalletAccount!.id)
              .take(20)
              .toList()
        : <TransactionModel>[];

    return Scaffold(
      drawer: const AppDrawer(selectedItem: DrawerItem.accounts, isRoot: false),
      appBar: AppBar(
        title: const Text('My Accounts'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: _WalletStackDashboard(
              accounts: allAccounts,
              selectedAccount: _selectedWalletAccount,
              netWorth: netWorth,
              totalAssets: totalBalance,
              totalDebt: totalDue,
              cachedBalances: _cachedBalances,
              onAccountSelected: (Account? selectedAccount) {
                setState(() {
                  _hasUserSelectedAccount = true;
                  _selectedWalletAccount = selectedAccount;
                });
              },
              onFanModeChanged: (isFanMode) {
                // Fan mode hides the transactions section below — handled via
                // _isFanMode flag passed down, which gates the sliver rendering.
                setState(() {
                  _isFanMode = isFanMode;
                });
              },
            ),
          ),

          if (!_isFanMode) ...[
            if (recentTransactions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RECENT ACTIVITY",
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FadingDivider(
                          thickness: 2,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                      ),
                      if (_selectedWalletAccount != null)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionsScreen(
                                  args: TransactionsScreenArgs(
                                    type:
                                        _selectedWalletAccount!.accountType ==
                                            'credit'
                                        ? TransactionScreenType.creditAccount
                                        : TransactionScreenType.account,
                                    account: _selectedWalletAccount,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'See All',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            if (recentTransactions.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyReportPlaceholder(
                  message: 'Your transactions will show up here!',
                  icon: HugeIcons.strokeRoundedWalletRemove02,
                ),
              )
            else
              GroupedTransactionList(
                transactions: recentTransactions,
                onTap: (tx) => _showTransactionDetails(context, tx),
                useSliver: true,
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildGlassFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildGlassFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PaywallInterceptor.execute(
              context: context,
              feature: PaywallFeature.userAccounts,
              currentCount: context.read<AccountProvider>().accounts.length,
              onAllowed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  SlideUpRoute(page: const AddEditAccountScreen()),
                );
              },
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Account",
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOADING SKELETON
// ---------------------------------------------------------------------------

class _AccountsLoadingSkeleton extends StatelessWidget {
  const _AccountsLoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainer,
      highlightColor: theme.colorScheme.surfaceContainerHighest,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 150,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              childCount: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WALLET STACK DASHBOARD — main widget with fan-mode animation
// ---------------------------------------------------------------------------

class _WalletStackDashboard extends StatefulWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final double netWorth;
  final double totalAssets;
  final double totalDebt;
  final Function(Account?) onAccountSelected;
  final Map<String, double> cachedBalances;
  final Function(bool isFanMode) onFanModeChanged;

  const _WalletStackDashboard({
    required this.accounts,
    this.selectedAccount,
    required this.netWorth,
    required this.totalAssets,
    required this.totalDebt,
    required this.onAccountSelected,
    required this.cachedBalances,
    required this.onFanModeChanged,
  });

  @override
  State<_WalletStackDashboard> createState() => _WalletStackDashboardState();
}

class _WalletStackDashboardState extends State<_WalletStackDashboard>
    with TickerProviderStateMixin {
  // ── Stack-mode state ──────────────────────────────────────────────────────
  int? _expandedIndex;
  int? _prevExpandedIndex;
  bool _isBalanceHidden = false;

  // ── Fan-mode animation ────────────────────────────────────────────────────
  late AnimationController _fanController;
  bool _isFanMode = false;

  // ── Select/deselect animation ─────────────────────────────────────────────
  late AnimationController _selectController;
  late Animation<double> _selectCurved;

  // Derived animations (set up in initState / didUpdateWidget)
  late Animation<double> _pocketSlideAnim; // pocket slides down
  late Animation<double> _pocketFadeAnim; // pocket fades out
  late Animation<double> _backTabFadeAnim; // "View All" tab fades out
  late Animation<double> _collapseButtonAnim; // collapse button fades in
  // Per-card fan animations are computed inline from _fanController.value.

  // ── Card colours (shared) ─────────────────────────────────────────────────
  final List<Color> _cardColors = [
    const Color(0xFFE65100),
    const Color(0xFFF6A000),
    const Color(0xFF37474F),
    const Color(0xFF2E7D32),
    const Color(0xFFC2185B),
    const Color(0xFF1565C0),
    const Color(0xFF6A1B9A),
    const Color(0xFF00695C),
  ];

  @override
  void initState() {
    super.initState();
    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _selectCurved = CurvedAnimation(
      parent: _selectController,
      curve: Curves.easeOutCubic,
    );

    _setupAnimations();

    // Sync initial expanded card with selectedAccount
    if (widget.selectedAccount != null) {
      final idx = _stackAccounts.indexWhere(
        (a) => a.id == widget.selectedAccount!.id,
      );
      if (idx != -1) {
        _expandedIndex = idx;
        _selectController.value = 1.0;
      }
    }
  }

  void _setupAnimations() {
    _pocketFadeAnim = CurvedAnimation(
      parent: _fanController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );
    _pocketSlideAnim = CurvedAnimation(
      parent: _fanController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeInCubic),
    );
    _backTabFadeAnim = CurvedAnimation(
      parent: _fanController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    );
    _collapseButtonAnim = CurvedAnimation(
      parent: _fanController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_WalletStackDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedAccount != oldWidget.selectedAccount &&
        widget.selectedAccount != null) {
      final index = _stackAccounts.indexWhere(
        (acc) => acc.id == widget.selectedAccount!.id,
      );
      if (index != -1 && index != _expandedIndex) {
        _animateSelectCard(index);
      }
    }
  }

  @override
  void dispose() {
    _fanController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  void _animateSelectCard(int? newIndex) {
    _prevExpandedIndex = _expandedIndex;
    _expandedIndex = newIndex;
    _selectController.forward(from: 0.0);
  }

  void _animateDeselectCard() {
    _prevExpandedIndex = _expandedIndex;
    _expandedIndex = null;
    _selectController.forward(from: 0.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// At most 5 accounts shown in the stack.
  List<Account> get _stackAccounts {
    final all = widget.accounts;
    if (all.length <= 5) return all;

    // Priority: primary first, cash last, up to 3 others in between.
    final List<Account> result = [];

    // 1. Primary
    final primary = all.firstWhere(
      (a) => a.isPrimary && a.bankName.toLowerCase() != 'cash',
      orElse: () => all.first,
    );
    result.add(primary);

    // 2. Up to 3 others (not primary, not cash)
    final others = all
        .where((a) => a.id != primary.id && a.bankName.toLowerCase() != 'cash')
        .take(3)
        .toList();
    result.addAll(others);

    // 3. Cash (if present)
    final cashList = all
        .where((a) => a.bankName.toLowerCase() == 'cash')
        .toList();
    if (cashList.isNotEmpty) result.add(cashList.first);

    return result.take(5).toList();
  }

  bool get _hasMoreThanFive => widget.accounts.length > 5;

  void _enterFanMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFanMode = true;
      _expandedIndex = null;
      _prevExpandedIndex = null;
      _selectController.value = 1.0;
    });
    widget.onFanModeChanged(true);
    _fanController.forward();
  }

  void _exitFanMode() {
    HapticFeedback.mediumImpact();
    _fanController.reverse().then((_) {
      if (mounted) {
        setState(() => _isFanMode = false);
        widget.onFanModeChanged(false);
      }
    });
  }

  // ── Layout constants ──────────────────────────────────────────────────────

  static const double _topMargin = 60.0;
  static const double _cardSpacing = 45.0;
  static const double _pocketHeight = 260.0;
  static const double _fanCardHeight = 88.0;
  static const double _fanCardSpacing = 12.0;
  static const double _fanTopPadding = 16.0;

  double get _pocketTop => _topMargin + (_stackAccounts.length * _cardSpacing);

  double get _stackHeight => _pocketTop + _pocketHeight;

  double _fanHeight(int totalCards) =>
      _fanTopPadding +
      (totalCards * (_fanCardHeight + _fanCardSpacing)) +
      80; // space for collapse button

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencyFormat = NumberFormat.currency(
      symbol: settingsProvider.currencySymbol,
      decimalDigits: 0,
    );
    final theme = Theme.of(context);

    final stackAccounts = _stackAccounts;
    final allAccounts = widget.accounts;
    final int totalCards = allAccounts.length;

    return AnimatedBuilder(
      animation: Listenable.merge([_fanController, _selectController]),
      builder: (context, _) {
        final t = _fanController.value; // 0 = stack, 1 = fan
        final selectT = _selectCurved.value; // 0 = old state, 1 = new state

        // Height interpolation
        final double currentHeight = lerpDouble(
          _stackHeight,
          _fanHeight(totalCards),
          t,
        )!;

        return SizedBox(
          height: currentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 1. BACK TAB ("View All") ─────────────────────────────────
              if (_hasMoreThanFive)
                Positioned(
                  top: 20.0,
                  left: 32,
                  right: 32,
                  height: 100,
                  child: FadeTransition(
                    opacity: ReverseAnimation(_backTabFadeAnim),
                    child: GestureDetector(
                      onTap: _enterFanMode,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "View All Cards",
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(10),
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: Text(
                                allAccounts.length.toString(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 2. ACCOUNT CARDS ─────────────────────────────────────────
              // In stack mode  → only stackAccounts are shown, stacked
              // In fan mode    → ALL accounts are shown, laid flat
              // During transition → cards animate between positions
              ..._buildCards(
                context,
                t,
                selectT,
                allAccounts,
                stackAccounts,
                currencyFormat,
                theme,
              ),

              // ── 3. WALLET POCKET ─────────────────────────────────────────
              Positioned(
                top: lerpDouble(_pocketTop, currentHeight + 40, t),
                left: 8,
                right: 8,
                bottom: 0,
                child: Opacity(
                  opacity: (1.0 - _pocketFadeAnim.value).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _pocketSlideAnim.value * 80),
                    child: GestureDetector(
                      onTap: () {
                        if (_expandedIndex != null) {
                          HapticFeedback.selectionClick();
                          _animateDeselectCard();
                          widget.onAccountSelected(null);
                        }
                      },
                      child: _WalletPocket(
                        netWorth: widget.netWorth,
                        totalAssets: widget.totalAssets,
                        totalDebt: widget.totalDebt,
                        isBalanceHidden: _isBalanceHidden,
                        currencyFormat: currencyFormat,
                        onToggleVisibility: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isBalanceHidden = !_isBalanceHidden);
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ── 4. COLLAPSE BUTTON (fan mode) ─────────────────────────────
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _collapseButtonAnim,
                  child: Center(
                    child: GestureDetector(
                      onTap: _exitFanMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCancelCircle,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Collapse All Cards",
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Card builder ──────────────────────────────────────────────────────────

  List<Widget> _buildCards(
    BuildContext context,
    double t, // fan animation progress 0..1
    double selectT, // select animation progress 0..1
    List<Account> allAccounts,
    List<Account> stackAccounts,
    NumberFormat currencyFormat,
    ThemeData theme,
  ) {
    final int n = stackAccounts.length;
    final int totalCards = allAccounts.length;
    // final screenWidth = MediaQuery.of(context).size.width;

    // For each account in allAccounts, compute its stack position (if it
    // appears in stackAccounts) and its fan position, then interpolate.

    final List<_CardLayoutData> layouts = [];

    for (int i = 0; i < totalCards; i++) {
      final account = allAccounts[i];
      final stackIdx = stackAccounts.indexWhere((a) => a.id == account.id);
      final isInStack = stackIdx != -1;

      // ── STACK position ────────────────────────────────────────────────────
      double stackTop;
      double stackLeft;
      double stackRight;
      double stackHeight;
      int stackZ;
      double stackOpacity;

      if (isInStack) {
        final idx = stackIdx;
        final double collapsedTop = _topMargin + (idx * _cardSpacing);

        // Compute the OLD position (from _prevExpandedIndex)
        double prevTop = collapsedTop;
        int prevZ = idx;
        if (_prevExpandedIndex != null) {
          final int kPrev = (idx - _prevExpandedIndex! + n) % n;
          prevZ = kPrev;
          if (kPrev == 0) {
            prevTop = 20.0;
          } else if (kPrev == 1) {
            prevTop = _pocketTop - _cardSpacing;
          } else {
            prevTop = _pocketTop + 50.0;
          }
        }

        // Compute the NEW position (from _expandedIndex)
        double newTop = collapsedTop;
        int newZ = idx;
        if (_expandedIndex != null) {
          final int kNew = (idx - _expandedIndex! + n) % n;
          newZ = kNew;
          if (kNew == 0) {
            newTop = 20.0;
          } else if (kNew == 1) {
            newTop = _pocketTop - _cardSpacing;
          } else {
            newTop = _pocketTop + 50.0;
          }
        }

        // Interpolate between prev and new based on selectT
        final double animTop = lerpDouble(prevTop, newTop, selectT)!;
        final int zIdx = lerpDouble(
          prevZ.toDouble(),
          newZ.toDouble(),
          selectT,
        )!.round();

        final double sideMargin = 24.0 - (idx * 4.0).clamp(0, 24);
        stackTop = animTop;
        stackLeft = sideMargin;
        stackRight = sideMargin;
        final double maxHeight = (_pocketTop + _pocketHeight) - animTop;
        stackHeight = (_pocketTop - animTop + 30).clamp(200.0, maxHeight);
        stackZ = zIdx;
        stackOpacity = 1.0;
      } else {
        // Not in stack — hide behind bottom of stack
        stackTop = _pocketTop + 60.0;
        stackLeft = 24.0;
        stackRight = 24.0;
        stackHeight = 200.0;
        stackZ = -1; // behind everything
        stackOpacity = 0.0;
      }

      // ── FAN position ──────────────────────────────────────────────────────
      final double fanTop =
          _fanTopPadding + i * (_fanCardHeight + _fanCardSpacing);
      const double fanLeft = 16.0;
      const double fanRight = 16.0;
      const double fanHeight = _fanCardHeight;
      const int fanZ = 0; // all same level in fan
      const double fanOpacity = 1.0;

      // ── Stagger offset: cards animate in sequence ─────────────────────────
      // Each card starts its animation slightly later (entering fan) or
      // slightly earlier (collapsing), creating a cascading effect.
      // Forward: top cards go first. Reverse: bottom cards go first.
      final double staggerIn = (i / totalCards) * 0.35;
      final double staggerOut = ((totalCards - 1 - i) / totalCards) * 0.35;

      final double tCard = _isFanMode
          ? ((t - staggerIn) / (1.0 - staggerIn)).clamp(0.0, 1.0)
          : ((t - staggerOut) / (1.0 - staggerOut)).clamp(0.0, 1.0);

      final double easedT = Curves.easeOutCubic.transform(tCard);

      layouts.add(
        _CardLayoutData(
          account: account,
          isInStack: isInStack,
          stackIdx: stackIdx,
          top: lerpDouble(stackTop, fanTop, easedT)!,
          left: lerpDouble(stackLeft, fanLeft, easedT)!,
          right: lerpDouble(stackRight, fanRight, easedT)!,
          height: lerpDouble(stackHeight, fanHeight, easedT)!,
          zIndex: lerpDouble(
            stackZ.toDouble(),
            fanZ.toDouble(),
            easedT,
          )!.round(),
          opacity: lerpDouble(stackOpacity, fanOpacity, easedT)!,
          isFanMode: easedT > 0.5,
          color: _cardColors[i % _cardColors.length],
          balance: widget.cachedBalances[account.id] ?? 0.0,
        ),
      );
    }

    // Sort by zIndex so higher zIndex paints on top
    layouts.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return layouts.map((layout) {
      final account = layout.account;
      final isCredit = account.accountType == 'credit';
      final isExpanded =
          layout.isInStack &&
          _expandedIndex == layout.stackIdx &&
          !_isFanMode &&
          selectT > 0.5;

      return Positioned(
        key: ValueKey(account.id),
        top: layout.top,
        left: layout.left,
        right: layout.right,
        height: layout.height,
        child: RepaintBoundary(
          child: Opacity(
            opacity: layout.opacity.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                if (_isFanMode || t > 0.5) {
                  // In fan mode — navigate to transactions
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionsScreen(
                        args: TransactionsScreenArgs(
                          type: isCredit
                              ? TransactionScreenType.creditAccount
                              : TransactionScreenType.account,
                          account: account,
                        ),
                      ),
                    ),
                  );
                } else if (layout.isInStack) {
                  // Stack mode
                  HapticFeedback.lightImpact();
                  if (isExpanded) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsScreen(
                          args: TransactionsScreenArgs(
                            type: isCredit
                                ? TransactionScreenType.creditAccount
                                : TransactionScreenType.account,
                            account: account,
                          ),
                        ),
                      ),
                    );
                  } else {
                    _animateSelectCard(layout.stackIdx);
                    widget.onAccountSelected(account);
                  }
                }
              },
              child: layout.isFanMode
                  ? _FanCard(
                      account: account,
                      balance: layout.balance,
                      color: layout.color,
                      currencyFormat: currencyFormat,
                      isBalanceHidden: _isBalanceHidden,
                      editAccountBalance: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => EditAccountBalanceModalSheet(
                            account: account,
                            passedContext: context,
                          ),
                        );
                      },
                    )
                  : _StackCard(
                      account: account,
                      balance: layout.balance,
                      color: layout.color,
                      currencyFormat: currencyFormat,
                      isBalanceHidden: _isBalanceHidden,
                      isExpanded: isExpanded,
                      pocketTop: _pocketTop,
                      cardSpacing: _cardSpacing,
                      onCollapseCard: () {
                        HapticFeedback.selectionClick();
                        _animateDeselectCard();
                        widget.onAccountSelected(null);
                      },
                      onInfoTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => AccountInfoModalSheet(
                            account: account,
                            passedContext: context,
                          ),
                        );
                      },
                      editAccountBalance: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => EditAccountBalanceModalSheet(
                            account: account,
                            passedContext: context,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Layout data transfer object
// ---------------------------------------------------------------------------

class _CardLayoutData {
  final Account account;
  final bool isInStack;
  final int stackIdx;
  final double top;
  final double left;
  final double right;
  final double height;
  final int zIndex;
  final double opacity;
  final bool isFanMode;
  final Color color;
  final double balance;

  const _CardLayoutData({
    required this.account,
    required this.isInStack,
    required this.stackIdx,
    required this.top,
    required this.left,
    required this.right,
    required this.height,
    required this.zIndex,
    required this.opacity,
    required this.isFanMode,
    required this.color,
    required this.balance,
  });
}

// ---------------------------------------------------------------------------
// STACK CARD — the tall overlapping card used in wallet-stack mode
// ---------------------------------------------------------------------------

class _StackCard extends StatelessWidget {
  final Account account;
  final double balance;
  final Color color;
  final NumberFormat currencyFormat;
  final bool isBalanceHidden;
  final bool isExpanded;
  final double pocketTop;
  final double cardSpacing;
  final VoidCallback onCollapseCard;
  final VoidCallback onInfoTap;
  final VoidCallback editAccountBalance;

  const _StackCard({
    required this.account,
    required this.balance,
    required this.color,
    required this.currencyFormat,
    required this.isBalanceHidden,
    required this.isExpanded,
    required this.pocketTop,
    required this.cardSpacing,
    required this.onCollapseCard,
    required this.onInfoTap,
    required this.editAccountBalance,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = account.accountType == 'credit';

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.bankName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (account.isPrimary) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${isCredit ? 'Credit' : 'Debit'} • •••• ${account.accountNumber}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Balance chip (top-right)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isCredit) ...[
                        Text(
                          isBalanceHidden
                              ? '****'
                              : currencyFormat.format(
                                  (account.creditLimit ?? 0) + balance,
                                ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Limit Remaining",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9,
                          ),
                        ),
                      ] else ...[
                        Text(
                          isBalanceHidden
                              ? '****'
                              : currencyFormat.format(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Expanded content
              if (isExpanded) ...[
                const Divider(height: 30, color: Colors.white12),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCredit ? "Outstanding" : "Total Balance",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isBalanceHidden
                                    ? '****'
                                    : currencyFormat.format(
                                        isCredit ? -balance : balance,
                                      ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (account.accountType != 'credit')
                                IconButton(
                                  tooltip: 'Edit account balance',
                                  onPressed: editAccountBalance,
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white70,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Show account info',
                                onPressed: onInfoTap,
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCircleArrowRight01,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "View account transactions",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          // Collapse button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onCollapseCard,
                                borderRadius: BorderRadius.circular(30),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HugeIcon(
                                        icon:
                                            HugeIcons.strokeRoundedCancelCircle,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Collapse card",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAN CARD — the compact flat tile used in fan/expanded mode
// ---------------------------------------------------------------------------

class _FanCard extends StatelessWidget {
  final Account account;
  final double balance;
  final Color color;
  final NumberFormat currencyFormat;
  final bool isBalanceHidden;
  final VoidCallback? editAccountBalance;

  const _FanCard({
    required this.account,
    required this.balance,
    required this.color,
    required this.currencyFormat,
    required this.isBalanceHidden,
    this.editAccountBalance,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = account.accountType == 'credit';

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Left: bank info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.bankName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account.isPrimary) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "${isCredit ? 'Credit' : 'Debit'} • •••• ${account.accountNumber}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Right: balance + arrow
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isBalanceHidden
                    ? '****'
                    : currencyFormat.format(isCredit ? -balance : balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isCredit ? "Outstanding" : "Balance",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (account.accountType != 'credit' &&
              editAccountBalance != null) ...[
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: editAccountBalance,
            ),
          ],

          const SizedBox(width: 10),

          // Chevron
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WALLET POCKET — the blue bottom container
// ---------------------------------------------------------------------------
class _WalletPocket extends StatelessWidget {
  final double netWorth;
  final double totalAssets;
  final double totalDebt;
  final bool isBalanceHidden;
  final NumberFormat currencyFormat;
  final VoidCallback onToggleVisibility;

  const _WalletPocket({
    required this.netWorth,
    required this.totalAssets,
    required this.totalDebt,
    required this.isBalanceHidden,
    required this.currencyFormat,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            Color.lerp(primary, Colors.black, 0.05)!,
            Color.lerp(primary, Colors.black, 0.15)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Embossed diagonal stripe texture at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 90,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              child: CustomPaint(
                painter: _DiagonalStripesPainter(color: onPrimary),
              ),
            ),
          ),

          // Sheen highlight at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    onPrimary.withValues(alpha: 0.12),
                    onPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Dashed stitch border
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: onPrimary),
              ),
            ),
          ),

          // Main content - Now uses Positioned.fill to take up the full height
          Positioned.fill(
            child: Padding(
              // Reduced bottom padding slightly to give the text room
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.max, // Force it to stretch
                children: [
                  // --- TOP SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "NET WORTH",
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isBalanceHidden
                                ? '****'
                                : currencyFormat.format(netWorth),
                            style: TextStyle(
                              color: onPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: onToggleVisibility,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: onPrimary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            color: onPrimary.withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            isBalanceHidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: onPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Flexible space between header and stats
                  const Spacer(flex: 2),

                  // --- MIDDLE SECTION ---
                  Column(
                    children: [
                      SegmentedProgressBar(
                        height: 6,
                        gap: 4,
                        borderRadius: BorderRadius.circular(4),
                        segments: [
                          if (totalAssets > 0)
                            Segment(value: totalAssets, color: onPrimary),
                          if (totalDebt > 0)
                            Segment(
                              value: totalDebt,
                              color: onPrimary.withValues(alpha: 0.18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCell(
                                onPrimary: onPrimary,
                                dotOpacity: 1.0,
                                label: "ASSETS",
                                value: isBalanceHidden
                                    ? '****'
                                    : currencyFormat.format(totalAssets),
                              ),
                            ),
                            VerticalDivider(
                              color: onPrimary.withValues(alpha: 0.2),
                              width: 1,
                              thickness: 1,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _StatCell(
                                onPrimary: onPrimary,
                                dotOpacity: 0.35,
                                label: "LIABILITIES",
                                value: isBalanceHidden
                                    ? '****'
                                    : currencyFormat.format(totalDebt),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Pushes the hint all the way to the bottom
                  const Spacer(flex: 3),

                  // --- BOTTOM SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: onPrimary.withValues(alpha: 0.4),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "COLLAPSE OPEN ACCOUNTS",
                        style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dashed stitch border painter
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(22),
    );

    const dashLen = 6.0, gapLen = 5.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dashLen), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// Diagonal subtle texture painter
class _DiagonalStripesPainter extends CustomPainter {
  final Color color;
  _DiagonalStripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.025)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width + size.height; x += 20) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// Card slot notch widget
// class _CardSlot extends StatelessWidget {
//   final double width;
//   const _CardSlot({required this.width});

//   @override
//   Widget build(BuildContext context) => Container(
//     width: width,
//     height: 10,
//     decoration: BoxDecoration(
//       gradient: LinearGradient(
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//         colors: [
//           Colors.black.withValues(alpha: 0.22),
//           Colors.black.withValues(alpha: 0.08),
//         ],
//       ),
//       borderRadius: const BorderRadius.only(
//         bottomLeft: Radius.circular(6),
//         bottomRight: Radius.circular(6),
//       ),
//     ),
//   );
// }

class _StatCell extends StatelessWidget {
  final Color onPrimary;
  final double dotOpacity;
  final String label, value;
  const _StatCell({
    required this.onPrimary,
    required this.dotOpacity,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 3,
            backgroundColor: onPrimary.withValues(alpha: dotOpacity),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.55),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: onPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
