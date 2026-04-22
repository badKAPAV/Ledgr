import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

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

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
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

  @override
  void initState() {
    super.initState();
    _initializeFilters();
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

  void _setDateRange(String type) async {
    if (type == 'custom') {
      await _showCustomDateRangePicker();
      return;
    }

    setState(() {
      _dateRangeType = type;
      final now = DateTime.now();

      if (type == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'this_week') {
        final difference = now.weekday - 1;
        final start = now.subtract(Duration(days: difference));
        final end = start.add(const Duration(days: 6));
        _startDate = DateTime(start.year, start.month, start.day);
        _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
      } else if (type == 'this_month') {
        final settings = context.read<SettingsProvider>();
        final range = BudgetCycleHelper.getCycleRange(
          targetMonth: now.month,
          targetYear: now.year,
          mode: settings.budgetCycleMode,
          startDay: settings.budgetCycleStartDay,
        );
        _startDate = range.start;
        _endDate = range.end;
      } else if (type == 'this_year') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
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
    if (_currentPriceRange.start > 0 ||
        _currentPriceRange.end < _absMaxAmount) {
      count++;
    }
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
        dateMatch = !t.timestamp.isAfter(_endDate!);
      }

      bool typeMatch = t.type == _selectedType;
      bool categoryMatch =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(t.category);
      bool accountMatch =
          _selectedAccountIds.isEmpty ||
          (t.accountId != null && _selectedAccountIds.contains(t.accountId));

      return dateMatch && typeMatch && categoryMatch && accountMatch;
    }).toList();

    // Dynamically fetch lists
    final availableCategories = _selectedType == 'expense'
        ? TransactionCategories.expense
        : TransactionCategories.income;
    final availableAccounts = context.read<AccountProvider>().accounts;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      height: MediaQuery.of(context).size.height * 0.92,
      child: Column(
        children: [
          // --- HEADER & DRAG HANDLE ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Filters",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onReset();
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Reset All",
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- SCROLLABLE CONTENT ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. TRANSACTION TYPE (Segmented Control)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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

                // 2. DATE RANGE (Horizontal Pills)
                _buildSectionTitle(theme, "TIME PERIOD"),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildChoiceChip(
                        theme,
                        label: 'All Time',
                        isSelected: _dateRangeType == 'all_time',
                        onTap: () => _setDateRange('all_time'),
                      ),
                      _buildChoiceChip(
                        theme,
                        label: 'Today',
                        isSelected: _dateRangeType == 'today',
                        onTap: () => _setDateRange('today'),
                      ),
                      _buildChoiceChip(
                        theme,
                        label: 'This Month',
                        isSelected: _dateRangeType == 'this_month',
                        onTap: () => _setDateRange('this_month'),
                      ),
                      _buildChoiceChip(
                        theme,
                        label: 'This Year',
                        isSelected: _dateRangeType == 'this_year',
                        onTap: () => _setDateRange('this_year'),
                      ),
                      _buildChoiceChip(
                        theme,
                        label: _dateRangeType == 'custom' && _startDate != null
                            ? "${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}"
                            : 'Custom...',
                        isSelected: _dateRangeType == 'custom',
                        icon: Icons.calendar_today_rounded,
                        onTap: () => _setDateRange('custom'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. CATEGORIES (Inline Wrap)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(theme, "CATEGORIES", padding: false),
                      if (_selectedCategories.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategories.clear()),
                          child: Text(
                            "Clear",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: availableCategories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return _buildFilterChip(
                        theme,
                        label: cat,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCategories.remove(cat);
                            } else {
                              _selectedCategories.add(cat);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // 4. ACCOUNTS (Inline Wrap)
                if (availableAccounts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle(theme, "ACCOUNTS", padding: false),
                        if (_selectedAccountIds.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedAccountIds.clear()),
                            child: Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: availableAccounts.map((acc) {
                        final isSelected = _selectedAccountIds.contains(acc.id);
                        return _buildFilterChip(
                          theme,
                          label: acc.bankName,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedAccountIds.remove(acc.id);
                              } else {
                                _selectedAccountIds.add(acc.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // 5. PRICE RANGE
                _buildSectionTitle(theme, "AMOUNT RANGE"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Graph container
                      Container(
                        height: 80,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: PriceDistributionChart(
                          transactions: filteredForGraph,
                          minRange: _currentPriceRange.start,
                          maxRange: _currentPriceRange.end,
                          color: _selectedType == 'income'
                              ? theme.extension<AppColors>()?.income ??
                                    Colors.green
                              : theme.extension<AppColors>()?.expense ??
                                    Colors.red,
                          maxCap: _absMaxAmount,
                        ),
                      ),
                      // Range Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _selectedType == 'income'
                              ? theme.extension<AppColors>()?.income
                              : theme.extension<AppColors>()?.expense,
                          inactiveTrackColor:
                              colorScheme.surfaceContainerHighest,
                          thumbColor: _selectedType == 'income'
                              ? theme.extension<AppColors>()?.income
                              : theme.extension<AppColors>()?.expense,
                          trackHeight: 4,
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 10,
                            elevation: 2,
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
                      // Direct Inputs
                      Row(
                        children: [
                          Expanded(
                            child: ModernPriceInput(
                              currencySymbol,
                              _currentPriceRange.start,
                              label: "Minimum",
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              height: 2,
                              width: 12,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ModernPriceInput(
                              currencySymbol,
                              _currentPriceRange.end,
                              label: "Maximum",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // --- STICKY BOTTOM ACTION BAR ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Apply Filters",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_countActiveFilters() > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_countActiveFilters()}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for small caps section titles
  Widget _buildSectionTitle(
    ThemeData theme,
    String title, {
    bool padding = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: padding ? 24 : 0,
        right: padding ? 24 : 0,
        bottom: 12,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Helper widget for horizontal scrolling single-choice pills (Date Range)
  Widget _buildChoiceChip(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for multi-choice wraps (Categories, Accounts)
  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// --- MODERN SLIDING TOGGLE ---
// Kept logic but refined aesthetics heavily
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
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
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
// Refined to look like a solid input field
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- PRICE DISTRIBUTION CHART ---
// Intact from original, layout wrapper improved
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

    _drawBackgroundArea(canvas, size, bins, maxCount, binCount);
    _drawActiveRange(canvas, size, bins, maxCount, binCount);
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
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 0.5,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
