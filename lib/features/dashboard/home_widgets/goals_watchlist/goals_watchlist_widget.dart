import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/dashboard/models/home_widget_model.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/dashboard/home_widgets/goals_watchlist/goals_selection_sheet.dart';
import 'package:wallzy/common/helpers/dashed_border.dart';
import 'package:wallzy/features/goals/provider/goals_provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

class GoalsWatchlistWidget extends StatelessWidget {
  final HomeWidgetModel model;
  const GoalsWatchlistWidget({super.key, required this.model});

  void _showGoalsSelectionSheet(BuildContext context, HomeWidgetModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalsSelectionSheet(
        widgetId: model.id,
        initialSelection: model.configIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Real Data
    final goalsProvider = Provider.of<GoalsProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final allGoals = goalsProvider.goals;
    final selectedGoals = allGoals
        .where((g) => model.configIds.contains(g.id))
        .toList();

    final goals = selectedGoals.map((goal) {
      // Calculate spent (current amount) by summing up balances of accounts in goal.accountsList
      double currentAmount = 0.0;
      for (final accountId in goal.accountsList) {
        try {
          final account = accountProvider.accounts.firstWhere(
            (a) => a.id == accountId,
          );
          currentAmount += accountProvider.getBalanceForAccount(
            account,
            transactionProvider.transactions,
          );
        } catch (_) {}
      }

      return _GoalData(
        id: goal.id,
        name: goal.title,
        color: Colors
            .indigo, // Default goal color as goals might not have color property yet, or use custom icon color?
        // Wait, Goal model doesn't have Color. Tag did.
        // We can use a default or maybe generate from ID.
        // But we have iconKey.
        spent: currentAmount,
        target: goal.targetAmount,
        iconKey: goal.iconKey,
      );
    }).toList();

    final textTheme = Theme.of(context).textTheme;
    final currencySymbol = settingsProvider.currencySymbol;

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            physics: const NeverScrollableScrollPhysics(),
            // Show up to 3 items + potential Add button
            itemCount: goals.length < 3 ? goals.length + 1 : goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == goals.length) {
                return InkWell(
                  onTap: () => _showGoalsSelectionSheet(context, model),
                  borderRadius: BorderRadius.circular(12),
                  child: DashedBorder(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    strokeWidth: 1.5,
                    gap: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 30,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Add target",
                            style: textTheme.labelMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final goal = goals[index];
              // Avoid division by zero
              final percent = goal.target > 0
                  ? (goal.spent / goal.target).clamp(0.0, 1.0)
                  : 0.0;

              final spentStr = goal.spent.toStringAsFixed(0);
              final targetStr = goal.target.toStringAsFixed(0);

              return SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Icon Circle (Target Icon)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14), // Rounded
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: HugeIcon(
                              icon: GoalIconRegistry.getIcon(
                                goal.iconKey,
                              ), // Use dynamic icon
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Row: Name and Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      goal.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '$currencySymbol$spentStr',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'momo',
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        " / $targetStr",
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).hintColor,
                                          fontFamily: 'momo',
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Bottom Row: Custom Progress Bar for Goals
                              Row(
                                children: [
                                  Expanded(
                                    child: SegmentedProgressBar(
                                      height: 6,
                                      borderRadius: BorderRadius.circular(3),
                                      segments: [
                                        Segment(
                                          value: goal.spent,
                                          color: colorScheme.primary,
                                        ),
                                        Segment(
                                          value: (goal.target - goal.spent)
                                              .clamp(0, double.infinity),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(percent * 100).toInt()}%",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GoalData {
  final String id;
  final String name;
  final Color color;
  final double spent;
  final double target;
  final String? iconKey;

  _GoalData({
    required this.id,
    required this.name,
    required this.color,
    required this.spent,
    required this.target,
    this.iconKey,
  });
}
