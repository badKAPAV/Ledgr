import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:collection/collection.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import '../models/transaction.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.fastfood_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'salary':
        return Icons.work_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final appColors =
        Theme.of(context).extension<AppColors>() ??
        const AppColors(income: Colors.green, expense: Colors.red);
    final isExpense = transaction.type == 'expense';
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    final amountColor = isExpense
        ? Theme.of(context).colorScheme.onSurface
        : appColors.income;
    final amountString =
        '${isExpense ? '-' : '+'}${currencyFormat.format(transaction.amount)}';

    // Logic for Credit Tag
    final bool showCreditTag =
        (transaction.isCredit == true || transaction.purchaseType == 'credit');

    // Logic for Title
    final String title =
        (transaction.category.toLowerCase() == 'people' &&
            transaction.people?.isNotEmpty == true)
        ? transaction.people!.first.fullName
        : (transaction.description.isNotEmpty
              ? transaction.description
              : transaction.category);

    IconData icon = isExpense
        ? Icons.arrow_outward_rounded
        : Icons.arrow_downward_rounded;
    if (transaction.category.toLowerCase().contains('food')) {
      icon = Icons.fastfood_rounded;
    } else if (transaction.category.toLowerCase().contains('shop')) {
      icon = Icons.shopping_bag_rounded;
    } else {
      icon = _getIconForCategory(transaction.category);
    }

    // Logic for Subtitle (Payment Method only now)
    String subtitle = transaction.paymentMethod;

    // Linked Transaction Logic
    final txProvider = Provider.of<TransactionProvider>(context);
    final linkedTx = transaction.linkedTransactionId != null
        ? txProvider.transactions.firstWhereOrNull(
            (t) => t.transactionId == transaction.linkedTransactionId,
          )
        : null;

    double? netAmount;
    if (linkedTx != null) {
      double amount1 = isExpense ? -transaction.amount : transaction.amount;
      double amount2 = linkedTx.type == 'income'
          ? linkedTx.amount
          : -linkedTx.amount;
      netAmount = amount1 + amount2;
    }

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 24 : 6),
      topRight: Radius.circular(isFirst ? 24 : 6),
      bottomLeft: Radius.circular(isLast ? 24 : 6),
      bottomRight: Radius.circular(isLast ? 24 : 6),
    );

    final netBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(6),
      topRight: Radius.circular(6),
      bottomLeft: Radius.circular(isLast ? 18 : 6),
      bottomRight: Radius.circular(isLast ? 18 : 6),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. MAIN TRANSACTION CONTENT (Original Row) ---
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  linkedTx != null && netAmount != null ? 6 : 16,
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (isExpense ? appColors.expense : appColors.income)
                                .withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isExpense ? appColors.expense : appColors.income,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Center Column (Title + Date/Time + Credit Tag)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                DateFormat(
                                  'MMM d, y • h:mm a',
                                ).format(transaction.timestamp),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (showCreditTag) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CREDIT',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Column (Amount + Payment Method)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountString,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: amountColor,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 10,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // --- 2. LINKED TRANSACTION & NET BALANCE SECTION ---
              if (linkedTx != null && netAmount != null) ...[
                // const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: netBorderRadius,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Link Icon
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLink01,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),

                        SizedBox(
                          height: 16,
                          child: VerticalDivider(
                            thickness: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),

                        const SizedBox(width: 0),

                        // Linked Transaction Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Linked with",
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.5),
                                      fontSize: 10,
                                      height: 1.0,
                                    ),
                              ),
                              Text(
                                linkedTx.description.isNotEmpty
                                    ? linkedTx.description
                                    : linkedTx.category,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Net Amount Visual
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (netAmount >= 0
                                        ? appColors.income
                                        : appColors.expense)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Net: ",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${netAmount >= 0 ? '+' : ''}${currencyFormat.format(netAmount)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: netAmount >= 0
                                      ? appColors.income
                                      : appColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }
}
