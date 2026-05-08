class FeatureLimits {
  final bool quickSave;
  final bool autosave;
  final int transactionHistoryLimitMonths;
  final int userAccountsQuantity;
  final bool customCategories;
  final bool categoryBudgets;
  final int folderQuantity;
  final bool folderBudgets;
  final int recurringPaymentsQuantity;
  final int goalsQuantity;
  final bool dataSyncToCloud;
  final bool imageReceiptInTransactions;
  final bool dataExport;
  final bool canUseBiometric;
  final bool convertInTransaction;
  final bool canUseBudgetCycle;

  const FeatureLimits({
    required this.quickSave,
    required this.autosave,
    required this.transactionHistoryLimitMonths,
    required this.userAccountsQuantity,
    required this.customCategories,
    required this.categoryBudgets,
    required this.folderQuantity,
    required this.folderBudgets,
    required this.recurringPaymentsQuantity,
    required this.goalsQuantity,
    required this.dataSyncToCloud,
    required this.imageReceiptInTransactions,
    required this.dataExport,
    required this.canUseBiometric,
    required this.convertInTransaction,
    required this.canUseBudgetCycle,
  });

  factory FeatureLimits.fromJson(Map<String, dynamic> json) {
    return FeatureLimits(
      quickSave: json['quick_save'] ?? false,
      autosave: json['autosave'] ?? false,
      transactionHistoryLimitMonths:
          json['transaction_history_limit_months'] ?? 3,
      userAccountsQuantity: json['user_accounts_quantity'] ?? 1,
      customCategories: json['custom_categories'] ?? false,
      categoryBudgets: json['category_budgets'] ?? false,
      folderQuantity: json['folder_quantity'] ?? 2,
      folderBudgets: json['folder_budgets'] ?? false,
      recurringPaymentsQuantity: json['recurring_payments_quantity'] ?? 0,
      goalsQuantity: json['goals_quantity'] ?? 0,
      dataSyncToCloud: json['data_sync_to_cloud'] ?? false,
      imageReceiptInTransactions:
          json['image_receipt_in_transactions'] ?? false,
      dataExport: json['data_export'] ?? false,
      canUseBiometric: json['biometric'] ?? false,
      convertInTransaction: json['convert_in_transaction'] ?? false,
      canUseBudgetCycle: json['set_budget_cycle'] ?? false,
    );
  }

  // CRITICAL: Safe defaults if the user is completely offline on first launch
  factory FeatureLimits.fallbackFree() => const FeatureLimits(
    quickSave: false,
    autosave: false,
    transactionHistoryLimitMonths: 3,
    userAccountsQuantity: 2,
    customCategories: false,
    categoryBudgets: false,
    folderQuantity: 2,
    folderBudgets: false,
    recurringPaymentsQuantity: 2,
    goalsQuantity: 1,
    dataSyncToCloud: false,
    imageReceiptInTransactions: false,
    dataExport: false,
    canUseBiometric: false,
    convertInTransaction: false,
    canUseBudgetCycle: false,
  );

  factory FeatureLimits.fallbackPro() => const FeatureLimits(
    quickSave: true,
    autosave: true,
    transactionHistoryLimitMonths: 999, // Infinite
    userAccountsQuantity: 99,
    customCategories: true,
    categoryBudgets: true,
    folderQuantity: 999,
    folderBudgets: true,
    recurringPaymentsQuantity: 999,
    goalsQuantity: 999,
    dataSyncToCloud: true,
    imageReceiptInTransactions: true,
    dataExport: true,
    canUseBiometric: true,
    convertInTransaction: true,
    canUseBudgetCycle: true,
  );
}
