import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/core/helpers/transaction_category.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/currency_convert/widgets/currency_convert_modal_sheet.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/person_picker_sheet.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/provider/subscription_provider.dart';
import 'package:wallzy/features/subscription/screens/add_subscription_screen.dart';
import 'package:wallzy/features/folders/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/services/receipt_service.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';
import 'package:wallzy/features/transaction/widgets/link_transaction_modal_sheet.dart';
import 'package:wallzy/features/categories/screens/add_edit_category_modal_sheet.dart';
import 'package:wallzy/features/transaction/widgets/add_receipt_modal_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class TransactionForm extends StatefulWidget {
  final TransactionMode mode;
  final TransactionModel? transaction;
  final String? initialAmount;
  final DateTime? initialDate;
  final String? smsTransactionId;
  final String? initialPaymentMethod;
  final String? initialBankName;
  final String? initialAccountNumber;
  final String? initialPayee;
  final String? initialCategory;
  final String? initialCategoryId;
  final Person? initialPerson;
  final bool initialIsLoan;
  final String initialLoanSubtype;

  const TransactionForm({
    super.key,
    required this.mode,
    this.transaction,
    this.initialAmount,
    this.initialDate,
    this.smsTransactionId,
    this.initialPaymentMethod,
    this.initialBankName,
    this.initialAccountNumber,
    this.initialPayee,
    this.initialCategory,
    this.initialCategoryId,
    this.initialPerson,
    this.initialIsLoan = false,
    this.initialLoanSubtype = 'new',
  });

  @override
  TransactionFormState createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  // Core Fields
  String? _selectedCategory;
  String? _selectedCategoryId;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Account? _selectedAccount;

  // Conditional Fields
  Person? _selectedPerson;
  bool _isLoan = false;
  String _loanSubtype = 'new'; // 'new' vs 'repayment'

  // Power Fields (Hidden by default)
  List<Tag> _selectedFolders = [];
  String? _selectedSubscriptionId;
  DateTime? _reminderDate;
  Uint8List? _newReceiptData;
  String? _existingReceiptUrl;
  bool _isDeletingReceipt = false;
  TransactionModel? _selectedLinkedTransaction;

  // View State for Power Fields
  bool _showFolders = false;
  bool _showSubscription = false;
  bool _showReceipt = false;
  bool _showLinkedTransaction = false;

  bool _isDirty = false;
  bool _isLoadingAccount = true;

  // Lists
  final _nonCashPaymentMethods = ["Card", "UPI", "Net banking", "Other"];
  final _cashPaymentMethods = ["Cash", "Other"];

  dynamic _getCategoryIcon(String name, {String? categoryId}) {
    if (categoryId != null) {
      final categoryProvider = context.read<CategoryProvider>();
      final category = categoryProvider.categories.firstWhereOrNull(
        (c) => c.id == categoryId,
      );
      if (category != null) {
        return GoalIconRegistry.getIcon(category.iconKey);
      }
    }

    // Legacy Fallback
    switch (name.toLowerCase()) {
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

  static final Map<String, dynamic> _paymentMethodIcons = {
    'Cash': HugeIcons.strokeRoundedCash02,
    'UPI': HugeIcons.strokeRoundedQrCode01,
    'Card': HugeIcons.strokeRoundedCreditCardPos,
    'Net banking': HugeIcons.strokeRoundedBank,
    'Other': HugeIcons.strokeRoundedPayment01,
  };

  dynamic _getMethodIcon(String name) {
    return _paymentMethodIcons[name] ?? HugeIcons.strokeRoundedMoney03;
  }

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAccount();
    _checkAutoAddFolders();
    _amountController.addListener(_markAsDirty);
    _descController.addListener(_markAsDirty);
  }

  void _initializeData() {
    if (_isEditing) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _descController.text = tx.description;
      _selectedCategory = tx.category;
      _selectedCategoryId = tx.categoryId;

      // Handle legacy migration if id is null
      if (_selectedCategoryId == null && _selectedCategory != null) {
        final categoryProvider = context.read<CategoryProvider>();
        final match = categoryProvider.categories.firstWhereOrNull(
          (c) =>
              c.mode == widget.mode &&
              c.name.toLowerCase() == _selectedCategory?.toLowerCase(),
        );
        if (match != null) {
          _selectedCategoryId = match.id;
        }
      }
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.timestamp;
      _selectedTime = TimeOfDay.fromDateTime(tx.timestamp);

      // Load Tags & Toggle Visibility
      if (tx.tags != null && tx.tags!.isNotEmpty) {
        try {
          _selectedFolders = List<Tag>.from(tx.tags!.whereType<Tag>());
          _showFolders = true;
        } catch (_) {}
      }

      // Load Person
      if (tx.people?.isNotEmpty == true) {
        _selectedPerson = tx.people!.first;
        _isLoan = tx.isCredit != null;
      }

      _reminderDate = tx.reminderDate;

      // Load Subscription
      if (tx.subscriptionId != null) {
        _selectedSubscriptionId = tx.subscriptionId;
        _showSubscription = true;
      }

      // Load Receipt
      if (tx.receiptUrl != null) {
        _existingReceiptUrl = tx.receiptUrl;
        _showReceipt = true;
      }

      // Load Linked Transaction
      if (tx.linkedTransactionId != null) {
        final provider = Provider.of<TransactionProvider>(
          context,
          listen: false,
        );
        final found = provider.transactions.firstWhereOrNull(
          (t) => t.transactionId == tx.linkedTransactionId,
        );
        if (found != null) {
          _selectedLinkedTransaction = found;
          _showLinkedTransaction = true;
        }
      }
    } else {
      // New Transaction Logic
      if (widget.initialAmount != null) {
        _amountController.text =
            double.tryParse(widget.initialAmount!)?.toStringAsFixed(0) ?? '';
      }
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      _selectedPaymentMethod = widget.initialPaymentMethod;

      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory;
        _selectedCategoryId = widget.initialCategoryId;
      }

      // if (widget.initialCategory != null) {
      //   final validCategories = widget.mode == TransactionMode.expense
      //       ? TransactionCategories.expense
      //       : TransactionCategories.income;
      //   if (validCategories.contains(widget.initialCategory)) {
      //     _selectedCategory = widget.initialCategory;

      //     // Try to find the matching ID for the initial category
      //     final categoryProvider = context.read<CategoryProvider>();
      //     final match = categoryProvider.categories.firstWhereOrNull(
      //       (c) =>
      //           c.mode == widget.mode &&
      //           c.name.toLowerCase() == _selectedCategory?.toLowerCase(),
      //     );
      //     if (match != null) {
      //       _selectedCategoryId = match.id;
      //     }
      //   }
      // }

      // if (_selectedCategory == null || _selectedCategoryId == null) {
      //   final categoryProvider = context.read<CategoryProvider>();
      //   final defaultCat = categoryProvider.categories.firstWhereOrNull(
      //     (c) => c.mode == widget.mode && c.isDefault,
      //   );

      //   if (defaultCat != null) {
      //     _selectedCategory = defaultCat.name;
      //     _selectedCategoryId = defaultCat.id;
      //   } else {
      //     _selectedCategory = 'Others';
      //     // Start of legacy others fallback
      //     final match = categoryProvider.categories.firstWhereOrNull(
      //       (c) => c.mode == widget.mode && c.name == 'Others',
      //     );
      //     if (match != null) _selectedCategoryId = match.id;
      //   }
      // }

      if (widget.initialPayee != null && widget.initialPayee!.isNotEmpty) {
        _descController.text = widget.initialPayee!;
      }
      _selectedCategory = widget.initialCategory;
      _selectedCategoryId = widget.initialCategoryId;
      _selectedPaymentMethod = widget.initialPaymentMethod;
      if (widget.initialPerson != null) {
        _selectedPerson = widget.initialPerson;
      }
      _isLoan = widget.initialIsLoan;
      _loanSubtype = widget.initialLoanSubtype;

      _existingReceiptUrl = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only attempt to resolve if we are creating a NEW transaction and missing an ID
    if (!_isEditing && _selectedCategoryId == null) {
      final categoryProvider = Provider.of<CategoryProvider>(context);

      if (!categoryProvider.isLoading &&
          categoryProvider.categories.isNotEmpty) {
        // --- SCENARIO 1: We have a category name (from legacy Kotlin), but no ID. ---
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          final matchedCat = categoryProvider.categories.firstWhereOrNull(
            (c) =>
                c.mode == widget.mode &&
                c.name.toLowerCase() == _selectedCategory!.toLowerCase() &&
                !c.isDeleted,
          );

          if (matchedCat != null) {
            _applyCategory(matchedCat);
            return; // Stop here!
          }
        }

        // --- SCENARIO 2: THE QUICK-SAVE FALLBACK (Match by Payee/Keywords) ---
        // If Kotlin sent null, let's scan the description (payee) text against our keywords.
        final String textToMatch = _descController.text.trim().toLowerCase();

        if (textToMatch.isNotEmpty) {
          CategoryModel? bestMatch;
          int bestMatchLength = 0;

          // Search all active categories for this mode
          final modeCategories = categoryProvider.categories.where(
            (c) => c.mode == widget.mode && !c.isDeleted,
          );

          for (var cat in modeCategories) {
            for (var keyword in cat.keywords) {
              final kw = keyword.toLowerCase().trim();
              if (kw.isNotEmpty && textToMatch.contains(kw)) {
                // Rule: Longest keyword match wins (e.g. "uber eats" > "uber")
                if (kw.length > bestMatchLength) {
                  bestMatchLength = kw.length;
                  bestMatch = cat;
                }
              }
            }
          }

          if (bestMatch != null) {
            _applyCategory(bestMatch);
            return; // Stop here, we found a match!
          }
        }

        // --- SCENARIO 3: Ultimate Fallback (System Default) ---
        final defaultCat = categoryProvider.categories.firstWhereOrNull(
          (c) => c.mode == widget.mode && c.isDefault && !c.isDeleted,
        );

        if (defaultCat != null) {
          _applyCategory(defaultCat);
        }
      }
    }
  }

  // Helper method to keep code clean and ensure safe state updates
  void _applyCategory(CategoryModel cat) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedCategoryId == null) {
        setState(() {
          _selectedCategory = cat.name;
          _selectedCategoryId = cat.id;
        });
      }
    });
  }

  void reset() {
    setState(() {
      _amountController.clear();
      _descController.clear();

      // Reset to defaults
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);

      // Re-initialize category based on mode
      // Re-initialize category based on mode
      final categoryProvider = context.read<CategoryProvider>();
      final defaultCat = categoryProvider.categories.firstWhereOrNull(
        (c) => c.mode == widget.mode && c.isDefault,
      );

      if (defaultCat != null) {
        _selectedCategory = defaultCat.name;
        _selectedCategoryId = defaultCat.id;
      } else {
        _selectedCategory = 'Others';
        // Fallback logic
        final validCategories = widget.mode == TransactionMode.expense
            ? TransactionCategories.expense
            : TransactionCategories.income;
        if (!validCategories.contains(_selectedCategory)) {
          _selectedCategory = validCategories.first;
        }
        // Try to find ID for fallback
        final match = categoryProvider.categories.firstWhereOrNull(
          (c) => c.mode == widget.mode && c.name == _selectedCategory,
        );
        if (match != null) _selectedCategoryId = match.id;
      }

      // Reset Power Fields
      _selectedFolders = [];
      _selectedPerson = null;
      _isLoan = false;
      _loanSubtype = 'new';
      _selectedSubscriptionId = null;
      _reminderDate = null;
      _newReceiptData = null;
      _existingReceiptUrl = null;
      _isDeletingReceipt = false;

      // Reset View State
      _showFolders = false;
      _showSubscription = false;
      _showFolders = false;
      _showSubscription = false;
      _showReceipt = false;
      _showLinkedTransaction = false;

      _isDirty = false;
    });

    // Re-check auto-folders for today
    _checkAutoAddFolders();
  }

  Future<void> _checkAutoAddFolders() async {
    if (_isEditing && _selectedFolders.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final metaProvider = Provider.of<MetaProvider>(context, listen: false);

      // Polling for loading state (up to 2 seconds)
      int retries = 0;
      while (metaProvider.isLoading && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (!mounted) return;
      }

      final autoTags = metaProvider.getAutoAddTagsForDate(_selectedDate);
      if (autoTags.isNotEmpty) {
        setState(() {
          _selectedFolders = autoTags;
          _showFolders = true;
        });
      }
    });
  }

  Future<void> _initializeAccount() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );

      // Wait for accounts to load
      int retries = 0;
      while (accountProvider.accounts.isEmpty && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (!mounted) return;
      }

      Account? foundAccount;
      if (_isEditing && widget.transaction?.accountId != null) {
        try {
          foundAccount = accountProvider.accounts.firstWhere(
            (acc) => acc.id == widget.transaction!.accountId,
          );
        } catch (_) {}
      } else if (widget.initialAccountNumber != null) {
        foundAccount = await accountProvider.findOrCreateAccount(
          bankName: widget.initialBankName ?? 'Unknown Bank',
          accountNumber: widget.initialAccountNumber!,
        );
      } else {
        foundAccount = await accountProvider.getPrimaryAccount();
      }

      if (mounted) {
        setState(() {
          if (foundAccount != null) {
            _selectedAccount = foundAccount;
            if (!_isEditing) {
              final isCash = foundAccount.bankName.toLowerCase() == 'cash';
              _selectedPaymentMethod ??= (isCash ? 'Cash' : 'UPI');
            }
          }
          _isLoadingAccount = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  bool _validateCustomFields() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return false;
    }
    if (_selectedCategory == 'People' && _selectedPerson == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a person.')));
      return false;
    }
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.')),
      );
      return false;
    }
    return true;
  }

  Future<bool> save(String currencyCode, {bool stayOnPage = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_validateCustomFields()) {
      return false;
    }
    setState(() => _isDirty = false);

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    bool? isCreditForModel;
    if (_selectedCategory == 'People' && _isLoan) {
      isCreditForModel = (widget.mode == TransactionMode.expense);
    }
    final isCreditAccount = _selectedAccount?.accountType == 'credit';
    final purchaseType =
        (isCreditAccount && widget.mode == TransactionMode.expense)
        ? 'credit'
        : 'debit';

    // Upload Receipt Logic
    String? finalReceiptUrl = _existingReceiptUrl;
    if (_isDeletingReceipt) {
      finalReceiptUrl = null;
      if (_existingReceiptUrl != null) {
        ReceiptService().deleteReceipt(_existingReceiptUrl!);
      }
    }

    if (_newReceiptData != null) {
      final receiptId = const Uuid().v4();
      try {
        finalReceiptUrl = await ReceiptService().uploadReceipt(
          imageData: _newReceiptData!,
          userId: Provider.of<AuthProvider>(context, listen: false).user!.uid,
          transactionId: receiptId,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload receipt: $e')),
          );
        }
      }
    }

    if (_isEditing) {
      final updatedTransaction = widget.transaction!.copyWith(
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        categoryId: _selectedCategoryId,
        tags: _selectedFolders.isNotEmpty ? _selectedFolders : [],
        people: _selectedPerson != null ? [_selectedPerson!] : [],
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: () => _selectedSubscriptionId,
        accountId: () => _selectedAccount?.id,
        purchaseType: purchaseType,
        currency: currencyCode,
        receiptUrl: () => finalReceiptUrl,
        isTransfer: _selectedLinkedTransaction != null ? true : null,
        linkedTransactionId: () => _selectedLinkedTransaction?.transactionId,
      );
      await txProvider.updateTransaction(updatedTransaction);
      if (_selectedLinkedTransaction != null) {
        await txProvider.linkTransactions(
          updatedTransaction,
          _selectedLinkedTransaction!,
        );
      }

      // Handle Debts
      if (_selectedPerson != null && _isLoan) {
        await _updatePersonDebt(peopleProvider, amount);
      }

      _cleanupSms();
      if (!mounted) return true;
      Navigator.of(context).pop(true);
      return true;
    } else {
      final newTransaction = TransactionModel(
        transactionId: const Uuid().v4(),
        type: widget.mode == TransactionMode.expense ? 'expense' : 'income',
        amount: amount,
        timestamp: _selectedDate,
        description: _descController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
        category: _selectedCategory!,
        categoryId: _selectedCategoryId,
        tags: _selectedFolders.isNotEmpty ? _selectedFolders : null,
        people: _selectedPerson != null ? [_selectedPerson!] : null,
        isCredit: isCreditForModel,
        reminderDate: _reminderDate,
        subscriptionId: _selectedSubscriptionId,
        accountId: _selectedAccount?.id,
        currency: currencyCode,
        purchaseType: purchaseType,
        receiptUrl: finalReceiptUrl,
        isTransfer: _selectedLinkedTransaction != null ? true : null,
        linkedTransactionId: _selectedLinkedTransaction?.transactionId,
      );
      await txProvider.addTransaction(newTransaction);
      if (_selectedLinkedTransaction != null) {
        await txProvider.linkTransactions(
          newTransaction,
          _selectedLinkedTransaction!,
        );
      }

      if (_selectedPerson != null && _isLoan) {
        await _updatePersonDebt(peopleProvider, amount);
      }

      _cleanupSms();
      if (!mounted) return true;

      if (stayOnPage) {
        reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Transaction saved! Record another.'),
            duration: Duration(seconds: 2),
          ),
        );
        return true;
      } else {
        Navigator.pop(context, true);
        return true;
      }
    }
  }

  Future<void> _updatePersonDebt(PeopleProvider provider, double amount) async {
    Person updatedPerson = _selectedPerson!;
    if (widget.mode == TransactionMode.expense) {
      if (_loanSubtype == 'new') {
        updatedPerson = updatedPerson.copyWith(
          owesYou: updatedPerson.owesYou + amount,
        );
      } else {
        double newYouOwe = updatedPerson.youOwe - amount;
        if (newYouOwe < 0) newYouOwe = 0;
        updatedPerson = updatedPerson.copyWith(youOwe: newYouOwe);
      }
    } else {
      if (_loanSubtype == 'new') {
        updatedPerson = updatedPerson.copyWith(
          youOwe: updatedPerson.youOwe + amount,
        );
      } else {
        double newOwesYou = updatedPerson.owesYou - amount;
        if (newOwesYou < 0) newOwesYou = 0;
        updatedPerson = updatedPerson.copyWith(owesYou: newOwesYou);
      }
    }

    if (updatedPerson.owesYou > 0 && updatedPerson.youOwe > 0) {
      final overlap = updatedPerson.owesYou < updatedPerson.youOwe
          ? updatedPerson.owesYou
          : updatedPerson.youOwe;
      updatedPerson = updatedPerson.copyWith(
        owesYou: updatedPerson.owesYou - overlap,
        youOwe: updatedPerson.youOwe - overlap,
      );
    }
    await provider.updatePerson(updatedPerson);
  }

  void _cleanupSms() {
    if (widget.smsTransactionId != null) {
      try {
        _platform
            .invokeMethod('removePendingTransaction', {
              'id': widget.smsTransactionId,
            })
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccount) {
      return const Center(
        child: CircularProgressIndicator(strokeCap: StrokeCap.round),
      );
    }

    final appColors = Theme.of(context).extension<AppColors>()!;
    final heroColor = widget.mode == TransactionMode.expense
        ? appColors.expense
        : appColors.income;

    final colorScheme = Theme.of(context).colorScheme;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, res) async {
        if (didPop) return;
        final bool shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // 1. HERO AMOUNT
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: AmountInputHero(
                controller: _amountController,
                color: heroColor,
              ),
            ),

            // 2. METADATA ROW (Date + Time + Account)
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DatePill(selectedDate: _selectedDate, onTap: _pickDate),
                  const SizedBox(width: 8),
                  TimePill(time: _selectedTime, onTap: _pickTime),
                  const SizedBox(width: 8),
                  CompactAccountPill(
                    accountName: _selectedAccount?.bankName ?? 'Select',
                    methodName: _selectedPaymentMethod ?? 'Method',
                    onTap: _showAccountMethodPicker,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. SCROLLABLE FORM BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                children: [
                  // --- ESSENTIALS ---
                  FunkyPickerTile(
                    icon: HugeIcons.strokeRoundedMenu01,
                    label: "Category",
                    value: _selectedCategory,
                    valueIcon: _selectedCategory != null
                        ? _getCategoryIcon(
                            _selectedCategory!,
                            categoryId: _selectedCategoryId,
                          )
                        : null,
                    valueColor: _selectedCategory != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onTap: _showCategoryPicker,
                    isError: _selectedCategory == null,
                  ),

                  if (_selectedCategory == 'People') ...[
                    const SizedBox(height: 12),
                    _buildPeopleSection(context),
                  ],

                  const SizedBox(height: 12),

                  FunkyTextField(
                    controller: _descController,
                    label: widget.mode == TransactionMode.expense
                        ? "Sent to or payee"
                        : "Received from or payer",
                    icon: HugeIcons.strokeRoundedNote01,
                  ),

                  const SizedBox(height: 24),

                  // --- POWER OPTION SECTIONS (Animated) ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showFolders
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FunkyPickerTile(
                              icon: HugeIcons.strokeRoundedCalendar03,
                              label: "Add to Folders",
                              value: _selectedFolders.isEmpty ? "Select" : null,
                              valueWidget: _selectedFolders.isEmpty
                                  ? null
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: BouncingScrollPhysics(),
                                      child: Row(
                                        children: [
                                          ..._selectedFolders.map(
                                            (folder) => Container(
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: folder.color != null
                                                    ? Color(
                                                        folder.color!,
                                                      ).withValues(alpha: 0.15)
                                                    : colorScheme.primary
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: folder.color != null
                                                      ? Color(
                                                          folder.color!,
                                                        ).withValues(alpha: 0.3)
                                                      : colorScheme.primary
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedFolder02,
                                                    size: 14,
                                                    color: folder.color != null
                                                        ? Color(folder.color!)
                                                        : colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    folder.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          folder.color != null
                                                          ? Color(folder.color!)
                                                          : colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: InkWell(
                                              onTap: _showFolderPicker,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: colorScheme.primary
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  "+ Add to another Folder",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              onTap: _showFolderPicker,
                              trailingAction: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  child: const Icon(Icons.close, size: 14),
                                  onTap: () => setState(() {
                                    _showFolders = false;
                                    _selectedFolders.clear();
                                  }),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showSubscription
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Consumer<SubscriptionProvider>(
                              builder: (context, subProvider, _) {
                                final sub = subProvider.subscriptions
                                    .where(
                                      (s) => s.id == _selectedSubscriptionId,
                                    )
                                    .firstOrNull;
                                return FunkyPickerTile(
                                  icon: HugeIcons.strokeRoundedRotate02,
                                  label: "Recurring",
                                  value: sub?.name ?? "Select",
                                  leadingValueWidget: sub != null
                                      ? CircleAvatar(
                                          radius: 8,
                                          backgroundColor:
                                              colorScheme.surfaceContainer,
                                          child: Text(
                                            sub.name
                                                .trim()
                                                .split(' ')
                                                .map((l) => l[0])
                                                .take(2)
                                                .join()
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                  valueColor: sub != null
                                      ? colorScheme.onSurface
                                      : null,
                                  onTap: () => _showSubscriptionPicker(
                                    subProvider.subscriptions,
                                  ),
                                  trailingAction: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      child: const Icon(Icons.close, size: 14),
                                      onTap: () => setState(() {
                                        _showSubscription = false;
                                        _selectedSubscriptionId = null;
                                      }),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showReceipt
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReceiptCard(),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showLinkedTransaction
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLinkedTransactionCard(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 4. ACTION CHIPS DECK
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  children: [
                    if (!_showFolders)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedFolderAdd,
                        label: "Folder",
                        onTap: () {
                          setState(() => _showFolders = true);
                          _showFolderPicker();
                        },
                      ),
                    if (!_showReceipt)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedCameraAdd01,
                        label: "Receipt",
                        onTap: () {
                          setState(() => _showReceipt = true);
                          _pickReceipt();
                        },
                      ),
                    if (!_showSubscription &&
                        widget.mode == TransactionMode.expense)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedRotate02,
                        label: "Link Recurring",
                        onTap: () {
                          setState(() => _showSubscription = true);
                          _showSubscriptionPicker(
                            subscriptionProvider.subscriptions,
                          );
                        },
                      ),
                    TransactionActionChip(
                      icon: HugeIcons.strokeRoundedMoneyExchange01,
                      label: "Convert",
                      onTap: _openCurrencyConverter,
                    ),
                    if (!_showLinkedTransaction)
                      TransactionActionChip(
                        icon: HugeIcons.strokeRoundedLink01,
                        label: "Link Transfer Transaction",
                        onTap: () {
                          setState(() => _showLinkedTransaction = true);
                          _showLinkTransactionModal();
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 74),
          ],
        ),
      ),
    );
  }

  // --- NEW WIDGETS ---
  Widget _buildPeopleSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          FunkyPickerTile(
            icon: HugeIcons.strokeRoundedUser,
            label: "Person",
            value: _selectedPerson?.fullName,
            leadingValueWidget: _selectedPerson != null
                ? CircleAvatar(
                    radius: 8,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      _selectedPerson!.fullName
                          .trim()
                          .split(' ')
                          .map((l) => l[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  )
                : null,
            onTap: _showPeopleModal,
            isCompact: true,
            isError: _selectedPerson == null,
          ),
          // const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Track as Loan",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _isLoan,
                      onChanged: (v) => setState(() {
                        _isLoan = v;
                        _markAsDirty();
                      }),
                    ),
                  ],
                ),
                if (_isLoan) ...[
                  const Divider(height: 24),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          widget.mode == TransactionMode.expense
                              ? "Loan Given"
                              : "Loan Taken",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          widget.mode == TransactionMode.expense
                              ? "This person will owe you the amount"
                              : "You will owe this person the amount",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: 'new',
                        groupValue: _loanSubtype,
                        onChanged: (v) => setState(() => _loanSubtype = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      // const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text(
                          "Repayment",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          widget.mode == TransactionMode.expense
                              ? "Paying back the amount you owed"
                              : "Collecting back the amount they owed",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: 'repayment',
                        groupValue: _loanSubtype,
                        onChanged: (v) => setState(() => _loanSubtype = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Stack(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _newReceiptData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_newReceiptData!, fit: BoxFit.cover),
                )
              : _existingReceiptUrl != null && !_isDeletingReceipt
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _existingReceiptUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                )
              : Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text("Upload Image"),
                    onPressed: _pickReceipt,
                  ),
                ),
        ),
        if (_newReceiptData != null ||
            (_existingReceiptUrl != null && !_isDeletingReceipt))
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 14,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () => setState(() {
                  _newReceiptData = null;
                  if (_existingReceiptUrl != null) {
                    _isDeletingReceipt = true;
                  }
                  if (_existingReceiptUrl == null) _showReceipt = false;
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkedTransactionCard() {
    return FunkyPickerTile(
      icon: HugeIcons.strokeRoundedArrowRight01,
      label: "Linked Transaction",
      value: _selectedLinkedTransaction?.description ?? "Select Transaction",
      leadingValueWidget: _selectedLinkedTransaction != null
          ? CircleAvatar(
              radius: 8,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: HugeIcon(
                icon: _selectedLinkedTransaction!.type == 'income'
                    ? HugeIcons.strokeRoundedMoney03
                    : HugeIcons.strokeRoundedBank,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
      valueColor: _selectedLinkedTransaction != null
          ? Theme.of(context).colorScheme.onSurface
          : null,
      onTap: _showLinkTransactionModal,
      trailingAction: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: const Icon(Icons.close, size: 14),
          onTap: () => setState(() {
            _showLinkedTransaction = false;
            _selectedLinkedTransaction = null;
          }),
        ),
      ),
    );
  }

  // --- Helpers ---
  void _showAccountMethodPicker() {
    final accountProvider = Provider.of<AccountProvider>(
      context,
      listen: false,
    );
    showCustomAccountModal(context, accountProvider.accounts, (acc) {
      setState(() {
        _selectedAccount = acc;
        _markAsDirty();
      });
      _showPaymentMethodPicker();
    }, selectedId: _selectedAccount?.id);
  }

  void _showCategoryPicker() async {
    final categoryProvider = context.read<CategoryProvider>();
    final categories = categoryProvider.categories
        .where((c) => c.mode == widget.mode && !c.isDeleted)
        .toList();

    final selected = await showModernPickerSheet(
      context: context,
      title: 'SELECT CATEGORY',
      showSearch: true,
      showCreateNew: true,
      onCreateNew: () async {
        Navigator.pop(context); // Close the picker list
        HapticFeedback.selectionClick();
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddEditCategoryModalSheet(),
        );

        // After the modal closes, if a category was added, we select it
        if (!mounted) return;
        final newCatProvider = context.read<CategoryProvider>();
        final latestCategories = newCatProvider.categories
            .where((c) => c.mode == widget.mode && !c.isDeleted)
            .toList();

        if (latestCategories.length > categories.length) {
          // A new category was added, find and select it
          // Assuming it's added at the end or we can just sort by created time if available.
          // For now, we take the one not in the old list.
          final oldIds = categories.map((c) => c.id).toSet();
          final newCat = latestCategories.firstWhereOrNull(
            (c) => !oldIds.contains(c.id),
          );
          if (newCat != null) {
            setState(() {
              _selectedCategoryId = newCat.id;
              _selectedCategory = newCat.name;
              if (newCat.name != 'People') _selectedPerson = null;
              _markAsDirty();
            });
            if (newCat.name == 'People') _showPeopleModal();
          }
        }
      },
      items: categories
          .map(
            (c) => PickerItem(
              id: c.id,
              label: c.name,
              icon: GoalIconRegistry.getIcon(c.iconKey),
            ),
          )
          .toList(),
      selectedId: _selectedCategoryId,
    );
    if (selected != null) {
      final selectedCat = categories.firstWhere((c) => c.id == selected);
      setState(() {
        _selectedCategoryId = selected;
        _selectedCategory = selectedCat.name;
        if (selectedCat.name != 'People') _selectedPerson = null;
        _markAsDirty();
      });
      if (selectedCat.name == 'People') _showPeopleModal();
    }
  }

  void _showPaymentMethodPicker() async {
    final isCash = _selectedAccount?.bankName.toLowerCase() == 'cash';
    final methods = isCash ? _cashPaymentMethods : _nonCashPaymentMethods;
    final selected = await showModernPickerSheet(
      context: context,
      title: 'Select Method',
      items: methods
          .map((m) => PickerItem(id: m, label: m, icon: _getMethodIcon(m)))
          .toList(),
      selectedId: _selectedPaymentMethod,
    );
    if (selected != null) {
      setState(() {
        _selectedPaymentMethod = selected;
        _markAsDirty();
      });
    }
  }

  void _showPeopleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        builder: (_, c) => PersonPickerSheet(
          selectedPerson: _selectedPerson,
          scrollController: c,
          onSelected: (p) => setState(() {
            _selectedPerson = p;
            _markAsDirty();
          }),
        ),
      ),
    );
  }

  void _showFolderPicker() {
    final meta = Provider.of<MetaProvider>(context, listen: false);
    final tx = Provider.of<TransactionProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        builder: (_, c) => FolderPickerSheet(
          metaProvider: meta,
          txProvider: tx,
          selectedFolders: _selectedFolders,
          scrollController: c,
          onSelected: (tags) => setState(() {
            _selectedFolders = tags;
            _markAsDirty();
          }),
        ),
      ),
    );
  }

  void _showSubscriptionPicker(List<Subscription> subs) {
    showModernPickerSheet(
      context: context,
      title: "Recurring Payments",
      items: subs
          .map(
            (s) => PickerItem(id: s.id, label: s.name, icon: Icons.autorenew),
          )
          .toList(),
      showCreateNew: true,
      onCreateNew: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
      ),
      selectedId: _selectedSubscriptionId,
    ).then((id) {
      if (id != null) {
        setState(() {
          _selectedSubscriptionId = id;
          _markAsDirty();
        });
      }
    });
  }

  void _pickReceipt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReceiptModalSheet(
        uploadImmediately: false,
        onComplete: (_, bytes) {
          if (bytes != null) {
            setState(() {
              _newReceiptData = bytes;
              _isDeletingReceipt = false;
              _markAsDirty();
            });
          }
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        _markAsDirty();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
        _markAsDirty();
      });
    }
  }

  void _openCurrencyConverter() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CurrencyConverterModal(
        initialFromCurrency: 'USD',
        defaultTargetCurrency: settings.currencyCode,
        initialAmount: double.tryParse(_amountController.text),
      ),
    );
    if (result != null) {
      setState(() {
        _amountController.text = result.toStringAsFixed(2);
        _markAsDirty();
      });
    }
  }

  void _showLinkTransactionModal() async {
    final result = await showModalBottomSheet<TransactionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkTransactionModalSheet(
        excludeTransaction: widget.transaction,
        sourceTransactionType: widget.mode == TransactionMode.expense
            ? 'expense'
            : 'income',
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLinkedTransaction = result;
        _showLinkedTransaction = true;
        _markAsDirty();
      });
    } else {
      // If cancelled and no transaction selected, hide the card
      if (_selectedLinkedTransaction == null) {
        setState(() => _showLinkedTransaction = false);
      }
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('Unsaved changes will be lost.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        )) ??
        false;
  }
}
