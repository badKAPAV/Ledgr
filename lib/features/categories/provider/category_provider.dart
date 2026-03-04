import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class CategoryProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  CategoryProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    notifyListeners();

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _fetchCategories(user.uid);
      } else {
        _categories = [];
        notifyListeners();
      }
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? cachedList = prefs.getStringList(
        'cached_category_map',
      );
      if (cachedList != null) {
        _categories = cachedList
            .map((item) => CategoryModel.fromJson(jsonDecode(item)))
            .toList();
      }
      // Don't notify here, let init do it or the caller.
    } catch (e) {
      debugPrint("Error loading categories from cache: $e");
    }
  }

  Future<void> fetchCategories() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _fetchCategories(user.uid);
  }

  Future<void> _fetchCategories(String uid) async {
    // If we have categories from cache, we don't need to show loading
    if (_categories.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .get();

      if (snapshot.docs.isEmpty) {
        // Only create default if we really have nothing (even in cache)
        if (_categories.isEmpty) {
          await _createDefaultCategories(uid);
        }
      } else {
        final serverCategories = snapshot.docs
            .map((doc) => CategoryModel.fromJson(doc.data()))
            .toList();

        _categories = serverCategories;
        await _syncCategoriesToSharedPrefs();
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createDefaultCategories(String uid) async {
    final batch = _firestore.batch();
    final defaultCategories = _getDefaultCategories();

    List<CategoryModel> createdCategories = [];

    for (var cat in defaultCategories) {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(cat.id);
      batch.set(docRef, cat.toJson());
      createdCategories.add(cat);
    }

    await batch.commit();

    _categories = createdCategories;
    await _syncCategoriesToSharedPrefs();
  }

  Future<void> _ensureUniqueDefault(
    String newDefaultId,
    TransactionMode mode,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    bool batchHasUpdates = false;

    for (int i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      if (cat.mode == mode) {
        if (cat.id == newDefaultId) {
          if (!cat.isDefault) {
            _categories[i] = cat.copyWith(isDefault: true);
            batch.update(
              _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('categories')
                  .doc(cat.id),
              {'isDefault': true},
            );
            batchHasUpdates = true;
          }
        } else {
          if (cat.isDefault) {
            _categories[i] = cat.copyWith(isDefault: false);
            batch.update(
              _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('categories')
                  .doc(cat.id),
              {'isDefault': false},
            );
            batchHasUpdates = true;
          }
        }
      }
    }

    if (batchHasUpdates) {
      notifyListeners();
      await _syncCategoriesToSharedPrefs();
      try {
        await batch.commit();
      } catch (e) {
        debugPrint("Error updating default categories: \$e");
      }
    }
  }

  List<CategoryModel> _getDefaultCategories() {
    CategoryModel create(
      String key,
      String name,
      CategoryType type,
      TransactionMode mode,
      String iconKey,
      List<String> keywords, {
      required bool isDefault,
    }) {
      return CategoryModel(
        id: 'def_$key',
        name: name,
        type: type,
        mode: mode,
        iconKey: iconKey,
        keywords: keywords,
        budget: null,
        isDeleted: false,
        isDefault: isDefault,
      );
    }

    final expense = CategoryType.defaultType;
    final income = CategoryType.defaultType;
    final modeExp = TransactionMode.expense;
    final modeInc = TransactionMode.income;

    return [
      // EXPENSES (15)
      create('grocery', 'Grocery', expense, modeExp, 'grocery', [
        "bigbasket",
        "blinkit",
        "zepto",
        "instamart",
        "grofers",
        "dmart",
        "reliance fresh",
        "nature's basket",
        "kirana",
        "supermarket",
        "vegetable",
        "fruit",
        "grocery",
      ], isDefault: false),

      create('food', 'Food', expense, modeExp, 'food', [
        "zomato",
        "swiggy",
        "ubereats",
        "domino",
        "pizza",
        "burger",
        "kfc",
        "mcdonald",
        "cafe",
        "coffee",
        "starbucks",
        "tea",
        "dining",
        "kitchen",
        "restaurant",
        "baking",
        "bakery",
        "cake",
        "eats",
        "bar",
        "pub",
        "brew",
        "brewery",
        "brewpub",
      ], isDefault: false),

      create('transport', 'Transport', expense, modeExp, 'car', [
        "uber",
        "ola",
        "rapido",
        "indrive",
        "metro",
        "rail",
        "irctc",
        "fastag",
        "toll",
        "ticket",
        "cab",
        "auto",
        "transport",
      ], isDefault: false),

      create('fuel', 'Fuel', expense, modeExp, 'fuel', [
        "petrol",
        "diesel",
        "shell",
        "hpcl",
        "bpcl",
        "ioc",
        "pump",
        "fuel",
        "gas station",
      ], isDefault: false),

      create('shopping', 'Shopping', expense, modeExp, 'shopping', [
        "amazon",
        "flipkart",
        "myntra",
        "ajio",
        "meesho",
        "nykaa",
        "tata",
        "reliance trends",
        "zudio",
        "pantaloons",
        "mall",
        "retail",
        "store",
        "mart",
        "cloth",
        "fashion",
        "decathlon",
        "nike",
        "adidas",
        "shopping",
      ], isDefault: false),

      create('entertainment', 'Entertainment', expense, modeExp, 'film', [
        "bookmyshow",
        "pvr",
        "inox",
        "netflix",
        "prime",
        "hotstar",
        "spotify",
        "youtube",
        "game",
        "steam",
        "playstation",
        "movie",
        "cinema",
        "subscription",
        "entertainment",
      ], isDefault: false),

      create('health', 'Health', expense, modeExp, 'health', [
        "pharmacy",
        "medplus",
        "apollo",
        "1mg",
        "practo",
        "hospital",
        "doctor",
        "clinic",
        "lab",
        "meds",
        "health",
        "dr.",
      ], isDefault: false),

      create('utilities', 'Utilities', expense, modeExp, 'bulb', [
        "electricity",
        "bescom",
        "tneb",
        "discom",
        "gas",
        "water",
        "broadband",
        "internet",
        "wifi",
        "fiber",
        "dth",
        "cable",
        "utilities",
      ], isDefault: false),

      create('investment', 'Investment', expense, modeExp, 'invest', [
        "zerodha",
        "groww",
        "kite",
        "sip",
        "mutual fund",
        "stock",
        "angel one",
        "upstox",
        "coin",
        "nps",
        "ppf",
        "smallcase",
        "investment",
      ], isDefault: false),

      create('education', 'Education', expense, modeExp, 'education', [
        "school",
        "college",
        "fee",
        "university",
        "udemy",
        "coursera",
        "learning",
        "class",
        "education",
        "book",
        "tuition",
      ], isDefault: false),

      create('bills', 'Bills', expense, modeExp, 'bill', [
        "bill",
        "recharge",
        "invoice",
        "premium",
      ], isDefault: false),

      create('rent', 'Rent', expense, modeExp, 'house', [
        "rent",
        "nobroker",
        "nestaway",
        "house",
        "apartment",
        "mortgage",
      ], isDefault: false),

      create('tax', 'Tax', expense, modeExp, 'tax', [
        "tax",
        "income tax",
        "property tax",
      ], isDefault: false),

      create('people_exp', 'People', expense, modeExp, 'user', [
        "people",
        "friend",
        "family",
        "gift",
      ], isDefault: false),

      create('others_exp', 'Others', expense, modeExp, 'menu', [
        "other",
        "miscellaneous",
        "misc",
      ], isDefault: true), // ONLY OTHERS IS DEFAULT
      // INCOME (5)
      create('salary', 'Salary', income, modeInc, 'money_bag', [
        "salary",
        "payroll",
        "credit towards salary",
        "-salary",
        "salary-",
        "wages",
        "income",
        "bonus",
        "paycheck",
      ], isDefault: false),

      create('loan', 'Loan', income, modeInc, 'bank', [
        "loan",
        "emi",
        "finance",
        "bajaj",
        "borrow",
        "lend",
      ], isDefault: false),

      create('refund', 'Refund', income, modeInc, 'refund', [
        "refund",
        "reversal",
        "reversed",
        "return",
        "reimbursement",
      ], isDefault: false),

      create('people_inc', 'People', income, modeInc, 'user', [
        "people",
        "friend",
        "family",
      ], isDefault: false),

      create('others_inc', 'Others', income, modeInc, 'menu', [
        "other",
        "miscellaneous",
        "misc",
      ], isDefault: true),
    ];
  }

  Future<void> _syncCategoriesToSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> categoriesJson = _categories
        .map((c) => jsonEncode(c.toJson()))
        .toList();

    await prefs.setStringList('cached_category_map', categoriesJson);
  }

  // --- CRUD OPERATIONS ---

  Future<void> addCategory({
    required String name,
    required String iconKey,
    required TransactionMode mode,
    required List<String> keywords,
    double? budget,
    bool? isDefault,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .doc();

    final newCategory = CategoryModel(
      id: newRef.id,
      name: name,
      type: CategoryType.customType,
      mode: mode,
      iconKey: iconKey,
      keywords: keywords,
      budget: budget,
      isDeleted: false,
      isDefault: isDefault ?? false,
    );

    // Optimistic Update
    _categories.add(newCategory);

    // If new category is default, handle uniqueness
    if (newCategory.isDefault) {
      // This will also persist the new default state for others
      await _ensureUniqueDefault(newCategory.id, newCategory.mode);
    } else {
      // Just persist the new category
      notifyListeners();
      _syncCategoriesToSharedPrefs();
    }

    try {
      if (!newCategory.isDefault) {}
      await newRef.set(newCategory.toJson());
    } catch (e) {
      debugPrint("Error adding category to Firestore: $e");
      // Revert if failed (optional, but good practice)
      _categories.removeWhere((c) => c.id == newCategory.id);
      notifyListeners();
      _syncCategoriesToSharedPrefs();
      // Rethrow or handle error UI
    }
  }

  Future<void> editCategory(CategoryModel updatedCategory) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final index = _categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index == -1) return;

    // Optimistic Update
    final oldCategory = _categories[index];

    if (updatedCategory.isDefault && !oldCategory.isDefault) {
      // Setting as default
      // Note: We don't update _categories[index] here yet because _ensureUniqueDefault
      // relies on existing state to determine what needs to be updated in batch.
      await _ensureUniqueDefault(updatedCategory.id, updatedCategory.mode);

      // After unique default is ensured (and other defaults unset),
      // update this category with new values (name, icon, etc.) AND isDefault=true
      _categories[index] = updatedCategory;
      notifyListeners();
      await _syncCategoriesToSharedPrefs();
      // _ensureUniqueDefault handles persistence for all modified docs including this one's isDefault field
      // BUT we still need to update other fields like name/icon if they changed.
      // So we should let ensureUniqueDefault handle the 'isDefault' switching,
      // and then we update the document with ALL fields.
    } else if (!updatedCategory.isDefault && oldCategory.isDefault) {
      // Unsetting default - NOT ALLOWED typically unless another is set.
      // But if user explicitly unchecks, we might allow no default?
      // Plan says override fallback to 'Others'.
      // For now, let's allow it.
      _categories[index] = updatedCategory;
      notifyListeners();
      _syncCategoriesToSharedPrefs();
    } else {
      // No change in default status
      _categories[index] = updatedCategory;
      notifyListeners();
      _syncCategoriesToSharedPrefs();
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(updatedCategory.id)
          .update(updatedCategory.toJson());
    } catch (e) {
      debugPrint("Error updating category in Firestore: $e");
      // Revert
      _categories[index] = oldCategory;
      notifyListeners();
      _syncCategoriesToSharedPrefs();
    }
  }

  Future<void> setAsDefault(String categoryId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Find the target category
    final targetIndex = _categories.indexWhere((c) => c.id == categoryId);
    if (targetIndex == -1) return;

    final targetCategory = _categories[targetIndex];
    if (targetCategory.isDefault) return; // Already default, do nothing

    final mode = targetCategory.mode;

    // 2. Optimistic UI Update (Memory)
    // Find the old default for this mode and turn it off
    final oldDefaultIndex = _categories.indexWhere(
      (c) => c.mode == mode && c.isDefault,
    );
    if (oldDefaultIndex != -1) {
      _categories[oldDefaultIndex] = _categories[oldDefaultIndex].copyWith(
        isDefault: false,
      );
    }

    // Turn the new one on
    _categories[targetIndex] = targetCategory.copyWith(isDefault: true);

    // 3. Notify and save locally IMMEDIATELY (Offline-first)
    notifyListeners();
    await _syncCategoriesToSharedPrefs();

    // 4. Batch Write to Firestore
    final batch = _firestore.batch();

    // Update old default in Firestore
    if (oldDefaultIndex != -1) {
      final oldRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(_categories[oldDefaultIndex].id);
      batch.update(oldRef, {'isDefault': false});
    }

    // Update new default in Firestore
    final newRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .doc(targetCategory.id);
    batch.update(newRef, {'isDefault': true});

    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error updating default categories in Firestore: $e");
      // Optional: If you want extreme robustness, you'd revert the memory state here on failure.
      // But for offline-first, we usually trust the local state and let Firestore sync when online.
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return;

    final category = _categories[index];
    if (category.isDefault) {
      debugPrint("Cannot delete default category");
      return;
    }

    // Soft delete
    final deletedCategory = category.copyWith(isDeleted: true);

    // Optimistic Update
    _categories[index] = deletedCategory;
    notifyListeners();
    _syncCategoriesToSharedPrefs();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .update({'isDeleted': true});
    } catch (e) {
      debugPrint("Error deleting category in Firestore: $e");
      // Revert
      _categories[index] = category;
      notifyListeners();
      _syncCategoriesToSharedPrefs();
    }
  }
}
