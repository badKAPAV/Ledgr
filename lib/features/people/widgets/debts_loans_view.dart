import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/themes/theme.dart';
import 'package:wallzy/features/people/provider/people_provider.dart';
import 'package:wallzy/features/people/widgets/people_list_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/widgets/empty_report_placeholder.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';

class DebtsLoansView extends StatefulWidget {
  const DebtsLoansView({super.key});

  @override
  State<DebtsLoansView> createState() => _DebtsLoansViewState();
}

class _DebtsLoansViewState extends State<DebtsLoansView> {
  String _selectedType = 'youOwe';

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final peopleProvider = Provider.of<PeopleProvider>(context);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final theme = Theme.of(context);

    final currentList = _selectedType == 'youOwe'
        ? peopleProvider.youOweList
        : peopleProvider.owesYouList;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Dashboard Pod
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _DebtDashboardPod(
              totalYouOwe: peopleProvider.totalYouOwe,
              totalOwesYou: peopleProvider.totalOwesYou,
              currencyFormat: currencyFormat,
            ),
          ),
        ),

        // 2. Segmented Toggle (Now with Sliding Animation)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: _SegmentedDebtToggle(
              selectedType: _selectedType,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
            ),
          ),
        ),

        // 3. List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              _selectedType == 'youOwe'
                  ? 'PEOPLE YOU OWE'
                  : 'PEOPLE WHO OWE YOU',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ),

        // 4. List
        if (currentList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyReportPlaceholder(
              message: "All settled up!",
              icon: HugeIcons.strokeRoundedTick02,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            sliver: PeopleListView(
              people: currentList,
              onDismissed: (person) {
                final newPerson = _selectedType == 'youOwe'
                    ? person.copyWith(youOwe: 0)
                    : person.copyWith(owesYou: 0);

                peopleProvider.updatePerson(newPerson);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    content: const Text('Debt cleared'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        peopleProvider.updatePerson(person);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DebtDashboardPod extends StatelessWidget {
  final double totalYouOwe;
  final double totalOwesYou;
  final NumberFormat currencyFormat;

  const _DebtDashboardPod({
    required this.totalYouOwe,
    required this.totalOwesYou,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final netBalance = totalOwesYou - totalYouOwe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Net Balance (Header)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "NET",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                currencyFormat.format(netBalance),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  height: 1.0,
                  fontFamily: 'momo',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Segmented Progress Bar (Comparison)
          SegmentedProgressBar(
            height: 12,
            gap: 4.0,
            borderRadius: BorderRadius.circular(6),
            segments: [
              Segment(value: totalOwesYou, color: appColors.income),
              Segment(value: totalYouOwe, color: appColors.expense),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Stats Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SimplifiedDebtStat(
                label: "Owes You",
                amount: totalOwesYou,
                color: appColors.income,
                isLeft: true,
              ),
              _SimplifiedDebtStat(
                label: "You Owe",
                amount: totalYouOwe,
                color: appColors.expense,
                isLeft: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimplifiedDebtStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isLeft;

  const _SimplifiedDebtStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: isLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SegmentedDebtToggle extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _SegmentedDebtToggle({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    // Determine current active color for text
    final isYouOwe = selectedType == 'youOwe';

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 1. The Sliding White Background
          AnimatedAlign(
            alignment: isYouOwe ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. The Text Labels (Sitting on top)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTypeSelected('youOwe'),
                  child: Center(
                    child: Text(
                      'You Owe',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isYouOwe
                            ? appColors.expense
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTypeSelected('owesYou'),
                  child: Center(
                    child: Text(
                      'Owes You',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: !isYouOwe
                            ? appColors.income
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
