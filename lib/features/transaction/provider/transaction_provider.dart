import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? categories;
  final List<Tag>? tags;
  final List<Person>? people;
  final List<String>? paymentMethods;
  final double? minAmount;
  final double? maxAmount;
  final String? type;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categories,
    this.tags,
    this.people,
    this.paymentMethods,
    this.minAmount,
    this.maxAmount,
    this.type,
  });

  static const TransactionFilter empty = TransactionFilter();

  TransactionFilter copyWith({
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
    ValueGetter<List<String>?>? categories,
    ValueGetter<List<Tag>?>? tags,
    ValueGetter<List<Person>?>? people,
    ValueGetter<List<String>?>? paymentMethods,
    ValueGetter<double?>? minAmount,
    ValueGetter<double?>? maxAmount,
    ValueGetter<String?>? type,
  }) {
    return TransactionFilter(
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      categories: categories != null ? categories() : this.categories,
      tags: tags != null ? tags() : this.tags,
      people: people != null ? people() : this.people,
      paymentMethods: paymentMethods != null
          ? paymentMethods()
          : this.paymentMethods,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
      type: type != null ? type() : this.type,
    );
  }

  bool get hasActiveFilters => this != empty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          const ListEquality().equals(categories, other.categories) &&
          const ListEquality().equals(tags, other.tags) &&
          const ListEquality().equals(people, other.people) &&
          const ListEquality().equals(paymentMethods, other.paymentMethods) &&
          minAmount == other.minAmount &&
          maxAmount == other.maxAmount &&
          type == other.type;

  @override
  int get hashCode => Object.hash(
    startDate,
    endDate,
    type,
    minAmount,
    maxAmount,
    const ListEquality().hash(categories),
    const ListEquality().hash(tags),
    const ListEquality().hash(people),
    const ListEquality().hash(paymentMethods),
  );
}

class FilterResult {
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpense;

  double get balance => totalIncome - totalExpense;

  FilterResult({
    required this.transactions,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
  });

  static FilterResult empty = FilterResult(transactions: []);
}

