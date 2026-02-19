import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/features/categories/screens/add_edit_category_modal_sheet.dart';
import 'package:wallzy/features/categories/services/migration_service.dart'; // Ensure this import is present
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class CategorySettingsTabScreen extends StatefulWidget {
  const CategorySettingsTabScreen({super.key});

  @override
  State<CategorySettingsTabScreen> createState() =>
      _CategorySettingsTabScreenState();
}

class _CategorySettingsTabScreenState extends State<CategorySettingsTabScreen> {
  bool _isMigrateLoading = false;

  Future<void> _runMigration(
    BuildContext context,
    CategoryProvider provider,
  ) async {
    HapticFeedback.mediumImpact();
    setState(() => _isMigrateLoading = true);
    try {
      final migrationService = MigrationService(provider);
      await migrationService.migrateTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Migration completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMigrateLoading = false);
    }
  }

  void _showAddEditCategoryModal(
    BuildContext context, {
    CategoryModel? category,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditCategoryModalSheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final activeCategories = categoryProvider.categories
        .where((c) => !c.isDeleted)
        .toList();
    final theme = Theme.of(context);

    // Separate and sort lists
    final expenseCategories =
        activeCategories
            .where((c) => c.mode == TransactionMode.expense)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final incomeCategories =
        activeCategories.where((c) => c.mode == TransactionMode.income).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Stack(
      children: [
        // --- MAIN SCROLL CONTENT ---
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Just a nice top padding instead of an AppBar
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            if (activeCategories.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    "No categories found",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              // --- EXPENSES SECTION ---
              if (expenseCategories.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Text(
                      "EXPENSE",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.outline,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _CategoryCard(
                      category: expenseCategories[index],
                      provider: categoryProvider,
                      onTap: () => _showAddEditCategoryModal(
                        context,
                        category: expenseCategories[index],
                      ),
                    );
                  }, childCount: expenseCategories.length),
                ),
              ],

              // --- INCOME SECTION ---
              if (incomeCategories.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                    child: Text(
                      "INCOME",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.outline,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _CategoryCard(
                      category: incomeCategories[index],
                      provider: categoryProvider,
                      onTap: () => _showAddEditCategoryModal(
                        context,
                        category: incomeCategories[index],
                      ),
                    );
                  }, childCount: incomeCategories.length),
                ),
              ],

              // Bottom padding to clear the floating toolkit
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),

        // --- FLOATING TOOLKIT (Bottom Center) ---
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Migrate Button
                    _ToolkitButton(
                      icon: HugeIcons.strokeRoundedDatabaseSync,
                      label: "Migrate",
                      isLoading: _isMigrateLoading,
                      onTap: () => _runMigration(context, categoryProvider),
                      theme: theme,
                    ),

                    // Add Button
                    _ToolkitButton(
                      icon: Icons.add_rounded,
                      label: "New Category",
                      isPrimary: true,
                      onTap: () => _showAddEditCategoryModal(context),
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- MODERN CATEGORY CARD ---
class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final CategoryProvider provider;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = category.mode == TransactionMode.expense;
    final isSystemDefault = category.type == CategoryType.defaultType;
    final appColors = theme.extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isExpense ? appColors.expense : appColors.income)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: HugeIcon(
                  icon: GoalIconRegistry.getIcon(category.iconKey),
                  color: isExpense ? appColors.expense : appColors.income,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isSystemDefault) ...[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "SYSTEM",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ] else
                          Text(
                            "CUSTOM",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Trailing Actions (Default Badge / Set Default Button)
              if (category.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    provider.setAsDefault(category.id);
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    "Set Default",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TOOLKIT BUTTON WIDGET ---
class _ToolkitButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isPrimary;
  final bool isLoading;

  const _ToolkitButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.isPrimary = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              )
            else if (icon is List<List<dynamic>>) // Checking for HugeIcon
              HugeIcon(
                icon: icon,
                size: 20,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              )
            else
              Icon(
                icon,
                size: 20,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
