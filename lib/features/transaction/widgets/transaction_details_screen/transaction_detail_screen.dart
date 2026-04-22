import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:wallzy/common/switch/custom_switch.dart';
import 'package:wallzy/common/widgets/custom_alert_dialog.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/recurring_payment/provider/recurring_payment_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/screens/add_edit_transaction_screen.dart';
import 'package:wallzy/features/folders/screens/folder_details_screen.dart';
import 'package:wallzy/features/transaction/widgets/add_to_folder_modal_sheet.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/folders/models/folder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';
import 'package:wallzy/features/transaction/widgets/add_receipt_modal_sheet.dart';
import 'package:wallzy/features/recurring_payment/models/recurring_payment.dart';
import 'package:wallzy/features/recurring_payment/screens/recurring_payment_details_screen.dart';
import 'package:wallzy/features/transaction/widgets/link_transaction_modal_sheet.dart';

import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/slim_info_row.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/action_tile.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/status_badge.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/action_box.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;
  final List<String> parentTagIds;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.parentTagIds = const [],
  });

  // --- Logic Helper Methods (Unchanged) ---

  dynamic _getIconForCategory(BuildContext context, TransactionModel tx) {
    if (tx.categoryId != null) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final category = categoryProvider.categories.firstWhereOrNull(
        (c) => c.id == tx.categoryId,
      );
      if (category != null) {
        return GoalIconRegistry.getIcon(category.iconKey);
      }
    }

    // Fallback for legacy
    switch (tx.category.toLowerCase()) {
      case 'food':
        return HugeIcons.strokeRoundedRiceBowl01;
      case 'shopping':
        return HugeIcons.strokeRoundedShoppingBag02;
      case 'transport':
        return HugeIcons.strokeRoundedCar02;
      case 'entertainment':
        return HugeIcons.strokeRoundedTicket01;
      case 'salary':
        return HugeIcons.strokeRoundedMoney03;
      case 'people':
        return HugeIcons.strokeRoundedUser;
      case 'health':
        return HugeIcons.strokeRoundedAmbulance;
      case 'bills':
        return HugeIcons.strokeRoundedInvoice01;
      default:
        return HugeIcons.strokeRoundedMenu01;
    }
  }

  String _getCategoryName(BuildContext context, TransactionModel tx) {
    if (tx.categoryId != null) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final category = categoryProvider.categories.firstWhereOrNull(
        (c) => c.id == tx.categoryId,
      );
      if (category != null) return category.name;
    }
    return tx.category;
  }

  void _deleteTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ModernAlertDialog(
        title: "Delete Transaction",
        description: "Are you sure you want to delete this transaction?",
        icon: HugeIcons.strokeRoundedDelete02,
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
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final txProvider = Provider.of<TransactionProvider>(
                context,
                listen: false,
              );
              txProvider.deleteTransaction(transaction.transactionId);
              if (!context.mounted) return;
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(true); // Close modal
            },
          ),
        ],
      ),
    );
  }

  void _showAddToFolderModal(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AddToFolderModalSheet(
          metaProvider: Provider.of<MetaProvider>(context, listen: false),
          txProvider: Provider.of<TransactionProvider>(context, listen: false),
          initialTags: tx.tags?.whereType<Tag>().toList() ?? [],
          scrollController: scrollController,
          onSelected: (tags) async {
            final txProvider = Provider.of<TransactionProvider>(
              context,
              listen: false,
            );
            final updatedTx = tx.copyWith(tags: tags);
            await txProvider.updateTransaction(updatedTx);
          },
        ),
      ),
    );
  }

  void _navigateToTagDetails(BuildContext context, Tag tag) {
    if (parentTagIds.contains(tag.id)) {
      Navigator.of(context).popUntil((route) {
        return route.settings.name == 'TagDetails' &&
            route.settings.arguments == tag.id;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: 'TagDetails', arguments: tag.id),
          builder: (_) => TagDetailsScreen(
            tag: tag,
            parentTagIds: [...parentTagIds, tag.id],
          ),
        ),
      );
    }
  }

  void _navigateToSubscriptionDetails(BuildContext context, Subscription? sub) {
    if (sub == null) return;
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final subTransactions = txProvider.transactions
        .where((tx) => tx.subscriptionId == sub.id)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailsScreen(
          subscription: sub,
          transactions: subTransactions,
        ),
      ),
    );
  }

  void _viewReceipt(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Selector<TransactionProvider, TransactionModel?>(
              selector: (context, provider) =>
                  provider.transactions.firstWhereOrNull(
                    (t) => t.transactionId == transaction.transactionId,
                  ),
              shouldRebuild: (previous, next) => true,
              builder: (context, updatedTransaction, child) {
                final tx = updatedTransaction ?? transaction;

                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final appColors = theme.extension<AppColors>()!;
                final accountProvider = Provider.of<AccountProvider>(
                  context,
                  listen: false,
                );
                final settingsProvider = Provider.of<SettingsProvider>(context);
                final currencySymbol = settingsProvider.currencySymbol;

                // --- Data Parsing ---
                final isExpense = tx.type == 'expense';
                final typeColor = isExpense
                    ? (appColors.expense)
                    : (appColors.income);

                final currencyFormat = NumberFormat.currency(
                  symbol: currencySymbol,
                  decimalDigits: 2,
                );

                // Account Logic
                final account = tx.accountId != null
                    ? accountProvider.accounts.firstWhereOrNull(
                        (acc) => acc.id == tx.accountId,
                      )
                    : null;

                String paymentDisplay = tx.paymentMethod;
                String accountNameDisplay = "Unlinked";

                if (account != null) {
                  accountNameDisplay = account.bankName;
                  if (account.bankName.toLowerCase() == 'cash' &&
                      tx.paymentMethod.toLowerCase() == 'cash') {
                    paymentDisplay = 'Cash Payment';
                  }
                } else if (tx.paymentMethod.toLowerCase() == 'cash') {
                  accountNameDisplay = "Cash Wallet";
                }

                // Category/Person Logic
                String mainTitleLabel = _getCategoryName(context, tx);
                dynamic mainIcon = _getIconForCategory(context, tx);

                if (mainTitleLabel.toLowerCase() == 'people' &&
                    tx.people != null &&
                    tx.people!.isNotEmpty) {
                  mainTitleLabel = tx.people!.map((p) => p.fullName).join(", ");
                  mainIcon = HugeIcons.strokeRoundedUser;
                }

                // Date Formatting
                final dateStr = DateFormat('MMM d, yyyy').format(tx.timestamp);
                final timeStr = DateFormat('h:mm a').format(tx.timestamp);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                      child: Column(
                        children: [
                          // --- ICON ---
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: HugeIcon(
                                icon: mainIcon,
                                strokeWidth: 2,
                                size: 12,
                                color: typeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // --- AMOUNT ---
                          Text(
                            currencyFormat.format(tx.amount),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -1,
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // --- CATEGORY / PERSON NAME ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Text(
                              mainTitleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 20,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // --- DATE & TIME ---
                          Text(
                            "$dateStr  •  $timeStr",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- CHIPS ROW (Unchanged logic) ---
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // Expense/Income
                              StatusBadge(
                                label: isExpense ? "Expense" : "Income",
                                color: colorScheme.onSurfaceVariant,
                                bgColor: colorScheme.surfaceContainerHighest,
                                icon: isExpense
                                    ? HugeIcons.strokeRoundedArrowUpRight01
                                    : HugeIcons.strokeRoundedArrowDownRight01,
                              ),

                              // Credit
                              if ((tx.isCredit ?? false) ||
                                  tx.purchaseType == 'credit')
                                StatusBadge(
                                  label: "Credit",
                                  color: colorScheme.tertiary,
                                ),

                              // Subscription
                              if (tx.subscriptionId != null)
                                Consumer<SubscriptionProvider>(
                                  builder: (context, subProvider, _) {
                                    final sub = subProvider.subscriptions
                                        .firstWhereOrNull(
                                          (s) => s.id == tx.subscriptionId,
                                        );
                                    return InkWell(
                                      onTap: () =>
                                          _navigateToSubscriptionDetails(
                                            context,
                                            sub,
                                          ),
                                      child: StatusBadge(
                                        label: sub != null
                                            ? sub.name
                                            : "Subscription",
                                        color: Colors.purple,
                                        icon: Icons.autorenew_rounded,
                                      ),
                                    );
                                  },
                                ),

                              // Tags (Folders)
                              if (tx.tags != null && tx.tags!.isNotEmpty)
                                ...tx.tags!.map((tag) {
                                  final colorVal =
                                      (tag is! String && tag.color != null)
                                      ? tag.color
                                      : null;
                                  final tagName = tag.name;

                                  final color = colorVal != null
                                      ? Color(colorVal)
                                      : colorScheme.primary;

                                  return InkWell(
                                    onTap: () =>
                                        _navigateToTagDetails(context, tag),
                                    borderRadius: BorderRadius.circular(20),
                                    child: StatusBadge(
                                      label: tagName,
                                      color: color,
                                      icon: HugeIcons.strokeRoundedFolder02,
                                    ),
                                  );
                                }),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // --- ACCOUNT & PAYMENT (Slim Row) ---
                          SlimInfoRow(
                            icon: HugeIcons.strokeRoundedWallet03,
                            title: accountNameDisplay,
                            subtitle: paymentDisplay,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),

                          // --- FOLDER & RECEIPT LOGIC ---
                          Builder(
                            builder: (context) {
                              final hasTags =
                                  tx.tags != null && tx.tags!.isNotEmpty;

                              // Receipt Widget
                              Widget receiptWidget;
                              if (tx.receiptUrl != null) {
                                // View Receipt
                                receiptWidget = ActionTile(
                                  icon: HugeIcons.strokeRoundedInvoice01,
                                  label: "View Receipt",
                                  onTap: () =>
                                      _viewReceipt(context, tx.receiptUrl!),
                                  isDashed: false,
                                  color: colorScheme.primary,
                                );
                              } else {
                                // Add Receipt
                                receiptWidget = ActionTile(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  label: "Add Receipt",
                                  isDashed: true,
                                  color: colorScheme.primary,
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => AddReceiptModalSheet(
                                        uploadImmediately: true,
                                        transactionId: tx.transactionId,
                                        onComplete: (url, _) async {
                                          if (url != null) {
                                            final txProvider =
                                                Provider.of<
                                                  TransactionProvider
                                                >(context, listen: false);
                                            final updatedTx = tx.copyWith(
                                              receiptUrl: () => url,
                                            );
                                            await txProvider.updateTransaction(
                                              updatedTx,
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                              }

                              if (hasTags) {
                                // Full width Receipt
                                return receiptWidget;
                              } else {
                                // Split Row: Add Folder | Receipt
                                return Row(
                                  children: [
                                    Expanded(
                                      child: ActionTile(
                                        icon: HugeIcons.strokeRoundedFolderAdd,
                                        label: "Add to Folder",
                                        isDashed: true,
                                        color: colorScheme.primary,
                                        onTap: () =>
                                            _showAddToFolderModal(context, tx),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: receiptWidget),
                                  ],
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 12),

                          // --- LINK TRANSACTION LOGIC ---
                          Consumer<TransactionProvider>(
                            builder: (context, txProvider, _) {
                              final linkedTx = txProvider.transactions
                                  .firstWhereOrNull(
                                    (t) =>
                                        t.transactionId ==
                                        tx.linkedTransactionId,
                                  );

                              if (linkedTx != null) {
                                // Calculate Net Amount
                                double netAmount = 0.0;
                                // Assuming positive for income, negative for expense for net calc?
                                // Or purely based on type.
                                double amount1 = tx.type == 'income'
                                    ? tx.amount
                                    : -tx.amount;
                                double amount2 = linkedTx.type == 'income'
                                    ? linkedTx.amount
                                    : -linkedTx.amount;
                                netAmount = amount1 + amount2;

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    10,
                                    6,
                                    6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12.0,
                                            ),
                                            child: Text(
                                              "LINKED TRANSACTION",
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.outline,
                                                    letterSpacing: 1.0,
                                                  ),
                                            ),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => ModernAlertDialog(
                                                  title: "Unlink Transaction?",
                                                  description:
                                                      "This will remove the link between these transactions.",
                                                  icon: HugeIcons
                                                      .strokeRoundedUnlink01,
                                                  actions: [
                                                    TextButton(
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                colorScheme
                                                                    .outline,
                                                            backgroundColor:
                                                                colorScheme
                                                                    .outline
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                          ),
                                                      child: const Text(
                                                        "Cancel",
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                    ),
                                                    TextButton(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            colorScheme
                                                                .errorContainer,
                                                        backgroundColor:
                                                            colorScheme.error,
                                                      ),
                                                      child: const Text(
                                                        "Unlink",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                await txProvider
                                                    .unlinkTransaction(tx);
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedUnlink01,
                                                    size: 16,
                                                    color: colorScheme.error,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Unlink",
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color:
                                                              colorScheme.error,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SlimInfoRow(
                                        isTransferWidget: true,
                                        icon: linkedTx.type == 'income'
                                            ? HugeIcons
                                                  .strokeRoundedArrowDownRight01
                                            : HugeIcons
                                                  .strokeRoundedArrowUpRight01,
                                        title: linkedTx.description.isNotEmpty
                                            ? linkedTx.description
                                            : linkedTx.category,
                                        subtitle: currencyFormat.format(
                                          linkedTx.amount,
                                        ),
                                        color: linkedTx.type == 'income'
                                            ? appColors.income
                                            : appColors.expense,
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerLowest,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(6),
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          // border: Border.all(
                                          //   color: colorScheme.primary,
                                          // ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Net Total",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            Text(
                                              "${netAmount >= 0 ? '+' : ''}${currencyFormat.format(netAmount)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
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
                                );
                              } else {
                                return ActionTile(
                                  icon: HugeIcons.strokeRoundedLink01,
                                  label: "Link Transaction",
                                  isDashed: true,
                                  color: colorScheme.primary,
                                  onTap: () async {
                                    final selectedTx =
                                        await showModalBottomSheet<
                                          TransactionModel
                                        >(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) =>
                                              LinkTransactionModalSheet(
                                                excludeTransaction: tx,
                                                sourceTransactionType: tx.type,
                                              ),
                                        );

                                    if (selectedTx != null) {
                                      await txProvider.linkTransactions(
                                        tx,
                                        selectedTx,
                                      );
                                    }
                                  },
                                );
                              }
                            },
                          ),
                          if (tx.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedNote01,
                                        size: 16,
                                        color: colorScheme.outline,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "NOTE",
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.outline,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tx.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (tx.type == 'expense')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Exclude from budgets",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  LedgrSwitch(
                                    value: tx.excludeFromBudgets,
                                    // activeColor: colorScheme.primary,
                                    onChanged: (newValue) async {
                                      final txProvider =
                                          Provider.of<TransactionProvider>(
                                            context,
                                            listen: false,
                                          );
                                      final updatedTx = tx.copyWith(
                                        excludeFromBudgets: newValue,
                                      );
                                      await txProvider.updateTransaction(
                                        updatedTx,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 3. Bottom Actions (Edit / Delete)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: ActionBox(
                              label: "Edit",
                              icon: HugeIcons.strokeRoundedEdit02,
                              color: colorScheme.primary,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddEditTransactionScreen(
                                      transaction: tx,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ActionBox(
                              label: "Delete",
                              icon: HugeIcons.strokeRoundedDelete02,
                              color: colorScheme.error,
                              onTap: () => _deleteTransaction(context),
                              isDestructive: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
