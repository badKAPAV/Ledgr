import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class CategoryMatcher {
  List<CategoryModel> _cachedCategories = [];

  Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final List<String>? categoriesJson = prefs.getStringList(
      'cached_category_map'
    );

    if (categoriesJson != null) {
      _cachedCategories = categoriesJson
          .map((str) => CategoryModel.fromJson(jsonDecode(str)))
          .where((c) => !c.isDeleted)
          .toList();
    }
  }

  String matchCategory(
    String text, {
    TransactionMode mode = TransactionMode.expense,
  }) {
    if (_cachedCategories.isEmpty || text.isEmpty) {
      return _getFallbackCategoryId(mode);
    }

    final lowerText = text.toLowerCase();

    // Filter categories by the requested mode
    final modeCategories = _cachedCategories
        .where((c) => c.mode == mode)
        .toList();

    CategoryModel? bestMatch;
    int bestMatchLength = 0;

    for (var category in modeCategories) {
      for (var keyword in category.keywords) {
        final lowerKeyword = keyword.toLowerCase().trim();
        if (lowerKeyword.isEmpty) continue;

        if (lowerText.contains(lowerKeyword)) {
          if (lowerKeyword.length > bestMatchLength) {
            bestMatchLength = lowerKeyword.length;
            bestMatch = category;
          }
        }
      }
    }

    return bestMatch?.id ?? _getFallbackCategoryId(mode);
  }

  String _getFallbackCategoryId(TransactionMode mode) {
    if (_cachedCategories.isEmpty) {
      return mode == TransactionMode.expense
          ? 'def_others_exp'
          : 'def_others_inc';
    }

    try {
      final defaultCat = _cachedCategories.firstWhere(
        (c) => c.mode == mode && c.isDefault == true,
      );
      return defaultCat.id;
    } catch (_) {
      try {
        final firstAvailable = _cachedCategories.firstWhere(
          (c) => c.mode == mode,
        );
        return firstAvailable.id;
      } catch (_) {
        return mode == TransactionMode.expense
            ? 'def_others_exp'
            : 'def_others_inc';
      }
    }
  }
}
