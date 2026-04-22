import 'package:flutter/material.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import '../../auth/provider/auth_provider.dart';

class BudgetProvider with ChangeNotifier {
  AuthProvider authProvider;
  TransactionProvider transactionProvider;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  BudgetProvider({
    required this.authProvider,
    required this.transactionProvider,
  });

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    notifyListeners();
  }

  void updateTransactionProvider(TransactionProvider newTransactionProvider) {
    transactionProvider = newTransactionProvider;
    notifyListeners();
  }

  double calculateAverageExpenses(int months, SettingsProvider settings) {
    if (months <= 0) return 0;
    double total = 0;
    int count = 0;

    final now = DateTime.now();

    for (int i = 1; i <= months; i++) {
      final currentTarget = BudgetCycleHelper.getTargetMonthForDate(now, settings.budgetCycleMode, settings.budgetCycleStartDay);
      var targetMonth = currentTarget.month - i;
      var targetYear = currentTarget.year;
      while (targetMonth <= 0) {
        targetMonth += 12;
        targetYear--;
      }

      final range = BudgetCycleHelper.getCycleRange(
        targetMonth: targetMonth,
        targetYear: targetYear,
        mode: settings.budgetCycleMode,
        startDay: settings.budgetCycleStartDay,
      );

      final monthlyTotal = transactionProvider.getNetTotal(
        start: range.start,
        end: range.end,
        type: 'expense',
      );

      if (monthlyTotal > 0) {
        total += monthlyTotal;
        count++;
      }
    }

    return count > 0 ? total / count : 0;
  }

  double calculateCurrentDailyBudget(SettingsProvider settings) {
    final monthlyBudget = authProvider.user?.monthlyBudget ?? 0.0;
    if (monthlyBudget <= 0) return 0.0;

    final now = DateTime.now();
    final cycle = BudgetCycleHelper.currentCycleRange(
      now,
      settings.budgetCycleMode,
      settings.budgetCycleStartDay
    );

    final todayStart = DateTime(now.year, now.month, now.day);

    final beforeTodayResult = transactionProvider.getFilteredResults(
      TransactionFilter(startDate: cycle.start, endDate: todayStart)
    );
    final spentBeforeToday = beforeTodayResult.totalExpense;

    final remainingMonthBudget = monthlyBudget - spentBeforeToday;
    final daysRemaining = cycle.end.difference(todayStart).inDays + 1;

    if (remainingMonthBudget > 0 && daysRemaining > 0) {
      return remainingMonthBudget / daysRemaining;
    }
    return 0.0;
  }

  Future<void> updateMonthlyBudget(double amount) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Delegate to AuthProvider to ensure local user state is updated immediately
      await authProvider.updateMonthlyBudget(amount);
    } catch (e) {
      debugPrint("Error updating monthly budget: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