// 1. ADD WidgetsBindingObserver MIXIN
class TransactionProvider with ChangeNotifier, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider authProvider;
  AccountProvider accountProvider;
  SettingsProvider settingsProvider;
  StreamSubscription? _transactionSubscription;

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading || authProvider.isAuthLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  String? _lastUserId;

  TransactionProvider({
    required this.authProvider,
    required this.accountProvider,
    required this.settingsProvider,
  }) {
    _lastUserId = authProvider.user?.uid;

    // 2. REGISTER OBSERVER
    WidgetsBinding.instance.addObserver(this);

    _listenToTransactions();
  }

  @override
  void dispose() {
    // 3. REMOVE OBSERVER
    WidgetsBinding.instance.removeObserver(this);
    _transactionSubscription?.cancel();
    super.dispose();
  }

  // 4. DETECT APP RESUME
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        "TransactionProvider: App resumed. Checking for background data...",
      );
      _syncPendingQuickSaves();
    }
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    final newUserId = authProvider.user?.uid;
    if (_lastUserId != newUserId) {
      _lastUserId = newUserId;
      _listenToTransactions();
    }
  }

  void updateAccountProvider(AccountProvider newAccountProvider) {
    accountProvider = newAccountProvider;
    notifyListeners();
  }

  void updateSettingsProvider(SettingsProvider newSettingsProvider) {
    settingsProvider = newSettingsProvider;
    notifyListeners();
  }

  void _listenToTransactions() async {
    _transactionSubscription?.cancel();
    final user = authProvider.user;
    if (user == null) {
      _transactions = [];
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. CACHE FIRST
    try {
      final cacheSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(milliseconds: 2500));

      if (cacheSnapshot.docs.isNotEmpty) {
        _transactions = cacheSnapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data()))
            .toList();
        _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Transaction cache load error or timeout: $e");
    }

    // 2. LIVE LISTENER
    _transactionSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            _transactions = snapshot.docs
                .map((doc) => TransactionModel.fromMap(doc.data()))
                .toList();
            _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (_transactions.isNotEmpty) {
              if (_isLoading) _isLoading = false;
            } else if (!snapshot.metadata.isFromCache) {
              if (_isLoading) _isLoading = false;
            }

            _error = null;
            notifyListeners();
          },
          onError: (e) {
            _error =
                "Failed to load transactions. Please check your connection.";
            _isLoading = false;
            notifyListeners();
          },
        );

    Future.delayed(const Duration(seconds: 2), () {
      if (_isLoading && _transactions.isEmpty) {
        _isLoading = false;
        try {
          notifyListeners();
        } catch (_) {}
      }
    });

    _syncPendingQuickSaves();
  }

  // 5. UPDATED SYNC LOGIC (Instant UI Update)
  Future<void> _syncPendingQuickSaves() async {
    final user = authProvider.user;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // CRITICAL: Reload prefs to catch writes from Background Isolate
      await prefs.reload();

      // 1. Sync Pending Accounts
      final String? pendingAccountsJson = prefs.getString(
        'pending_native_created_accounts',
      );
      if (pendingAccountsJson != null) {
        final List<dynamic> pendingAccountsList = jsonDecode(
          pendingAccountsJson,
        );
        if (pendingAccountsList.isNotEmpty) {
          debugPrint(
            "TransactionProvider: Syncing ${pendingAccountsList.length} offline accounts...",
          );
          for (final item in pendingAccountsList) {
            try {
              final account = Account.fromMap(item);
              await accountProvider.importAccount(account);
              debugPrint(
                "TransactionProvider: Imported account ${account.bankName}",
              );
            } catch (e) {
              debugPrint("TransactionProvider: Failed to import account: $e");
            }
          }
          await prefs.remove('pending_native_created_accounts');
        }
      }

      // 2. Sync Pending Transactions
      final String? pendingJson = prefs.getString(
        'pending_quick_save_transactions',
      );

      if (pendingJson != null) {
        final List<dynamic> pendingList = jsonDecode(pendingJson);
        if (pendingList.isEmpty) return;

        debugPrint(
          "TransactionProvider: Found ${pendingList.length} pending transactions.",
        );

        // --- OPTIMISTIC UI UPDATE START ---
        // Instantly add these to the UI before syncing to Firestore
        final List<TransactionModel> newLocalTransactions = [];
        for (final item in pendingList) {
          try {
            final txMap = Map<String, dynamic>.from(item);
            // Fix timestamp from JSON (int or string) to DateTime
            if (txMap['timestamp'] is int) {
              txMap['timestamp'] = DateTime.fromMillisecondsSinceEpoch(
                txMap['timestamp'],
              );
            } else if (txMap['timestamp'] is String) {
              txMap['timestamp'] = DateTime.parse(txMap['timestamp']);
            }

            final txModel = TransactionModel.fromMap(txMap);
            // Prevent duplicates
            if (!_transactions.any(
              (t) => t.transactionId == txModel.transactionId,
            )) {
              newLocalTransactions.add(txModel);
            }
          } catch (e) {
            debugPrint("Error creating optimistic model: $e");
          }
        }

        if (newLocalTransactions.isNotEmpty) {
          _transactions.addAll(newLocalTransactions);
          _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          notifyListeners(); // Updates the UI immediately!
          debugPrint("TransactionProvider: Optimistic UI update complete.");
        }
        // --- OPTIMISTIC UI UPDATE END ---

        // --- FIRESTORE SYNC ---
        int successCount = 0;
        final List<Map<String, dynamic>> failedList = [];
        final batch = _firestore.batch();
        bool batchHasOps = false;

        for (final item in pendingList) {
          try {
            final transactionData = item as Map<String, dynamic>;

            // Generate a proper ID for the final transaction
            final docRef = _firestore
                .collection('users')
                .doc(user.uid)
                .collection('transactions')
                .doc();

            // Update ID
            transactionData['transactionId'] = docRef.id;

            // Reconstruct Model (Ensure Timestamp is valid for Firestore)
            if (transactionData['timestamp'] is int) {
              transactionData['timestamp'] =
                  Timestamp.fromMillisecondsSinceEpoch(
                    transactionData['timestamp'],
                  );
            } else if (transactionData['timestamp'] is String) {
              transactionData['timestamp'] = Timestamp.fromDate(
                DateTime.parse(transactionData['timestamp']),
              );
            }

            // Reconstruct Model
            final txModel = TransactionModel.fromMap(transactionData);

            // Convert to Firestore map
            final firestoreMap = _transactionToMapWithPeople(txModel);
            batch.set(docRef, firestoreMap);
            batchHasOps = true;
            successCount++;
          } catch (e) {
            debugPrint(
              "TransactionProvider: Failed to queue transaction for sync: $e",
            );
            failedList.add(item as Map<String, dynamic>);
          }
        }

        if (batchHasOps) {
          await batch.commit();
          debugPrint(
            "TransactionProvider: Synced $successCount transactions to Cloud.",
          );

          if (failedList.isEmpty) {
            await prefs.remove('pending_quick_save_transactions');
          } else {
            await prefs.setString(
              'pending_quick_save_transactions',
              jsonEncode(failedList),
            );
          }
        }
      }
    } catch (e) {
      debugPrint(
        "TransactionProvider Critical: Error syncing pending quick saves: $e",
      );
    }
  }

  Map<String, dynamic> _transactionToMapWithPeople(
    TransactionModel transaction,
  ) {
    final map = transaction.toMap();
    map['timestamp'] = Timestamp.fromDate(transaction.timestamp);
    if (transaction.reminderDate != null) {
      map['reminderDate'] = Timestamp.fromDate(transaction.reminderDate!);
    }
    if (transaction.people != null) {
      map['people'] = transaction.people!.map((p) => p.toFirestore()).toList();
    } else {
      map['people'] = null;
    }
    return map;
  }

  // ... [Keep addTransaction, addCreditRepayment, addTransfer, updateTransaction, deleteTransaction, getFilteredResults, getTotal, etc. EXACTLY AS THEY WERE] ...

  // (Pasting the rest for completeness)
  Future<void> addTransaction(TransactionModel transaction) async {
    final user = authProvider.user;
    if (user == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.transactionId)
          .set(_transactionToMapWithPeople(transaction));
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> addCreditRepayment({
    required TransactionModel fromTransaction,
    required TransactionModel toTransaction,
  }) async {
    final user = authProvider.user;
    if (user == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(fromTransaction.transactionId),
        _transactionToMapWithPeople(fromTransaction),
      );
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(toTransaction.transactionId),
        _transactionToMapWithPeople(toTransaction),
      );
      await batch.commit();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> addTransfer(
    TransactionModel fromTransaction,
    TransactionModel toTransaction,
  ) async {
    final user = authProvider.user;
    if (user == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(fromTransaction.transactionId),
        _transactionToMapWithPeople(fromTransaction),
      );
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(toTransaction.transactionId),
        _transactionToMapWithPeople(toTransaction),
      );
      await batch.commit();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final user = authProvider.user;
    if (user == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.transactionId)
          .update(_transactionToMapWithPeople(transaction));
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final user = authProvider.user;
    if (user == null) return;
    final index = _transactions.indexWhere(
      (tx) => tx.transactionId == transactionId,
    );
    if (index == -1) return;
    final removedTransaction = _transactions[index];
    _transactions.removeAt(index);
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      _transactions.insert(index, removedTransaction);
      notifyListeners();
      debugPrint("Failed to delete transaction: $e");
    }
  }

  FilterResult getFilteredResults(TransactionFilter filter) {
    final filteredList = _transactions.where((t) {
      final inRange =
          (filter.startDate == null ||
              !t.timestamp.isBefore(filter.startDate!)) &&
          (filter.endDate == null || t.timestamp.isBefore(filter.endDate!));
      if (!inRange) return false;
      final typeMatch = filter.type == null || t.type == filter.type;
      if (!typeMatch) return false;
      final categoryMatch =
          filter.categories == null ||
          filter.categories!.isEmpty ||
          filter.categories!.contains(t.category);
      if (!categoryMatch) return false;
      final paymentMethodMatch =
          filter.paymentMethods == null ||
          filter.paymentMethods!.isEmpty ||
          filter.paymentMethods!.contains(t.paymentMethod);
      if (!paymentMethodMatch) return false;
      final amountMatch =
          (filter.minAmount == null || t.amount >= filter.minAmount!) &&
          (filter.maxAmount == null || t.amount <= filter.maxAmount!);
      if (!amountMatch) return false;
      final tagMatch =
          filter.tags == null ||
          filter.tags!.isEmpty ||
          (t.tags?.any(
                (txTag) => filter.tags!.any((fTag) => fTag.id == txTag.id),
              ) ??
              false);
      if (!tagMatch) return false;
      final personMatch =
          filter.people == null ||
          filter.people!.isEmpty ||
          (t.people?.any(
                (txPerson) =>
                    filter.people!.any((fPerson) => fPerson.id == txPerson.id),
              ) ??
              false);
      if (!personMatch) return false;
      return true;
    }).toList();

    double income = 0.0;
    double expense = 0.0;
    for (final t in filteredList) {
      if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'expense' && t.purchaseType == 'debit') {
        expense += t.amount;
      }
    }
    return FilterResult(
      transactions: filteredList,
      totalIncome: income,
      totalExpense: expense,
    );
  }

  double getTotal({
    required DateTime start,
    required DateTime end,
    String? type,
    List<String>? categories,
    List<Tag>? tags,
  }) {
    return _transactions
        .where((t) {
          final inRange =
              !t.timestamp.isBefore(start) && t.timestamp.isBefore(end);
          final typeMatch = type == null || t.type == type;
          final categoryMatch =
              categories == null || categories.contains(t.category);
          final tagMatch =
              tags == null ||
              t.tags!.any((tag) => tags.map((tg) => tg.id).contains(tag.id));
          bool isRealExpense = true;
          if (type == 'expense' && t.purchaseType == 'credit') {
            isRealExpense = false;
          }
          return inRange &&
              typeMatch &&
              categoryMatch &&
              tagMatch &&
              isRealExpense;
        })
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get todayIncome => _getForDay(DateTime.now(), type: "income");
  double get todayExpense => _getForDay(DateTime.now(), type: "expense");
  double get yesterdayIncome => _getForDay(
    DateTime.now().subtract(const Duration(days: 1)),
    type: "income",
  );
  double get yesterdayExpense => _getForDay(
    DateTime.now().subtract(const Duration(days: 1)),
    type: "expense",
  );
  double get thisWeekIncome => _getForRange(
    _startOfWeek(DateTime.now()),
    _endOfDay(DateTime.now()),
    type: "income",
  );
  double get thisWeekExpense => _getForRange(
    _startOfWeek(DateTime.now()),
    _endOfDay(DateTime.now()),
    type: "expense",
  );
  double get lastWeekIncome {
    final lastWeekStart = _startOfWeek(
      DateTime.now(),
    ).subtract(const Duration(days: 7));
    final lastWeekEnd = _startOfWeek(
      DateTime.now(),
    ).subtract(const Duration(seconds: 1));
    return _getForRange(lastWeekStart, lastWeekEnd, type: "income");
  }

  double get lastWeekExpense {
    final lastWeekStart = _startOfWeek(
      DateTime.now(),
    ).subtract(const Duration(days: 7));
    final lastWeekEnd = _startOfWeek(
      DateTime.now(),
    ).subtract(const Duration(seconds: 1));
    return _getForRange(lastWeekStart, lastWeekEnd, type: "expense");
  }

  double get thisMonthIncome {
    final range = BudgetCycleHelper.getCycleRange(
      targetMonth: DateTime.now().month,
      targetYear: DateTime.now().year,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );
    return _getForRange(range.start, range.end, type: "income");
  }

  double get thisMonthExpense {
    final range = BudgetCycleHelper.getCycleRange(
      targetMonth: DateTime.now().month,
      targetYear: DateTime.now().year,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );
    return _getForRange(range.start, range.end, type: "expense");
  }

  double get lastMonthIncome {
    final now = DateTime.now();
    var prevMonth = now.month - 1;
    var prevYear = now.year;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear--;
    }
    final range = BudgetCycleHelper.getCycleRange(
      targetMonth: prevMonth,
      targetYear: prevYear,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );
    return _getForRange(range.start, range.end, type: "income");
  }

  double get lastMonthExpense {
    final now = DateTime.now();
    var prevMonth = now.month - 1;
    var prevYear = now.year;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear--;
    }
    final range = BudgetCycleHelper.getCycleRange(
      targetMonth: prevMonth,
      targetYear: prevYear,
      mode: settingsProvider.budgetCycleMode,
      startDay: settingsProvider.budgetCycleStartDay,
    );
    return _getForRange(range.start, range.end, type: "expense");
  }

  double _getForDay(DateTime date, {String? type}) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getTotal(start: start, end: end, type: type);
  }

  double _getForRange(DateTime start, DateTime end, {String? type}) {
    return getTotal(start: start, end: end, type: type);
  }

  DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));
  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day).add(const Duration(days: 1));
  double getCreditDue(String accountId) {
    final accountTransactions = _transactions.where(
      (tx) => tx.accountId == accountId,
    );
    double purchases = 0.0;
    double payments = 0.0;
    for (final tx in accountTransactions) {
      if (tx.type == 'expense' && tx.category != 'Credit Repayment') {
        purchases += tx.amount;
      } else if (tx.type == 'income' || tx.category == 'Credit Repayment') {
        payments += tx.amount;
      }
    }
    final due = purchases - payments;
    return due > 0 ? due : 0.0;
  }

  List<Tag> getMostUsedTags({int limit = 6}) {
    final tagCounts = <String, int>{};
    final tagMap = <String, Tag>{};
    for (final tx in _transactions) {
      if (tx.tags != null) {
        for (final tag in tx.tags!) {
          tagCounts[tag.id] = (tagCounts[tag.id] ?? 0) + 1;
          tagMap[tag.id] = tag;
        }
      }
    }
    final sortedIds = tagCounts.keys.toList()
      ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));
    return sortedIds.take(limit).map((id) => tagMap[id]!).toList();
  }

  List<Tag> getRecentTags({int limit = 6}) {
    final recentTags = <Tag>[];
    final seenIds = <String>{};
    for (final tx in _transactions) {
      if (tx.tags != null) {
        for (final tag in tx.tags!) {
          if (!seenIds.contains(tag.id)) {
            seenIds.add(tag.id);
            recentTags.add(tag);
            if (recentTags.length >= limit) return recentTags;
          }
        }
      }
    }
    return recentTags;
  }
}
