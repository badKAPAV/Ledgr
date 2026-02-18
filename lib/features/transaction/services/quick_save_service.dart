import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:uuid/uuid.dart';

class QuickSaveService {
  static const String quickSaveTask = 'quick_save_transaction';

  static final QuickSaveService _instance = QuickSaveService._internal();

  factory QuickSaveService() {
    return _instance;
  }

  QuickSaveService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_ledgr');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> processQuickSave(Map<String, dynamic> ignoredData) async {
    try {
      await _initializeNotifications();
      final prefs = await SharedPreferences.getInstance();

      final String? userId = prefs.getString('last_user_id');
      if (userId == null) {
        throw Exception("User ID not found via 'last_user_id'.");
      }

      final String queueKey = 'native_pending_quick_saves';

      // 1. Reload to ensure we have the absolute latest data from disk
      await prefs.reload();
      final String? queueJson = prefs.getString(queueKey);

      if (queueJson == null || queueJson == '[]') return;

      final List<dynamic> initialQueue = jsonDecode(queueJson);

      // Track IDs that we have handled in this run
      final Set<int> processedIds = {};

      debugPrint(
        "QuickSaveService: Processing batch of ${initialQueue.length} items",
      );

      // 2. Process items
      for (var item in initialQueue) {
        int? notificationId;
        try {
          notificationId = item['notificationId'];
          if (notificationId != null) {
            processedIds.add(notificationId);
          }

          final Map<String, dynamic> txData = Map<String, dynamic>.from(
            item['data'],
          );
          txData['notification_id'] = notificationId;

          await _processSingleTransaction(txData, prefs, userId);
        } catch (e) {
          debugPrint(
            "QuickSaveService: Failed to process item $notificationId: $e",
          );
          // Note: We still added it to processedIds so we don't retry a "poison" item forever.
        }
      }

      // 3. Robust Cleanup (Race Condition Fix)
      // Re-fetch the queue in case new items were added by Kotlin while we were processing the loop above.
      await prefs.reload();
      final String? updatedQueueJson = prefs.getString(queueKey);

      List<dynamic> currentQueue = [];
      if (updatedQueueJson != null && updatedQueueJson != '[]') {
        currentQueue = jsonDecode(updatedQueueJson);
      }

      // Remove ONLY the items we actually processed
      final int beforeCount = currentQueue.length;
      currentQueue.removeWhere((item) {
        return processedIds.contains(item['notificationId']);
      });
      final int afterCount = currentQueue.length;

      debugPrint(
        "QuickSaveService: Cleanup complete. Removed ${beforeCount - afterCount} items. Remaining: $afterCount",
      );

      // Save back the remaining items (if any)
      await prefs.setString(queueKey, jsonEncode(currentQueue));
    } catch (e) {
      debugPrint("QuickSaveService Critical Failure: $e");
    }
  }

  Future<void> _processSingleTransaction(
    Map<String, dynamic> data,
    SharedPreferences prefs,
    String userId,
  ) async {
    // 1. Simulate "Thinking Time" to prevent race conditions
    await Future.delayed(const Duration(milliseconds: 500));

    int? notificationId = data['notification_id'];
    // debugPrint(
    //   "\n🔵 --- QUICK SAVE DEBUG START: Notification $notificationId ---",
    // );
    // debugPrint("Raw Data Keys: ${data.keys.toList()}");

    try {
      final double amount = (data['amount'] as num).toDouble();
      final String type = data['type'] ?? 'expense';

      // Forensic Log: Check exact values before processing
      final rawBank = data['bankName'];
      final rawAcc = data['accountNumber'];
      // debugPrint("Raw Bank: '$rawBank' (${rawBank.runtimeType})");
      // debugPrint("Raw Acc: '$rawAcc' (${rawAcc.runtimeType})");

      final String bankName = (rawBank?.toString() ?? '').trim();
      final String accountNumber = (rawAcc?.toString() ?? '').trim();
      final String payee = data['payee'] ?? '';
      final String category = data['category'] ?? 'Others';
      final String paymentMethod = data['paymentMethod'] ?? 'Other';

      // --- ACCOUNT RESOLUTION LOGIC ---
      String? targetAccountId;

      // Step A: Load Cache Freshly
      List<Account> cachedAccounts = [];
      try {
        await prefs.reload(); // Force reload from disk
        final String? accountsJson = prefs.getString(
          'quick_save_accounts_cache',
        );
        if (accountsJson != null) {
          final List<dynamic> decoded = jsonDecode(accountsJson);
          cachedAccounts = decoded.map((e) => Account.fromMap(e)).toList();
        }
        // debugPrint("Loaded ${cachedAccounts.length} cached accounts.");
      } catch (e) {
        // debugPrint("🔴 Cache Load Error: $e");
      }

      // Step B: The Decision Tree
      final bool hasBank = bankName.isNotEmpty;
      final bool hasNumber = accountNumber.isNotEmpty;
      // debugPrint("Condition Check: hasBank=$hasBank, hasNumber=$hasNumber");

      if (hasBank && hasNumber) {
        // debugPrint(
        //   "🟢 PATH: Specific data present. Searching for exact match...",
        // );

        // SEARCH: Look for Number match first (most unique)
        Account? match;
        try {
          // Manual loop for debugging
          for (var acc in cachedAccounts) {
            final bool numMatch =
                acc.accountNumber.trim() == accountNumber ||
                acc.accountNumber.endsWith(accountNumber);
            final bool bankMatch =
                acc.bankName.toLowerCase().contains(bankName.toLowerCase()) ||
                bankName.toLowerCase().contains(acc.bankName.toLowerCase());

            // if (bankMatch)
            // debugPrint(
            //   "   -> Potential Bank Match: ${acc.bankName}. Num Match: $numMatch",
            // );

            if (numMatch && bankMatch) {
              match = acc;
              break;
            }
          }
        } catch (e) {
          // debugPrint("🔴 Match Logic Error: $e");
        }

        if (match != null) {
          // debugPrint(
          //   "✅ FOUND MATCH: ${match.bankName} (${match.accountNumber}) -> ID: ${match.id}",
          // );
          targetAccountId = match.id;
        } else {
          // debugPrint("🟠 NO MATCH FOUND. Entering Creation Mode...");

          // CREATE NEW ACCOUNT
          final newId = const Uuid().v4();
          targetAccountId = newId;
          // debugPrint("   -> New ID Assigned Immediately: $newId");

          final newAccount = Account(
            id: newId,
            bankName: bankName,
            accountNumber: accountNumber,
            accountHolderName: 'Main',
            userId: userId,
            isPrimary: false,
            accountType: paymentMethod.toLowerCase().contains('credit')
                ? 'credit'
                : 'debit',
          );

          // Save to disk asynchronously
          try {
            await _persistNewAccount(prefs, newAccount);
            // debugPrint("✅ NEW ACCOUNT CREATED & PERSISTED: $bankName");
          } catch (e) {
            // debugPrint("🔴 Account Persist Failed: $e");
          }
        }
      } else {
        // debugPrint("🟠 PATH: Incomplete data. Skipping specific match.");
      }

      // Step C: Fallback to Primary (ONLY if target is still null)
      if (targetAccountId == null) {
        // debugPrint("⚠️ TARGET ID IS NULL. Resolving fallback (Primary)...");
        try {
          final primary = cachedAccounts.firstWhere(
            (acc) => acc.isPrimary,
            orElse: () => cachedAccounts.isNotEmpty
                ? cachedAccounts.first
                : Account.empty(),
          );

          if (primary.id.isNotEmpty) {
            targetAccountId = primary.id;
            // debugPrint(
            //   "   -> Used Primary/First Account: ${primary.bankName} (${primary.id})",
            // );
          } else {
            // debugPrint("🔴 CRITICAL: No Primary Account found in cache.");
          }
        } catch (e) {
          // debugPrint("🔴 Fallback Error: $e");
        }
      } else {
        // debugPrint("✅ FINAL TARGET ID: $targetAccountId");
      }
      // --- END ACCOUNT LOGIC ---

      // --- MATCHING TAGS ---
      List<Tag> selectedTags = [];
      try {
        final now = DateTime.now();
        final List<String> eventModeTagIds =
            prefs.getStringList('event_mode_tag_ids') ?? [];
        final String? tagsJson = prefs.getString('quick_save_tags_cache');
        if (tagsJson != null) {
          final List<dynamic> decoded = jsonDecode(tagsJson);
          for (var tagMap in decoded) {
            final t = Tag.fromMap(tagMap['id'] ?? '', tagMap);
            if (!eventModeTagIds.contains(t.id)) continue;
            DateTime? start = tagMap['eventStartDate'] != null
                ? DateTime.tryParse(tagMap['eventStartDate'])
                : null;
            DateTime? end = tagMap['eventEndDate'] != null
                ? DateTime.tryParse(tagMap['eventEndDate'])
                : null;
            if (start != null && end != null) {
              if (now.isAfter(start) &&
                  now.isBefore(end.add(const Duration(days: 1)))) {
                selectedTags.add(t);
              }
            }
          }
        }
        // debugPrint("Tags Selected: ${selectedTags.length}");
      } catch (e) {
        // debugPrint("Tag Error: $e");
      }

      // --- CREATE TRANSACTION ---
      final String tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      final newTransaction = TransactionModel(
        transactionId: tempId,
        type: type,
        amount: amount,
        timestamp: DateTime.now(),
        description: payee.isNotEmpty
            ? payee
            : (category.isNotEmpty ? category : 'Quick Save Transaction'),
        paymentMethod: paymentMethod,
        category: category,
        accountId: targetAccountId, // This holds our Created ID or Matched ID
        currency: 'INR',
        tags: selectedTags,
        purchaseType: paymentMethod.toLowerCase().contains('credit')
            ? 'credit'
            : 'debit',
      );

      debugPrint(
        "Finalizing Transaction Model with Account ID: ${newTransaction.accountId}",
      );

      // Save Transaction
      final String? existingPending = prefs.getString(
        'pending_quick_save_transactions',
      );
      List<dynamic> pendingList = [];
      if (existingPending != null) {
        try {
          pendingList = jsonDecode(existingPending);
        } catch (_) {}
      }
      pendingList.add(newTransaction.toMap());
      await prefs.setString(
        'pending_quick_save_transactions',
        jsonEncode(pendingList),
      );

      await _showSuccessNotification(notificationId, amount, type, payee);
    } catch (e) {
      // debugPrint("🔴 CRITICAL FAILURE: $e\n$s");
      await _showFailureNotification(notificationId);
    }
  }

  // --- Helper remains the same ---
  Future<void> _persistNewAccount(
    SharedPreferences prefs,
    Account newAccount,
  ) async {
    // 1. Pending Creation Queue
    final String? pendingAccountsJson = prefs.getString(
      'pending_native_created_accounts',
    );
    List<dynamic> pendingAccountsList = [];
    if (pendingAccountsJson != null) {
      try {
        pendingAccountsList = jsonDecode(pendingAccountsJson);
      } catch (_) {}
    }
    if (!pendingAccountsList.any((a) => a['id'] == newAccount.id)) {
      pendingAccountsList.add(newAccount.toMap());
      await prefs.setString(
        'pending_native_created_accounts',
        jsonEncode(pendingAccountsList),
      );
    }

    // 2. Immediate Cache Update (Crucial for next run)
    await Future.delayed(const Duration(milliseconds: 100));
    final String? currentCacheJson = prefs.getString(
      'quick_save_accounts_cache',
    );
    List<dynamic> currentCacheList = [];
    if (currentCacheJson != null) {
      try {
        currentCacheList = jsonDecode(currentCacheJson);
      } catch (_) {}
    }
    currentCacheList.add(newAccount.toMap());
    await prefs.setString(
      'quick_save_accounts_cache',
      jsonEncode(currentCacheList),
    );
  }

  Future<void> _showSuccessNotification(
    int? notificationId,
    double amount,
    String type,
    String payee,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Updates',
          channelDescription: 'Notifications for transaction updates',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: true,
          icon: 'ic_stat_ledgr',
          timeoutAfter: 5000,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final String action = type.toLowerCase() == 'income' ? 'Received' : 'Sent';
    final String preposition = type.toLowerCase() == 'income' ? 'from' : 'to';
    final String person = payee.isEmpty ? 'Unknown' : payee;

    await _notificationsPlugin.show(
      notificationId ?? 999,
      'Saved ✅ $action ${amount.toStringAsFixed(2)} $preposition $person',
      'Tap to view.',
      platformChannelSpecifics,
    );
  }

  Future<void> _showFailureNotification(int? notificationId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Errors',
          channelDescription: 'Notifications for transaction errors',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: 'ic_stat_ledgr',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      notificationId ?? 999,
      'Failed to save transaction ❌',
      'Please try again.',
      platformChannelSpecifics,
    );
  }
}
