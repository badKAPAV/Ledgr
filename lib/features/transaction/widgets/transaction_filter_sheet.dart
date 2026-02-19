import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

// --- MAIN SHEET WIDGET ---
class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilter initialFilter;
  final Function(TransactionFilter) onApply;
  final VoidCallback onReset;

  const TransactionFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet>
    with TickerProviderStateMixin {
  // Filter State
  String _dateRangeType = 'this_month';
  DateTime? _startDate;
  DateTime? _endDate;

  // Price Logic
  final double _absMaxAmount = 100000;
  late RangeValues _currentPriceRange;

  // Selections
  List<String> _selectedCategories = [];
  List<String> _selectedAccountIds = [];
  List<String> _selectedPersonIds = [];
  List<String> _selectedTagIds = [];
  String _selectedType = 'expense';

  // Animation Controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeFilters() {
    final filter = widget.initialFilter;

    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _determineDateRangeType();

    double start = filter.minAmount ?? 0;
    double end = filter.maxAmount ?? _absMaxAmount;
    if (end > _absMaxAmount) end = _absMaxAmount;
    _currentPriceRange = RangeValues(start, end);

    if (filter.type != null) {
      _selectedType = filter.type!;
    }

    _selectedCategories = List.from(filter.categories ?? []);
    _selectedAccountIds = List.from(filter.accounts ?? []);
    _selectedPersonIds = filter.people?.map((p) => p.id).toList() ?? [];
    _selectedTagIds = filter.tags?.map((t) => t.id).toList() ?? [];
  }

  void _determineDateRangeType() {
    if (_startDate == null && _endDate == null) {
      _dateRangeType = 'all_time';
      return;
    }
    final now = DateTime.now();
    if (_startDate?.month == now.month && _startDate?.year == now.year) {
      _dateRangeType = 'this_month';
    } else {
      _dateRangeType = 'custom';
    }
  }

  void _setDateRange(String type) {
    if (type == 'custom') {
      _showCustomDateRangePicker();
      return;
    }

    setState(() {
      _dateRangeType = type;
      final now = DateTime.now();

      if (type == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        _endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
      } else if (type == 'this_week') {
        // Assuming Monday is the start of the week
        final difference = now.weekday - 1;
        final start = now.subtract(Duration(days: difference));
        final end = start.add(const Duration(days: 6));
        _startDate = DateTime(start.year, start.month, start.day);
        _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
      } else if (type == 'last_week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));
        final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6));
        _startDate = DateTime(
          startOfLastWeek.year,
          startOfLastWeek.month,
          startOfLastWeek.day,
        );
        _endDate = DateTime(
          endOfLastWeek.year,
          endOfLastWeek.month,
          endOfLastWeek.day,
          23,
          59,
          59,
        );
      } else if (type == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (type == 'last_month') {
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      } else if (type == 'this_year') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
      } else if (type == 'last_year') {
        _startDate = DateTime(now.year - 1, 1, 1);
        _endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
      } else if (type == 'all_time') {
        _startDate = null;
        _endDate = null;
      }
    });
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'Done',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              onPrimary: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _dateRangeType = 'custom';
        _startDate = result.start;
        _endDate = result.end.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );
      });
    }
  }

  void _apply() {
    final metaProvider = context.read<MetaProvider>();
    final peopleProvider = context.read<PeopleProvider>();

    final selectedTags = metaProvider.tags
        .where((t) => _selectedTagIds.contains(t.id))
        .toList();
    final selectedPeople = peopleProvider.people
        .where((p) => _selectedPersonIds.contains(p.id))
        .toList();

    double? min = _currentPriceRange.start > 0
        ? _currentPriceRange.start
        : null;
    double? max = _currentPriceRange.end < _absMaxAmount
        ? _currentPriceRange.end
        : null;

    final filter = TransactionFilter(
      startDate: _startDate,
      endDate: _endDate,
      minAmount: min,
      maxAmount: max,
      type: _selectedType,
      categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
      accounts: _selectedAccountIds.isNotEmpty ? _selectedAccountIds : null,
      tags: selectedTags.isNotEmpty ? selectedTags : null,
      people: selectedPeople.isNotEmpty ? selectedPeople : null,
    );

    widget.onApply(filter);
    Navigator.pop(context);
  }

  int _countActiveFilters() {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedAccountIds.isNotEmpty) count++;
    if (_selectedTagIds.isNotEmpty) count++;
    if (_selectedPersonIds.isNotEmpty) count++;
    if (_dateRangeType != 'all_time') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencySymbol = context.read<SettingsProvider>().currencySymbol;

    final allTransactions = context.read<TransactionProvider>().transactions;
    final filteredForGraph = allTransactions.where((t) {
      bool dateMatch = true;
      if (_startDate != null) dateMatch = !t.timestamp.isBefore(_startDate!);
      if (_endDate != null && dateMatch) {
        dateMatch = t.timestamp.isBefore(_endDate!);
      }

      bool typeMatch = t.type == _selectedType;
      bool categoryMatch =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(t.category);
      bool accountMatch =
          _selectedAccountIds.isEmpty ||
          (t.accountId != null && _selectedAccountIds.contains(t.accountId));

      bool tagMatch = true;
      if (_selectedTagIds.isNotEmpty) {
        tagMatch =
            t.tags?.any((tag) => _selectedTagIds.contains(tag.id)) ?? false;
      }

      bool personMatch = true;
      if (_selectedPersonIds.isNotEmpty) {
        personMatch =
            t.people?.any((person) => _selectedPersonIds.contains(person.id)) ??
            false;
      }

      return dateMatch &&
          typeMatch &&
          categoryMatch &&
          accountMatch &&
          tagMatch &&
          personMatch;
    }).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // --- Drag Handle ---
              _buildDragHandle(colorScheme),

              // --- Header ---
              _buildHeader(theme, colorScheme),

              const Divider(height: 1),

              // --- Content ---
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. Type Toggle with Hero Animation
                    _AnimatedSection(
                      delay: 0,
                      child: ModernSlidingToggle(
                        labels: const ['Expense', 'Income'],
                        selectedIndex: _selectedType == 'expense' ? 0 : 1,
                        onTabChanged: (index) {
                          final newType = index == 0 ? 'expense' : 'income';
                          if (newType != _selectedType) {
                            setState(() {
                              _selectedType = newType;
                              _selectedCategories.clear();
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 2. Filter Cards
                    _AnimatedSection(
                      delay: 100,
                      child: _buildFilterCard(
                        context,
                        icon: Icons.calendar_today_rounded,
                        label: "Date Range",
                        value: _getDateRangeLabel(),
                        onTap: () => _showDateSheet(context),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _AnimatedSection(
                      delay: 150,
                      child: _buildFilterCard(
                        context,
                        icon: Icons.category_rounded,
                        label: "Category",
                        value: _selectedCategories.isEmpty
                            ? "All"
                            : "${_selectedCategories.length} selected",
                        hasSelection: _selectedCategories.isNotEmpty,
                        onTap: () => _showSelectionSheet(
                          context,
                          "Select ${_selectedType == 'expense' ? 'Expense' : 'Income'} Categories",
                          _selectedType == 'expense'
                              ? TransactionCategories.expense
                              : TransactionCategories.income,
                          _selectedCategories,
                          (selected) =>
                              setState(() => _selectedCategories = selected),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _AnimatedSection(
                      delay: 200,
                      child: _buildFilterCard(
                        context,
                        icon: Icons.account_balance_rounded,
                        label: "Account",
                        value: _selectedAccountIds.isEmpty
                            ? "All"
                            : "${_selectedAccountIds.length} selected",
                        hasSelection: _selectedAccountIds.isNotEmpty,
                        onTap: () {
                          final accounts = context
                              .read<AccountProvider>()
                              .accounts;
                          _showSelectionSheet(
                            context,
                            "Select Accounts",
                            accounts.map((e) => e.bankName).toList(),
                            _selectedAccountIds,
                            (selectedIds) => setState(
                              () => _selectedAccountIds = selectedIds,
                            ),
                            optionIds: accounts.map((e) => e.id).toList(),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 3. Price Range Section
                    _AnimatedSection(
                      delay: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Price Range",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedType == 'income'
                                      ? theme
                                            .extension<AppColors>()!
                                            .income
                                            .withValues(alpha: 0.1)
                                      : theme
                                            .extension<AppColors>()!
                                            .expense
                                            .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${filteredForGraph.length} transactions",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _selectedType == 'income'
                                        ? theme.extension<AppColors>()!.income
                                        : theme.extension<AppColors>()!.expense,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Graph container - removed border, made it blend
                          Container(
                            height: 100,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: PriceDistributionChart(
                              transactions: filteredForGraph,
                              minRange: _currentPriceRange.start,
                              maxRange: _currentPriceRange.end,
                              color: _selectedType == 'income'
                                  ? theme.extension<AppColors>()!.income
                                  : theme.extension<AppColors>()!.expense,
                              maxCap: _absMaxAmount,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Modern Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _selectedType == 'income'
                                  ? theme.extension<AppColors>()!.income
                                  : theme.extension<AppColors>()!.expense,
                              inactiveTrackColor:
                                  colorScheme.surfaceContainerHighest,
                              thumbColor: _selectedType == 'income'
                                  ? theme.extension<AppColors>()!.income
                                  : theme.extension<AppColors>()!.expense,
                              overlayColor:
                                  (_selectedType == 'income'
                                          ? theme.extension<AppColors>()!.income
                                          : theme
                                                .extension<AppColors>()!
                                                .expense)
                                      .withValues(alpha: 0.2),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                                elevation: 4,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24,
                              ),
                            ),
                            child: RangeSlider(
                              values: _currentPriceRange,
                              min: 0,
                              max: _absMaxAmount,
                              onChanged: (values) =>
                                  setState(() => _currentPriceRange = values),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Price Input Boxes
                          Row(
                            children: [
                              Expanded(
                                child: ModernPriceInput(
                                  currencySymbol,
                                  _currentPriceRange.start,
                                  label: "Min",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ModernPriceInput(
                                  currencySymbol,
                                  _currentPriceRange.end,
                                  label: "Max",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // --- Bottom Bar with Glassmorphic Effect ---
              _buildBottomBar(context, colorScheme, filteredForGraph.length),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: Text(
          "Filter Actions",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool hasSelection = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: hasSelection
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasSelection
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.surface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: hasSelection
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasSelection)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Active",
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ColorScheme colorScheme,
    int resultCount,
  ) {
    final activeCount = _countActiveFilters();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Reset${activeCount > 0 ? ' ($activeCount)' : ''}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Show $resultCount Results",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateRangeLabel() {
    if (_dateRangeType == 'today') return 'Today';
    if (_dateRangeType == 'yesterday') return 'Yesterday';
    if (_dateRangeType == 'this_week') return 'This Week';
    if (_dateRangeType == 'last_week') return 'Last Week';
    if (_dateRangeType == 'this_month') return 'This Month';
    if (_dateRangeType == 'last_month') return 'Last Month';
    if (_dateRangeType == 'this_year') return 'This Year';
    if (_dateRangeType == 'last_year') return 'Last Year';
    if (_dateRangeType == 'custom' && _startDate != null) {
      return "${DateFormat('MMM d').format(_startDate!)}${_endDate != null ? " - ${DateFormat('MMM d').format(_endDate!)}" : ""}";
    }
    return 'All Time';
  }

  void _showDateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModernSelectionSheet(
        title: "Date Range",
        icon: Icons.calendar_today_rounded,
        items: [
          SelectionItem(
            title: "All Time",
            icon: Icons.all_inclusive_rounded,
            isSelected: _dateRangeType == 'all_time',
            onTap: () {
              _setDateRange('all_time');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Today",
            icon: Icons.today_rounded,
            isSelected: _dateRangeType == 'today',
            onTap: () {
              _setDateRange('today');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Yesterday",
            icon: Icons.history_rounded,
            isSelected: _dateRangeType == 'yesterday',
            onTap: () {
              _setDateRange('yesterday');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "This Week",
            icon: Icons.date_range_rounded,
            isSelected: _dateRangeType == 'this_week',
            onTap: () {
              _setDateRange('this_week');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Last Week",
            icon: Icons.history_rounded,
            isSelected: _dateRangeType == 'last_week',
            onTap: () {
              _setDateRange('last_week');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "This Month",
            icon: Icons.calendar_month_rounded,
            isSelected: _dateRangeType == 'this_month',
            onTap: () {
              _setDateRange('this_month');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Last Month",
            icon: Icons.calendar_today_rounded,
            isSelected: _dateRangeType == 'last_month',
            onTap: () {
              _setDateRange('last_month');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "This Year",
            icon: Icons.calendar_view_month_rounded,
            isSelected: _dateRangeType == 'this_year',
            onTap: () {
              _setDateRange('this_year');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Last Year",
            icon: Icons.history_rounded,
            isSelected: _dateRangeType == 'last_year',
            onTap: () {
              _setDateRange('last_year');
              Navigator.pop(ctx);
            },
          ),
          SelectionItem(
            title: "Custom Range",
            icon: Icons.date_range_rounded,
            isSelected: _dateRangeType == 'custom',
            onTap: () {
              Navigator.pop(ctx);
              _setDateRange('custom');
            },
          ),
        ],
      ),
    );
  }

  void _showSelectionSheet(
    BuildContext context,
    String title,
    List<String> options,
    List<String> currentSelection,
    Function(List<String>) onConfirm, {
    List<String>? optionIds,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiSelectionSheet(
        title: title,
        options: options,
        optionIds: optionIds,
        initialSelection: currentSelection,
        onConfirm: onConfirm,
      ),
    );
  }
}

// --- ANIMATED SECTION WIDGET ---
class _AnimatedSection extends StatefulWidget {
  final Widget child;
  final int delay;

  const _AnimatedSection({required this.child, required this.delay});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// --- MODERN SLIDING TOGGLE ---
class ModernSlidingToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final Function(int) onTabChanged;

  const ModernSlidingToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      child: Text(labels[index]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// --- MODERN PRICE INPUT ---
class ModernPriceInput extends StatelessWidget {
  final String symbol;
  final double value;
  final String label;

  const ModernPriceInput(
    this.symbol,
    this.value, {
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- PRICE DISTRIBUTION CHART (Improved) ---
class PriceDistributionChart extends StatelessWidget {
  final List<TransactionModel> transactions;
  final double minRange;
  final double maxRange;
  final Color color;
  final double maxCap;

  const PriceDistributionChart({
    super.key,
    required this.transactions,
    required this.minRange,
    required this.maxRange,
    required this.color,
    required this.maxCap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ModernDistributionPainter(
        amounts: transactions.map((e) => e.amount).toList(),
        minRange: minRange,
        maxRange: maxRange,
        color: color,
        maxCap: maxCap,
      ),
    );
  }
}

class _ModernDistributionPainter extends CustomPainter {
  final List<double> amounts;
  final double minRange;
  final double maxRange;
  final Color color;
  final double maxCap;

  _ModernDistributionPainter({
    required this.amounts,
    required this.minRange,
    required this.maxRange,
    required this.color,
    required this.maxCap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amounts.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    const int binCount = 40;
    final List<int> bins = List.filled(binCount, 0);
    final double binWidth = maxCap / binCount;

    int maxCount = 0;
    for (var amount in amounts) {
      if (amount >= maxCap) continue;
      int index = (amount / binWidth).floor();
      if (index >= 0 && index < binCount) {
        bins[index]++;
        if (bins[index] > maxCount) maxCount = bins[index];
      }
    }

    if (maxCount == 0) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Draw background gradient area
    _drawBackgroundArea(canvas, size, bins, maxCount, binCount);

    // Draw active range with gradient
    _drawActiveRange(canvas, size, bins, maxCount, binCount);

    // Draw grid lines
    _drawGridLines(canvas, size);
  }

  void _drawBackgroundArea(
    Canvas canvas,
    Size size,
    List<int> bins,
    int maxCount,
    int binCount,
  ) {
    final path = Path();
    final double stepX = size.width / (binCount - 1);

    path.moveTo(0, size.height);

    for (int i = 0; i < binCount; i++) {
      final double x = i * stepX;
      final double normalizedHeight = (bins[i] / maxCount) * size.height * 0.85;
      final double y = size.height - normalizedHeight;

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * stepX;
        final double prevY =
            size.height - ((bins[i - 1] / maxCount) * size.height * 0.85);
        final double controlX = prevX + (stepX / 2);
        path.cubicTo(controlX, prevY, controlX, y, x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawActiveRange(
    Canvas canvas,
    Size size,
    List<int> bins,
    int maxCount,
    int binCount,
  ) {
    final path = Path();
    final double stepX = size.width / (binCount - 1);

    path.moveTo(0, size.height);

    for (int i = 0; i < binCount; i++) {
      final double x = i * stepX;
      final double normalizedHeight = (bins[i] / maxCount) * size.height * 0.85;
      final double y = size.height - normalizedHeight;

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * stepX;
        final double prevY =
            size.height - ((bins[i - 1] / maxCount) * size.height * 0.85);
        final double controlX = prevX + (stepX / 2);
        path.cubicTo(controlX, prevY, controlX, y, x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    final startX = (minRange / maxCap) * size.width;
    final endX = (maxRange / maxCap) * size.width;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(startX, 0, endX, size.height));

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.2)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 0.3,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- MODERN SELECTION SHEET (Single Choice) ---
class SelectionItem {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  SelectionItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
}

class ModernSelectionSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<SelectionItem> items;

  const ModernSelectionSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (item.isSelected)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            )
                          else
                            const SizedBox(width: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: item.isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// --- MULTI SELECTION SHEET ---
class MultiSelectionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String>? optionIds;
  final List<String> initialSelection;
  final Function(List<String>) onConfirm;

  const MultiSelectionSheet({
    super.key,
    required this.title,
    required this.options,
    this.optionIds,
    required this.initialSelection,
    required this.onConfirm,
  });

  @override
  State<MultiSelectionSheet> createState() => _MultiSelectionSheetState();
}

class _MultiSelectionSheetState extends State<MultiSelectionSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.optionIds ?? widget.options;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text("Clear all"),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final isSelected = _selected.contains(ids[i]);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        isSelected
                            ? _selected.remove(ids[i])
                            : _selected.add(ids[i]);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.options[i],
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () {
                  widget.onConfirm(_selected);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selected.isEmpty ? "Select" : "Apply (${_selected.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
