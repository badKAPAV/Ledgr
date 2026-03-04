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
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class CategorySettingsTabScreen extends StatefulWidget {
  const CategorySettingsTabScreen({super.key});

  @override
  State<CategorySettingsTabScreen> createState() =>
      _CategorySettingsTabScreenState();
}

class _CategorySettingsTabScreenState extends State<CategorySettingsTabScreen> {
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

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Maintain transparency for TabBarView
      floatingActionButton: _buildGlassFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Just a nice top padding instead of an AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 0)),

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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
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

            // Bottom padding to clear the FAB
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddEditCategoryModal(context),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Category",
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
