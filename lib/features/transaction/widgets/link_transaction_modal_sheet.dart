import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

class LinkTransactionModalSheet extends StatefulWidget {
  final TransactionModel? excludeTransaction;
  final String? sourceTransactionType;

  const LinkTransactionModalSheet({
    super.key,
    this.excludeTransaction,
    this.sourceTransactionType,
  });

  @override
  State<LinkTransactionModalSheet> createState() =>
      _LinkTransactionModalSheetState();
}

class _LinkTransactionModalSheetState extends State<LinkTransactionModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<TransactionModel> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTransactions);
    // Initial filter on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _filterTransactions());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTransactions() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredTransactions = provider.transactions.where((tx) {
        // Exclude current transaction if editing
        if (widget.excludeTransaction != null &&
            tx.transactionId == widget.excludeTransaction!.transactionId) {
          return false;
        }

        // Exclude already linked transactions (optional, but safer)
        if (tx.isTransfer == true || tx.linkedTransactionId != null) {
          return false;
        }

        // Type logic
        if (widget.sourceTransactionType != null ||
            widget.excludeTransaction != null) {
          final sourceType =
              widget.sourceTransactionType ?? widget.excludeTransaction!.type;

          final allowedType = sourceType == 'income' ? 'expense' : 'income';

          if (tx.type != allowedType) {
            return false;
          }
        }

        // Search logic
        final matchDescription = tx.description.toLowerCase().contains(query);
        final matchCategory = tx.category.toLowerCase().contains(query);
        final matchAmount = tx.amount.toString().contains(query);

        return matchDescription || matchCategory || matchAmount;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search with anything",
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 10,
                    strokeWidth: 2,
                  ),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Tap on a transaction to link',
            style: TextStyle(color: colorScheme.outline, fontSize: 12),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No linkable transactions found",
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      GroupedTransactionList(
                        transactions: _filteredTransactions,
                        onTap: (tx) => Navigator.pop(context, tx),
                        useSliver: true,
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
