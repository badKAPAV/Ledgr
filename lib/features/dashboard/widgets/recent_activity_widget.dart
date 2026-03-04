import 'package:flutter/material.dart';
import 'package:wallzy/features/dashboard/widgets/home_empty_state.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/widgets/transactions_list/grouped_transaction_list.dart';

class RecentActivityWidget extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onTap;

  const RecentActivityWidget({
    super.key,
    required this.transactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Column(children: [SizedBox(height: 24), HomeEmptyState()]);
    }

    final theme = Theme.of(context);
    // Base style from your headlineMedium
    final baseStyle = theme.textTheme.headlineMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    );

    return Column(
      children: [
        // --- NATIVE "TEXT WALL" HEADER ---
        Container(
          width: double.infinity,
          height: 100,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: Stack(
            children: [
              // Faded Top Row - Clipped Left
              Positioned(
                top: 10,
                left: -40,
                child: _buildTextRow(
                  "RECENT TRANSACTIONS RECENT TRANSACTIONS RECENT TRANSACTIONS RECENT TRANSACTIONS",
                  0.05,
                  baseStyle,
                ),
              ),
              // Focused Center Row
              Align(
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextRow(
                        "RECENT TRANSACTIONS RECENT TRANSACTIONS ",
                        0.05,
                        baseStyle,
                        TextAlign.right,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        "RECENT TRANSACTIONS",
                        style: baseStyle?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildTextRow(
                        " RECENT TRANSACTIONS RECENT TRANSACTIONS",
                        0.05,
                        baseStyle,
                        TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
              // Faded Bottom Row - Clipped Right
              Positioned(
                bottom: 10,
                right: -40,
                child: _buildTextRow(
                  "RECENT TRANSACTIONS RECENT TRANSACTIONS RECENT TRANSACTIONS RECENT TRANSACTIONS",
                  0.05,
                  baseStyle,
                ),
              ),
            ],
          ),
        ),

        // --- THE LIST ---
        GroupedTransactionList(
          transactions: transactions,
          onTap: onTap,
          useSliver: false,
        ),
      ],
    );
  }

  Widget _buildTextRow(
    String text,
    double opacity,
    TextStyle? style, [
    TextAlign textAlign = TextAlign.center,
  ]) {
    return Text(
      text,
      maxLines: 1,
      textAlign: textAlign,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: style?.copyWith(
        color:
            style.color?.withValues(alpha: opacity) ??
            Colors.grey.withValues(alpha: opacity),
      ),
    );
  }
}
