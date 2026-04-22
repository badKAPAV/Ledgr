import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/helpers/fading_divider.dart';
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
                  child: Row(
                    children: [
                      Text(
                        "EXPENSE CATEGORIES",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FadingDivider(
                          thickness: 2,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
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
              ),
            ],

            // --- INCOME SECTION ---
            if (incomeCategories.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        "INCOME CATEGORIES",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FadingDivider(
                          thickness: 2,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
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
    final isDefault = category.isDefault;

    return Material(
      color: isDefault
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDefault
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isDefault ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Forces extreme compactness
            children: [
              // --- ROW 1: Icon & Type Badge ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Compact Icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (isExpense ? appColors.expense : appColors.income)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: GoalIconRegistry.getIcon(category.iconKey),
                        color: isExpense ? appColors.expense : appColors.income,
                        size: 20,
                      ),
                    ),
                  ),

                  // Tiny SYS/CUST Badge
                  isSystemDefault
                      ? Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),

              const SizedBox(height: 10),

              // --- ROW 2: Category Title ---
              Text(
                category.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isSystemDefault
                      ? FontWeight.w400
                      : FontWeight.bold,
                  letterSpacing: -0.2,
                  fontSize: 13,
                  color: isSystemDefault
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 1, // Kept to 1 line for maximum vertical savings
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // --- ROW 3: Compact Action Area ---
              if (isDefault)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DEFAULT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setAsDefault(category.id);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    // Padding makes the tap target larger without increasing visual size
                    padding: const EdgeInsets.only(
                      top: 2,
                      bottom: 2,
                      right: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Set default",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
