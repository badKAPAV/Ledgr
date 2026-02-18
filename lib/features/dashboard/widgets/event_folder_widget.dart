import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/common/pie_chart/pie_chart_widget.dart'; // Use LedgrPieChart
import 'package:wallzy/common/pie_chart/pie_model.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/tag/models/tag.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';

class EventFolderWidget extends StatefulWidget {
  const EventFolderWidget({super.key});

  @override
  State<EventFolderWidget> createState() => _EventFolderWidgetState();
}

class _EventFolderWidgetState extends State<EventFolderWidget> {
  final PageController _pageController = PageController(viewportFraction: 1.0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaProvider = Provider.of<MetaProvider>(context);

    // Filter active events based on date
    final activeFolders = metaProvider.getActiveEventFolders().where((tag) {
      if (tag.eventStartDate == null || tag.eventEndDate == null) return false;
      final now = DateTime.now();
      final start = tag.eventStartDate!;
      // Add 1 day to end date to include the full end day
      final end = tag.eventEndDate!.add(const Duration(days: 1));
      return now.isAfter(start) && now.isBefore(end);
    }).toList();

    if (activeFolders.isEmpty) {
      return _buildEmptyState(theme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: activeFolders.length,
              clipBehavior: Clip.none,
              itemBuilder: (context, index) {
                return _EventFolderItem(
                  tagId:
                      activeFolders[index].id, // Pass ID to re-fetch fresh data
                );
              },
            ),
            if (activeFolders.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: _PageIndicator(
                    count: activeFolders.length,
                    controller: _pageController,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 24,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No Active Events",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Enable 'Event Mode' in a folder settings to track trips or projects here.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFolderItem extends StatelessWidget {
  final String tagId;

  const _EventFolderItem({required this.tagId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final metaProvider = Provider.of<MetaProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    // 1. Re-fetch the tag to ensure we have the latest Icon and Budget data
    final currentTag = metaProvider.tags.firstWhere(
      (t) => t.id == tagId,
      orElse: () => Tag(
        id: 'unknown',
        name: 'Unknown',
        iconKey: 'folder',
        createdAt: DateTime.now(),
      ),
    );

    // 2. Determine Date Range Logic
    DateTime rangeStart;
    DateTime rangeEnd;
    String labelSuffix = "";

    if (currentTag.tagBudgetFrequency == TagBudgetResetFrequency.monthly) {
      final now = DateTime.now();
      final range = BudgetCycleHelper.getCycleRange(
        targetMonth: now.month,
        targetYear: now.year,
        mode: settingsProvider.budgetCycleMode,
        startDay: settingsProvider.budgetCycleStartDay,
      );
      rangeStart = range.start;
      rangeEnd = range.end;
      labelSuffix = " (THIS MONTH)";
    } else {
      rangeStart = currentTag.eventStartDate ?? DateTime(2000);
      rangeEnd =
          currentTag.eventEndDate?.add(const Duration(days: 1)) ??
          DateTime.now();
      labelSuffix = " (ALL-TIME)";
    }

    // 3. ROBUST DATA CALCULATION (Fixes the 0 balance issue)
    final folderTransactions = txProvider.transactions.where((tx) {
      // A. Match Tag ID
      final hasTag = tx.tags?.any((t) => t.id == currentTag.id) ?? false;
      if (!hasTag) return false;

      // B. Match Date Range (Only for Monthly budgets)
      if (currentTag.tagBudgetFrequency == TagBudgetResetFrequency.monthly) {
        return tx.timestamp.isAfter(
              rangeStart.subtract(const Duration(seconds: 1)),
            ) &&
            tx.timestamp.isBefore(rangeEnd.add(const Duration(seconds: 1)));
      }
      return true;
    });

    // Calculate Net Spent (Expense - Income)
    double totalExpense = 0.0;
    double totalIncome = 0.0;

    for (var tx in folderTransactions) {
      if (tx.type == 'expense') {
        totalExpense += tx.amount;
      } else if (tx.type == 'income') {
        totalIncome += tx.amount;
      }
    }

    final double netSpent = totalExpense - totalIncome;

    final budget = currentTag.tagBudget ?? 0.0;
    final hasBudget = budget > 0;

    // Resolve Color
    final tagColor = currentTag.color != null
        ? Color(currentTag.color!)
        : theme.colorScheme.primary;

    final isOverspent = hasBudget && netSpent > budget;
    // Use error color if overspent, otherwise use tag color
    final colorToUse = isOverspent ? theme.colorScheme.error : tagColor;

    // Calculate remaining for the visual pie chart
    final double remaining = hasBudget ? (budget - netSpent) : 0;

    // Build Pie Chart Sections like TagBudgetCard
    final List<PieData> sections = [];
    if (hasBudget) {
      sections.add(
        PieData(
          value: netSpent.clamp(0.0, budget), // Cap visual at budget
          color: colorToUse,
        ),
      );
      sections.add(
        PieData(
          value: remaining > 0 ? remaining : 0,
          color: colorToUse.withOpacity(
            0.3,
          ), // Faded color for remaining match TagBudgetCard
        ),
      );
    }

    final iconKey = (currentTag.iconKey == null || currentTag.iconKey!.isEmpty)
        ? 'folder'
        : currentTag.iconKey;

    return Container(
      clipBehavior: Clip.antiAlias, // Ensures the huge icon cuts off cleanly
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer, // Solid base
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isOverspent
              ? theme.colorScheme.error.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Stack(
        children: [
          // 1. PREMIUM GLOW (Spotlight Effect)
          // A soft radial gradient emanating from the Top-Right
          Positioned(
            top: -250,
            right: -250,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorToUse.withValues(alpha: 0.25), // Soft colored glow
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // 2. WATERMARK ICON (Bottom-Right for balance)
          Positioned(
            left: -60,
            bottom: -60,
            child: Transform.rotate(
              angle: -0.2,
              child: HugeIcon(
                icon: GoalIconRegistry.getFolderIcon(iconKey),
                size: 240,
                color: colorToUse.withValues(alpha: 0.06), // Very subtle
              ),
            ),
          ),

          // 3. MAIN CONTENT
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Left Side: Info & Metrics
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: tagColor.withOpacity(0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentTag.name.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Spent Amount
                      Text(
                        "SPENT${labelSuffix == " (ALL-TIME)" ? "" : labelSuffix}", // Simplify suffix
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "$currencySymbol${netSpent.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontFamily: 'momo',
                            fontSize: 42, // Larger
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: isOverspent
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),

                      // Budget Pill
                      if (hasBudget) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isOverspent
                                ? theme.colorScheme.error.withValues(alpha: 0.1)
                                : theme.colorScheme.surface.withValues(
                                    alpha: 0.6,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverspent
                                  ? theme.colorScheme.error.withValues(
                                      alpha: 0.2,
                                    )
                                  : theme.colorScheme.outlineVariant.withValues(
                                      alpha: 0.2,
                                    ),
                            ),
                          ),
                          child: Text(
                            isOverspent
                                ? "Over Budget!"
                                : "of $currencySymbol${budget.toStringAsFixed(0)} limit",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isOverspent
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),

                // Right Side: Pie Chart
                if (hasBudget)
                  Expanded(
                    flex: 2,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Chart
                          LedgrPieChart(
                            sections: sections,
                            thickness: 18,
                            gap: 0,
                            emptyColor: Colors.transparent,
                          ),

                          // Center Icon
                          // Glassmorphism effect for the center icon container
                          HugeIcon(
                            icon: GoalIconRegistry.getFolderIcon(iconKey),
                            size: 32,
                            strokeWidth: 2,
                            color: colorToUse,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final PageController controller;

  const _PageIndicator({required this.count, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        int currentPage = 0;
        try {
          currentPage = controller.page?.round() ?? 0;
        } catch (_) {}

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (index) {
            final isSelected = index == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 20 : 6, // Longer active dash
              height: 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
