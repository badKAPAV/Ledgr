import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:collection/collection.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencyFormat = NumberFormat.currency(
      symbol: settingsProvider.currencySymbol,
      decimalDigits: 2,
    );

    // Resolve Category
    final category = categoryProvider.categories.firstWhereOrNull(
      (c) => c.id == transaction.categoryId,
    );

    // Resolve Icon
    final iconKey = category?.iconKey ?? 'category_rounded';
    final icon = GoalIconRegistry.getIcon(iconKey);

    // Resolve Title
    final categoryName = category?.name ?? transaction.category;
    String title = categoryName;
    if (categoryName.toLowerCase() == 'people' &&
        (transaction.people?.isNotEmpty ?? false)) {
      title = transaction.people!.first.fullName;
    } else if (transaction.description.isNotEmpty) {
      title = transaction.description;
    }

    // Resolve Account & Subtitle
    final account = accountProvider.accounts.firstWhereOrNull(
      (a) => a.id == transaction.accountId,
    );
    final subtitle = account?.bankName ?? transaction.paymentMethod;
    final showCreditTag = account?.accountType == 'Credit Card';

    // Amount Logic
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense
        ? theme.colorScheme.onSurface
        : appColors.income;
    final amountString =
        "${isExpense ? '' : '+'}${currencyFormat.format(transaction.amount)}";

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
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
                  12,
                  12,
                  12,
                  linkedTx != null && netAmount != null ? 6 : 12,
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.1,
                          ),
                          width: 1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: icon,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                        strokeWidth: 1.5,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: .w300,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              if (showCreditTag) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CREDIT',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: .w300,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
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
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: netBorderRadius,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Link Icon
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLink01,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),

                        SizedBox(
                          height: 16,
                          child: VerticalDivider(
                            thickness: 1,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.5,
                            ),
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
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: 10,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                linkedTx.description.isNotEmpty
                                    ? linkedTx.description
                                    : linkedTx.category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Net: ",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
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
