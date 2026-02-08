import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/dashboard/provider/home_widgets_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/features/goals/provider/goals_provider.dart';
import 'package:wallzy/features/goals/screens/goals_screen.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class GoalsSelectionSheet extends StatefulWidget {
  final String widgetId;
  final List<String> initialSelection;

  const GoalsSelectionSheet({
    super.key,
    required this.widgetId,
    this.initialSelection = const [],
  });

  @override
  State<GoalsSelectionSheet> createState() => _GoalsSelectionSheetState();
}

class _GoalsSelectionSheetState extends State<GoalsSelectionSheet> {
  late List<String> _selectedIds;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
      final validGoalIds = goalsProvider.goals.map((g) => g.id).toSet();

      _selectedIds = widget.initialSelection
          .where((id) => validGoalIds.contains(id))
          .toList();
      _isInitialized = true;
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < 3) {
          _selectedIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You can only choose up to 3 goals"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Select Goals",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Choose up to 3 goals to monitor",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 16),

          // List of Goals
          Expanded(
            child: Consumer<GoalsProvider>(
              builder: (context, goalsProvider, _) {
                final accountProvider = Provider.of<AccountProvider>(
                  context,
                  listen: false,
                ); // Use listen: false if mostly static or rebuilds triggered elsewhere? Actually inside Consumer we might not want to rebuild whole list on account change? But we do need live balance.
                // However, optimization: if we use Provider.of inside builder it might be better?
                // Actually, let's just grab them.
                final transactionProvider = Provider.of<TransactionProvider>(
                  context,
                  listen: false,
                );

                final goals = goalsProvider.goals;

                if (goals.isEmpty) {
                  return Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GoalsScreen(),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAdd01,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No goals found.\nCreate a goal first",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final id = goal.id;
                    final isSelected = _selectedIds.contains(id);

                    // Calculate progress
                    double currentAmount = 0.0;
                    for (final accountId in goal.accountsList) {
                      try {
                        // optimize: direct access? accounts list is likely small.
                        final account = accountProvider.accounts.firstWhere(
                          (a) => a.id == accountId,
                        );
                        currentAmount += accountProvider.getBalanceForAccount(
                          account,
                          transactionProvider.transactions,
                        );
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _toggleSelection(id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer
                                      .withOpacity(0.4)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: GoalIconRegistry.getIcon(goal.iconKey),
                                color: (isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SegmentedProgressBar(
                                      height: 4,
                                      borderRadius: BorderRadius.circular(2),
                                      segments: [
                                        Segment(
                                          value: currentAmount,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        Segment(
                                          value:
                                              (goal.targetAmount -
                                                      currentAmount)
                                                  .clamp(0, double.infinity),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      Provider.of<HomeWidgetsProvider>(
                        context,
                        listen: false,
                      ).updateWidgetConfig(widget.widgetId, _selectedIds);
                      Navigator.pop(context);
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("Save Widget"),
            ),
          ),
        ],
      ),
    );
  }
}
