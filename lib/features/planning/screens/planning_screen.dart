import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/common/tabbar/custom_tab_bar.dart';
import 'package:wallzy/features/goals/screens/goals_screen.dart';
import 'package:wallzy/features/planning/widgets/budget_tab_screen.dart';
import 'package:wallzy/features/subscription/screens/subscriptions_screen.dart';
import 'package:wallzy/features/categories/screens/category_settings_tab_screen.dart';

class PlanningScreen extends StatefulWidget {
  final int? initialTabIndex;
  const PlanningScreen({super.key, this.initialTabIndex});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      drawer: const AppDrawer(selectedItem: DrawerItem.planning, isRoot: false),
      appBar: AppBar(
        toolbarHeight: height * 0.08,
        title: CustomTabBar(
          tabs: [
            CustomTabItem(
              label: 'Goals',
              icon: HugeIcons.strokeRoundedTarget02,
            ),
            CustomTabItem(
              label: 'Recurring',
              icon: HugeIcons.strokeRoundedRotate02,
            ),
            CustomTabItem(
              label: 'Budgets',
              icon: HugeIcons.strokeRoundedAnalytics03,
            ),
            CustomTabItem(
              label: 'Categories',
              icon: HugeIcons.strokeRoundedLayout01,
            ),
          ],
          controller: _tabController,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        surfaceTintColor: Colors.transparent,
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GoalsScreen(),
          SubscriptionsScreen(),
          BudgetTabScreen(),
          CategorySettingsTabScreen(),
        ],
      ),
    );
  }
}
