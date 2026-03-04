import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/app_drawer.dart';
import 'package:wallzy/common/tabbar/custom_tab_bar.dart';
import 'package:wallzy/features/goals/screens/goals_screen.dart';
import 'package:wallzy/features/subscription/screens/subscriptions_screen.dart';
import 'package:wallzy/features/categories/screens/category_settings_tab_screen.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/features/categories/services/migration_service.dart';

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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _runMigration(BuildContext context) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final migrationService = MigrationService(provider);
      await migrationService.migrateTransactions();
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Migration completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      }
    }
  }

  void _showCategoryOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Options",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedDatabaseSync,
                    size: 20,
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: const Text('Migrate Categories'),
                subtitle: const Text(
                  'Sync old transactions to new tags format',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _runMigration(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
              label: 'Categories',
              icon: HugeIcons.strokeRoundedPieChart02,
            ),
          ],
          controller: _tabController,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_tabController.index == 2)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMoreVerticalCircle01,
                size: 16,
                strokeWidth: 2,
                color: Colors.grey,
              ),
              onPressed: () => _showCategoryOptionsSheet(context),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GoalsScreen(),
          SubscriptionsScreen(),
          CategorySettingsTabScreen(),
        ],
      ),
    );
  }
}
