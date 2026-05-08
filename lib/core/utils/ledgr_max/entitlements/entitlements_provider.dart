import 'package:flutter/foundation.dart';
import 'package:wallzy/core/utils/ledgr_max/entitlements/entitlements_service.dart';
import 'package:wallzy/core/utils/ledgr_max/entitlements/feature_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntitlementsProvider extends ChangeNotifier {
  final EntitlementsService _service = EntitlementsService();

  bool _isPro = false;
  bool _isLoading = true;

  // Store the fetched blueprints
  FeatureLimits _freeLimits = FeatureLimits.fallbackFree();
  FeatureLimits _proLimits = FeatureLimits.fallbackPro();

  // The active limits for the current user
  FeatureLimits get currentLimits => _isPro ? _proLimits : _freeLimits;

  // Expose blueprints for the Paywall UI
  FeatureLimits get freeLimits => _freeLimits;
  FeatureLimits get proLimits => _proLimits;
  bool get isLoading => _isLoading;

  EntitlementsProvider() {
    _init();
  }

  Future<void> _init() async {
    final tiers = await _service.fetchAllTiers();
    _freeLimits = tiers['free']!;
    _proLimits = tiers['pro']!;
    _isLoading = false;

    // Save for native Android access
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isProUser', _isPro);
      prefs.setBool('canUseQuickSave', currentLimits.quickSave);
    });

    notifyListeners();
  }

  /// Hook this to RevenueCatProvider via ProxyProvider
  void updateProStatus(bool isCurrentlyPro) {
    if (_isPro != isCurrentlyPro) {
      _isPro = isCurrentlyPro;
      
      // Save for native Android access
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('isProUser', isCurrentlyPro);
        prefs.setBool('canUseQuickSave', currentLimits.quickSave);
      });
      
      notifyListeners();
    }
  }

  // --- Clean Getters for Global UI Usage ---
  bool get canUseQuickSave => currentLimits.quickSave;
  bool get canUseAutosave => currentLimits.autosave;
  int get maxMonthsHistory => currentLimits.transactionHistoryLimitMonths;
  int get maxUserAccounts => currentLimits.userAccountsQuantity;
  bool get canUseCustomCategories => currentLimits.customCategories;
  bool get canUseCategoryBudgets => currentLimits.categoryBudgets;
  int get maxFolders => currentLimits.folderQuantity;
  bool get canUseFolderBudgets => currentLimits.folderBudgets;
  int get maxRecurringPayments => currentLimits.recurringPaymentsQuantity;
  int get maxGoals => currentLimits.goalsQuantity;
  bool get canUseCloudSync => currentLimits.dataSyncToCloud;
  bool get canUseTransactionReceipt => currentLimits.imageReceiptInTransactions;
  bool get canUseDataExport => currentLimits.dataExport;
  bool get canUseBiometric => currentLimits.canUseBiometric;
  bool get canUseConvertInTransaction => currentLimits.convertInTransaction;
  bool get canUseBudgetCycle => currentLimits.canUseBudgetCycle;
}
