import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_detail_screen.dart';
import 'package:wallzy/features/transaction/widgets/transaction_filter_sheet.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() =>
      _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  final _searchController = TextEditingController();
  List<TransactionModel> _searchResults = [];
  List<TransactionModel> _allTransactions = [];
  TransactionFilter _currentFilter = TransactionFilter.empty;

  @override
  void initState() {
    super.initState();
    // Get all transactions once for efficient searching.
    _allTransactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    ).transactions;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _runSearch();
  }

  void _applyFilters(TransactionFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
    _runSearch();
  }

  void _resetFilters() {
    setState(() {
      _currentFilter = TransactionFilter.empty;
    });
    _runSearch();
  }

  void _runSearch() {
    final query = _searchController.text.toLowerCase().trim();
    final provider = Provider.of<TransactionProvider>(context, listen: false);

    // 1. First apply filters
    List<TransactionModel> filtered = _currentFilter.hasActiveFilters
        ? provider.getFilteredResults(_currentFilter).transactions
        : _allTransactions;

    // 2. Then apply search query
    if (query.isNotEmpty) {
      filtered = filtered.where((tx) {
        // Amount Search (Exact Match)
        final queryAmount = double.tryParse(query);
        if (queryAmount != null) {
          // Allow small epsilon for float comparison if needed,
          // or just simple exact match for user convenience
          if (tx.amount == queryAmount) return true;
          // Maybe match int part?
          if (tx.amount.toInt() == queryAmount.toInt()) return true;
        }

        // Check description
        if (tx.description.toLowerCase().contains(query)) return true;

        // Check category (often useful)
        if (tx.category.toLowerCase().contains(query)) return true;

        // Check person
        final personMatch =
            tx.people?.any(
              (person) => person.fullName.toLowerCase().contains(query),
            ) ??
            false;
        if (personMatch) return true;

        // Check tags
        final tagMatch =
            tx.tags?.any((tag) => tag.name.toLowerCase().contains(query)) ??
            false;
        if (tagMatch) return true;

        return false;
      }).toList();
    } else if (!_currentFilter.hasActiveFilters) {
      // No query and no filters -> empty results (default state)
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searchResults = filtered;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFilterSheet(
        initialFilter: _currentFilter,
        onApply: _applyFilters,
        onReset: _resetFilters,
      ),
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

  @override
  Widget build(BuildContext context) {
    final hasFilters = _currentFilter.hasActiveFilters;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        titleSpacing: 12,
        title: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(100),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 14,
                          ),
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                          fontFamily: 'inter',
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => _searchController.clear(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _showFilterSheet,
              style: IconButton.styleFrom(
                backgroundColor: hasFilters
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: hasFilters
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              icon: Icon(Icons.filter_list_rounded, size: 20),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.isEmpty && !_currentFilter.hasActiveFilters) {
      return EmptyReportPlaceholder(
        message: 'Search by amount, description, people or folders',
        icon: HugeIcons.strokeRoundedSearchList02,
      );
    }

    if (_searchResults.isEmpty) {
      return EmptyReportPlaceholder(
        message: 'No transactions found matching your criteria',
        icon: HugeIcons.strokeRoundedSearchRemove,
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
          ), // GroupedTransactionList has internal padding for headers
          sliver: GroupedTransactionList(
            transactions: _searchResults,
            onTap: (tx) => _showTransactionDetails(context, tx),
            useSliver: true,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}
