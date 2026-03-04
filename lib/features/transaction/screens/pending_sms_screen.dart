import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/folders/models/tag.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:wallzy/features/categories/services/category_matcher.dart';
import 'dart:async';

class PendingSmsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  // CHANGED: Returns a Future<bool> to indicate success/failure
  final Function(Map<String, dynamic>) onAdd;
  final Function(Map<String, dynamic>) onDismiss;
  final Function(Map<String, dynamic>) onUndo;

  const PendingSmsScreen({
    super.key,
    required this.transactions,
    required this.onAdd,
    required this.onDismiss,
    required this.onUndo,
  });

  @override
  State<PendingSmsScreen> createState() => _PendingSmsScreenState();
}

class _PendingSmsScreenState extends State<PendingSmsScreen> {
  late List<Map<String, dynamic>> _transactions;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final ValueNotifier<int> _autoRecordTotal = ValueNotifier(0);
  final ValueNotifier<int> _autoRecordProgress = ValueNotifier(0);
  bool _isRecordingAll = false;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  @override
  void dispose() {
    _autoRecordTotal.dispose();
    _autoRecordProgress.dispose();
    super.dispose();
  }

  // --- Single Item Logic ---
  void _dismissItem(int index, Map<String, dynamic> tx) {
    HapticFeedback.selectionClick();

    // 1. Remove from UI immediately for "Ignore"
    final removedItem = _transactions.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(
          opacity: animation,
          child: _TransactionRow(tx: tx),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );

    // 2. Trigger Callback
    widget.onDismiss(removedItem);

    // 3. Show Snackbar with Undo
    _showUndoSnackbar(
      message: "Transaction ignored",
      onUndo: () {
        setState(() {
          _transactions.insert(index, removedItem);
        });
        _listKey.currentState?.insertItem(index);
        widget.onUndo(removedItem);
      },
    );
  }

