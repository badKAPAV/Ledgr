// lib/features/revenuecat/utils/premium_guard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/utils/ledgr_max/paywall/paywall_features.dart';
import 'package:wallzy/core/utils/ledgr_max/paywall/paywall_sheet.dart';
// Adjust imports to your path
import '../entitlements/entitlements_provider.dart';

class PaywallInterceptor {
  /// Evaluates if the user can perform an action, and intercepts with a
  /// paywall if they have hit their limit.
  static void execute({
    required BuildContext context,
    required PaywallFeature feature,
    required VoidCallback onAllowed,
    int? currentCount, // Only required for quantity-based features
  }) {
    // 1. Read the current rulebook (use read(), not watch() in functions)
    final entitlements = context.read<EntitlementsProvider>();
    bool isAllowed = false;

    // 2. Evaluate based on the specific feature
    switch (feature) {
      // --- QUANTITY GATES ---
      case PaywallFeature.folders:
        assert(currentCount != null, "currentCount is required for folders");
        isAllowed = currentCount! < entitlements.maxFolders;
        break;

      case PaywallFeature.recurringPayments:
        assert(
          currentCount != null,
          "currentCount is required for recurringPayments",
        );
        isAllowed = currentCount! < entitlements.maxRecurringPayments;
        break;

      case PaywallFeature.userAccounts:
        assert(
          currentCount != null,
          "currentCount is required for userAccounts",
        );
        isAllowed = currentCount! < entitlements.maxUserAccounts;
        break;

      case PaywallFeature.goals:
        assert(currentCount != null, "currentCount is required for goals");
        isAllowed = currentCount! < entitlements.maxGoals;
        break;

      case PaywallFeature.transactionLimitMonths:
        assert(
          currentCount != null,
          "currentCount is required for transactionLimitMonths",
        );
        isAllowed = currentCount! < entitlements.maxMonthsHistory;
        break;

      // --- BOOLEAN GATES ---
      case PaywallFeature.customCategories:
        isAllowed = entitlements.canUseCustomCategories;
        break;

      case PaywallFeature.budgetCycle:
        isAllowed = entitlements.canUseBudgetCycle;
        break;

      case PaywallFeature.convertInTransaction:
        isAllowed = entitlements.canUseConvertInTransaction;
        break;

      case PaywallFeature.categoryBudgets:
        isAllowed = entitlements.canUseCategoryBudgets;
        break;

      case PaywallFeature.quickSave:
        isAllowed = entitlements.canUseQuickSave;
        break;

      case PaywallFeature.cloudSync:
        isAllowed = entitlements.canUseCloudSync;
        break;

      case PaywallFeature.autosave:
        isAllowed = entitlements.canUseAutosave;
        break;

      case PaywallFeature.transactionReceipt:
        isAllowed = entitlements.canUseTransactionReceipt;
        break;

      case PaywallFeature.dataExport:
        isAllowed = entitlements.canUseDataExport;
        break;

      case PaywallFeature.biometric:
        isAllowed = entitlements.canUseBiometric;
        break;

      case PaywallFeature.folderBudgets:
        isAllowed = entitlements.canUseFolderBudgets;
        break;
    }

    // 3. The Intercept
    if (isAllowed) {
      onAllowed(); // Execute the actual function!
    } else {
      _showPaywall(context, feature.upsellMessage);
    }
  }

  static void _showPaywall(BuildContext context, String message) {
    PremiumUpsellSheet.show(context, message);
  }
}
