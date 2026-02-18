import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/tabbar/custom_tab_bar.dart';
import 'package:wallzy/features/transaction/screens/search_transactions_screen.dart';
import 'package:wallzy/features/transaction/widgets/categories_tab_screen.dart';
import 'package:wallzy/features/transaction/widgets/transactions_tab_screen.dart';

import 'package:wallzy/app_drawer.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      drawer: const AppDrawer(selectedItem: DrawerItem.reports, isRoot: false),
      appBar: AppBar(
        toolbarHeight: height * 0.08,
        title: CustomTabBar(
          tabs: [
            CustomTabItem(
              label: 'History',
              icon: HugeIcons.strokeRoundedTransactionHistory,
            ),
            CustomTabItem(
              label: 'Categories',
              icon: HugeIcons.strokeRoundedPieChart02,
            ),
          ],
          controller: _tabController,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        surfaceTintColor: Colors.transparent,
        // bottom: CustomTabBar(
        //   tabs: [
        //     CustomTabItem(
        //       label: 'Transactions',
        //       icon: HugeIcons.strokeRoundedTransactionHistory,
        //     ),
        //     CustomTabItem(
        //       label: 'Categories',
        //       icon: HugeIcons.strokeRoundedPieChart02,
        //     ),
        //   ],
        //   controller: _tabController,
        //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        // ),
        actions: [
          IconButton.filledTonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SearchTransactionsScreen()),
              );
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TransactionsTabScreen(),
          CategoriesTabScreen(),
          // PeopleTabScreen(),
        ],
      ),
    );
  }
}
