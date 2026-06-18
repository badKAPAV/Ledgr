import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/folders/models/folder.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

/// Bottom sheet that allows the user to enter their real-world account balance.
/// The sheet computes the difference and creates a compensating transaction to
/// reconcile the in-app balance with the user's actual balance.
class EditAccountBalanceModalSheet extends StatefulWidget {
  final Account account;

  /// [passedContext] is the outer context used to show snackbars on the parent
  /// scaffold after the sheet has been popped.
  final BuildContext passedContext;

  const EditAccountBalanceModalSheet({
    super.key,
    required this.account,
    required this.passedContext,
  });

  @override
  State<EditAccountBalanceModalSheet> createState() =>
      _EditAccountBalanceModalSheetState();
}

class _EditAccountBalanceModalSheetState
    extends State<EditAccountBalanceModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();

  bool _isSaving = false;

  // ─── The name of the system folder used for reconciliation ──────────────
  static const _reconciliationFolderName = 'balance out money';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Parses the amount text, accepting both '.' and ',' as decimal separators.
  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  void _showSnackbar(BuildContext ctx, String message, {bool isError = false}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(ctx).colorScheme.error
            : Theme.of(ctx).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Core business logic ──────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newBalance = _parseAmount(_amountController.text);
    if (newBalance == null) {
      _showSnackbar(context, 'Please enter a valid number.', isError: true);
      return;
    }

    // Step 1: Calculate difference.
    final txProvider = context.read<TransactionProvider>();
    final metaProvider = context.read<MetaProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final currentBalance = txProvider.accountProvider.getBalanceForAccount(
      widget.account,
      txProvider.transactions,
    );

    final difference = newBalance - currentBalance;

    if (difference == 0) {
      _showSnackbar(context, 'Balance is already up to date.');
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    // Capture context-sensitive objects before any async gap.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final passedMessenger = ScaffoldMessenger.of(widget.passedContext);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      // Step 2: Resolve (or create) the reconciliation folder / tag.
      final Tag reconciliationTag = await _resolveReconciliationTag(
        metaProvider,
      );

      // Step 3: Build the description.
      final userNote = _noteController.text.trim();
      final description = userNote.isEmpty
          ? '(System generated transaction for balancing account balance)'
          : '$userNote (System generated transaction for balancing account balance)';

      // Step 4: Determine transaction type and amount.
      final String txType = difference > 0 ? 'income' : 'expense';
      final double txAmount = difference.abs();

      // Step 5: Create and save the transaction.
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.account.userId)
          .collection('transactions')
          .doc(); // auto-generated ID

      final transaction = TransactionModel(
        transactionId: docRef.id,
        type: txType,
        amount: txAmount,
        timestamp: DateTime.now(),
        description: description,
        paymentMethod: 'cash',
        category: 'others',
        categoryId: 'others',
        currency: settingsProvider.currencySymbol,
        accountId: widget.account.id,
        tags: [reconciliationTag],
        excludeFromBudgets: true,
      );

      await txProvider.addTransaction(transaction);

      // Step 6: Success – close the sheet, then show confirmation on parent.
      nav.pop();
      passedMessenger.showSnackBar(
        SnackBar(
          content: const Text('Account balance updated.'),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to update balance. Please try again.'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      debugPrint('EditAccountBalanceSheet error: $e');
    }
  }

  /// Returns the existing reconciliation [Tag] if one with the name
  /// [_reconciliationFolderName] already exists, otherwise creates it and
  /// returns the newly created tag (with its Firestore-assigned ID).
  Future<Tag> _resolveReconciliationTag(MetaProvider metaProvider) async {
    final existing = metaProvider.tags.firstWhere(
      (t) => t.name.toLowerCase() == _reconciliationFolderName.toLowerCase(),
      orElse: () => Tag(id: '', name: '', createdAt: DateTime.now()),
    );

    if (existing.id.isNotEmpty) return existing;

    // Doesn't exist — create it now and await so we have a real ID.
    final newTag = await metaProvider.addTag(_reconciliationFolderName);
    return newTag;
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySymbol = settingsProvider.currencySymbol;

    // Current in-app balance for this account.
    final txProvider = context.watch<TransactionProvider>();
    final currentBalance = txProvider.accountProvider.getBalanceForAccount(
      widget.account,
      txProvider.transactions,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Adjust Balance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    widget.account.bankName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.account.accountNumber.isNotEmpty
                        ? "• ${widget.account.accountNumber}"
                        : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Current balance info card ────────────────────────────────────
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //   decoration: BoxDecoration(
          //     color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(
          //       color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(
          //         Icons.info_outline_rounded,
          //         size: 16,
          //         color: colorScheme.onSurfaceVariant,
          //       ),
          //       const SizedBox(width: 8),
          //       Text(
          //         'App balance: ',
          //         style: theme.textTheme.bodySmall?.copyWith(
          //           color: colorScheme.onSurfaceVariant,
          //         ),
          //       ),
          //       Text(
          //         '$currencySymbol${currentBalance.toStringAsFixed(2)}',
          //         style: theme.textTheme.bodySmall?.copyWith(
          //           color: colorScheme.onSurface,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //       // const Spacer(),
          //       // Text(
          //       //   'Enter your real balance →',
          //       //   style: theme.textTheme.labelSmall?.copyWith(
          //       //     color: colorScheme.primary,
          //       //     fontStyle: FontStyle.italic,
          //       //   ),
          //       // ),
          //     ],
          //   ),
          // ),
          _noteBuilder(
            theme,
            "App balance: $currencySymbol${currentBalance.toStringAsFixed(2)}",
          ),

          const SizedBox(height: 20),

          // ── Form ─────────────────────────────────────────────────────────
          Form(
            key: _formKey,
            child: Column(
              children: [
                // New Balance field
                TextFormField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    labelText: 'New Account Balance *',
                    prefixText: '$currencySymbol ',
                    prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 14,
                    ),
                    hintText: '0.00',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the new balance.';
                    }
                    if (_parseAmount(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Note field
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Monthly reconciliation',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Save button ──────────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteBuilder(ThemeData theme, String note, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning
            ? theme.colorScheme.errorContainer.withAlpha(76)
            : theme.colorScheme.primaryContainer.withAlpha(76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWarning
              ? theme.colorScheme.error.withAlpha(50)
              : theme.colorScheme.primary.withAlpha(50),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: isWarning
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: isWarning
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
