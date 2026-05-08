enum PaywallFeature {
  // Quantity-based
  folders,
  recurringPayments,
  userAccounts,
  goals,
  transactionLimitMonths,
  convertInTransaction,

  // Boolean-based
  customCategories,
  categoryBudgets,
  quickSave,
  cloudSync,
  autosave,
  transactionReceipt,
  dataExport,
  biometric,
  budgetCycle,
  folderBudgets;

  String get upsellMessage {
    switch (this) {
      case PaywallFeature.folders:
        return "Unlock unlimited custom folders with Ledgr Max";
      case PaywallFeature.recurringPayments:
        return "Track unlimited recurring payments with Ledgr Max";
      case PaywallFeature.customCategories:
        return "Create custom categories to match your lifestyle with Ledgr Max";
      case PaywallFeature.quickSave:
        return "One-tap save transactions hassle-free with Ledgr Max";
      case PaywallFeature.cloudSync:
        return "Securely backup your data across devices with Ledgr Max";
      case PaywallFeature.userAccounts:
        return "Manage multiple financial profiles with Ledgr Max";
      case PaywallFeature.categoryBudgets:
        return "Create budgets for each category with Ledgr Max";
      case PaywallFeature.folderBudgets:
        return "Create budgets for each folder with Ledgr Max";
      case PaywallFeature.transactionLimitMonths:
        return "Track unlimited transactions with Ledgr Max";
      case PaywallFeature.goals:
        return "Set and track unlimited goals with Ledgr Max";
      case PaywallFeature.transactionReceipt:
        return "Add image receipts to transactions with Ledgr Max";
      case PaywallFeature.dataExport:
        return "Export your data with Ledgr Max";
      case PaywallFeature.biometric:
        return "Secure your app with biometrics with Ledgr Max";
      case PaywallFeature.autosave:
        return "Auto-save your transactions with Ledgr Max";
      case PaywallFeature.convertInTransaction:
        return "Convert transactions to other currencies with Ledgr Max";
      case PaywallFeature.budgetCycle:
        return "Set custom budget cycles with Ledgr Max";
    }
  }
}
