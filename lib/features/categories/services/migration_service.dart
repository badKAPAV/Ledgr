import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CategoryProvider _categoryProvider;

  MigrationService(this._categoryProvider);

  Future<void> migrateTransactions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      debugPrint('Starting Migration...');
      // 1. Fetch all transactions
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .get();

      final WriteBatch batch = _firestore.batch();
      int updatedCount = 0;

      // Load categories fresh to make sure we have latest data
      await _categoryProvider.fetchCategories();
      final allCategories = _categoryProvider.categories;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? categoryId = data['categoryId'];
        final String legacyCategory = data['category'] ?? '';
        final String type = data['type'] ?? 'expense';
        final mode = type == 'income'
            ? TransactionMode.income
            : TransactionMode.expense;

        // Only migrate if categoryId is missing
        if (categoryId == null) {
          String? newCategoryId;

          // Attempt 1: Direct Name Match (Case Insensitive)
          // e.g. "Food" -> "Food"
          try {
            final directMatch = allCategories.firstWhere(
              (c) =>
                  c.mode == mode &&
                  c.name.toLowerCase() == legacyCategory.toLowerCase(),
            );
            newCategoryId = directMatch.id;
          } catch (e) {
            // No direct match
          }

          // Attempt 2: Fallback to Default 'Others'
          if (newCategoryId == null) {
            try {
              final defaultCat = allCategories.firstWhere(
                (c) => c.mode == mode && c.isDefault == true,
              );
              newCategoryId = defaultCat.id;
            } catch (e) {
              // Should definitely not happen if init was correct
              debugPrint('Error finding default category for fallback: $e');
            }
          }

          if (newCategoryId != null) {
            batch.update(doc.reference, {'categoryId': newCategoryId});
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('Migration Completed: Updated $updatedCount transactions.');
      } else {
        debugPrint('Migration: No transactions needed update.');
      }
    } catch (e) {
      debugPrint('Error migrating transactions: $e');
    }
  }
}