  Future<void> _trackItem(int index, Map<String, dynamic> tx) async {
    HapticFeedback.mediumImpact();

    // CHANGED: We do NOT remove the item yet.
    // We wait for the parent to tell us if it was successful.
    final bool success = await widget.onAdd(tx);

    // Only remove if the operation was successful (e.g. User clicked "Save")
    if (success && mounted) {
      // Check if index is still valid (list might have changed)
      if (index < _transactions.length && _transactions[index] == tx) {
        // ignore: unused_local_variable
        final removedItem = _transactions.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: const SizedBox.shrink(), // Instant shrink
          ),
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  // --- Bulk Logic ---
  Future<void> _handleClearAll() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text(
          "This will ignore all pending transactions in this list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List<Map<String, dynamic>> backupList = List.from(_transactions);
      final int count = backupList.length;

      for (var tx in _transactions) {
        widget.onDismiss(tx);
      }

      for (int i = _transactions.length - 1; i >= 0; i--) {
        final item = _transactions[i];
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: _TransactionRow(tx: item),
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
      setState(() {
        _transactions.clear();
      });

      _showUndoSnackbar(
        message: "Inbox cleared ($count items)",
        onUndo: () {
          setState(() {
            _transactions.addAll(backupList);
          });
          for (int i = 0; i < backupList.length; i++) {
            _listKey.currentState?.insertItem(i);
            widget.onUndo(backupList[i]);
          }
        },
      );
    }
  }

  Future<void> _handleAutoRecordAll() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;
    if (_transactions.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Auto Record All?"),
        content: Text(
          "This will automatically categorize and save all ${_transactions.length} pending transactions.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton.icon(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkBadge01,
              size: 20,
              color: Colors.white,
            ),
            label: const Text("Auto Record"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRecordingAll = true;
    });

    _autoRecordTotal.value = _transactions.length;
    _autoRecordProgress.value = 0;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<int>(
          valueListenable: _autoRecordProgress,
          builder: (context, progress, _) {
            final total = _autoRecordTotal.value;
            return Text(
              "Recording transactions... $progress / $total",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            );
          },
        ),
        duration: const Duration(days: 1),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    final metaProvider = Provider.of<MetaProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    int savedCount = 0;
    final List<Map<String, dynamic>> pending = List.from(_transactions);

    final matcher = CategoryMatcher();
    await matcher.loadCategories();

    for (final txData in pending) {
      if (!mounted) break;
      try {
        final amount = (txData['amount'] as num).toDouble();
        final type = txData['type'] ?? 'expense';
        final bankName = txData['bankName'] as String?;
        final accountNumber = txData['accountNumber'] as String?;
        final payee = txData['payee'] as String?;

        DateTime date;
        if (txData['timestamp'] != null && txData['timestamp'] is int) {
          date = DateTime.fromMillisecondsSinceEpoch(txData['timestamp']);
        } else {
          date = DateTime.now();
        }

        String? accountId;
        if (bankName != null && accountNumber != null) {
          final account = await accountProvider.findOrCreateAccount(
            bankName: bankName,
            accountNumber: accountNumber,
          );
          accountId = account.id;
        } else if (type == 'expense' &&
            payee != null &&
            payee.toLowerCase().contains('upi')) {
          final primary = await accountProvider.getPrimaryAccount();
          accountId = primary?.id;
        } else {
          final primary = await accountProvider.getPrimaryAccount();
          accountId = primary?.id;
        }

        final List<Tag> tags = metaProvider.getAutoAddTagsForDate(date);
        final textToMatch = payee ?? (type == 'income' ? 'Received' : 'Spent');

        String? categoryId = txData['categoryId'];
        String categoryName = txData['category'] ?? 'Others';

        if (categoryId == null || categoryId.isEmpty) {
          categoryId = matcher.matchCategory(
            textToMatch,
            mode: type == 'income'
                ? TransactionMode.income
                : TransactionMode.expense,
          );

          final categoryProvider = context.read<CategoryProvider>();
          categoryName =
              categoryProvider.categories
                  .firstWhereOrNull((c) => c.id == categoryId)
                  ?.name ??
              'Others';
        }

        final newTx = TransactionModel(
          transactionId: const Uuid().v4(),
          type: type,
          amount: amount,
          timestamp: date,
          description: textToMatch,
          paymentMethod: txData['paymentMethod'] ?? 'Unknown',
          category: categoryName,
          categoryId: categoryId,
          currency: settingsProvider.currencyCode,
          accountId: accountId,
          tags: tags,
        );

        await txProvider.addTransaction(newTx);

        // Trigger callback so parent removes it from both platform and UI
        widget.onDismiss(txData);

        // Remove from UI list
        final index = _transactions.indexOf(txData);
        if (index != -1) {
          _transactions.removeAt(index);
          _listKey.currentState?.removeItem(
            index,
            (context, animation) => SizeTransition(
              sizeFactor: animation,
              child: const SizedBox.shrink(),
            ),
            duration: const Duration(milliseconds: 200),
          );
        }

        savedCount++;
        _autoRecordProgress.value = savedCount;
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint("Error auto-saving transaction: $e");
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecordingAll = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Auto-recorded $savedCount transactions",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showUndoSnackbar({
    required String message,
    required VoidCallback onUndo,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Theme.of(context).colorScheme.inversePrimary,
          onPressed: () {
            HapticFeedback.lightImpact();
            onUndo();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Inbox"),
            Text(
              "${_transactions.length} pending",
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_transactions.isNotEmpty && !_isRecordingAll) ...[
            // --- RECORD ALL BUTTON ---
            Container(
              height: 36, // Fixed height for symmetry
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextButton.icon(
                onPressed: _handleAutoRecordAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedBookmarkAdd02,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  "Record All",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // --- CLEAR ALL BUTTON ---
            Container(
              height: 36, // Matching height
              width: 40, // Square-ish for the icon button
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: _handleClearAll,
                padding: EdgeInsets.zero,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],

          // --- LOADING STATE ---
          if (_isRecordingAll) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: _transactions.isEmpty
          ? const EmptyReportPlaceholder(
              message: "No pending transactions",
              icon: HugeIcons.strokeRoundedInboxCheck,
            )
          : AnimatedList(
              key: _listKey,
              padding: const EdgeInsets.symmetric(vertical: 8),
              initialItemCount: _transactions.length,
              itemBuilder: (context, index, animation) {
                if (index >= _transactions.length)
                  return const SizedBox.shrink();

                final tx = _transactions[index];
                return SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _TransactionRow(
                        tx: tx,
                        onTrack: () => _trackItem(index, tx),
                        onIgnore: () => _dismissItem(index, tx),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTrack;
  final VoidCallback? onIgnore;

  const _TransactionRow({required this.tx, this.onTrack, this.onIgnore});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final theme = Theme.of(context);

    final amount = (tx['amount'] as num).toDouble();
    final merchant = tx['payee'] ?? tx['merchant'] ?? 'Unknown';
    DateTime date;
    if (tx['timestamp'] != null && tx['timestamp'] is int) {
      date = DateTime.fromMillisecondsSinceEpoch(tx['timestamp']);
    } else {
      date = DateTime.tryParse(tx['date'] ?? '') ?? DateTime.now();
    }

    final isIncome = (tx['type'] == 'income');
    final color = isIncome ? Colors.green : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(80),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIncome ? '+' : ''} ${NumberFormat.simpleCurrency(name: settingsProvider.currencyCode).format(amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: onIgnore,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Ignore',
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: onTrack,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Track',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
