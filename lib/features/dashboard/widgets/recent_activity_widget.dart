import 'package:flutter/material.dart';
import 'package:wallzy/common/helpers/fading_divider.dart';
import 'package:wallzy/features/dashboard/widgets/home_empty_state.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/screens/all_transactions_screen.dart';
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

    // final theme = Theme.of(context);
    // Base style from your headlineMedium
    // final baseStyle = theme.textTheme.headlineMedium?.copyWith(
    //   fontSize: 16,
    //   fontWeight: FontWeight.w900,
    //   letterSpacing: 1.5
    // );

    return Column(
      // crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                'RECENT TRANSACTIONS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.secondary,
                ),
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
            ],
          ),
        ),

        // --- THE LIST ---
        GroupedTransactionList(
          transactions: transactions,
          onTap: onTap,
          useSliver: false,
        ),

        const SizedBox(height: 6),

        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            // borderRadius: .only(
            //   topLeft: Radius.circular(6),
            //   topRight: Radius.circular(6),
            //   bottomLeft: Radius.circular(24),
            //   bottomRight: Radius.circular(24),
            // ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: InkWell(
            // borderRadius: .only(
            //   topLeft: Radius.circular(6),
            //   topRight: Radius.circular(6),
            //   bottomLeft: Radius.circular(24),
            //   bottomRight: Radius.circular(24),
            // ),
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllTransactionsScreen(initialTabIndex: 0),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: .min,
                children: [
                  Text(
                    'View all',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildTextRow(
  //   String text,
  //   double opacity,
  //   TextStyle? style, [
  //   TextAlign textAlign = TextAlign.center,
  // ]) {
  //   return Text(
  //     text,
  //     maxLines: 1,
  //     textAlign: textAlign,
  //     overflow: TextOverflow.clip,
  //     softWrap: false,
  //     style: style?.copyWith(
  //       color:
  //           style.color?.withValues(alpha: opacity) ??
  //           Colors.grey.withValues(alpha: opacity),
  //     )
  //   );
  // }
}
