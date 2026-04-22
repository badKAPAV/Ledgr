import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/planning/widgets/active_budget_view.dart';
import 'package:wallzy/features/planning/widgets/budget_setup_wizard.dart';

class BudgetTabScreen extends StatelessWidget {
  const BudgetTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentBudget = authProvider.user?.monthlyBudget;

        // If no budget is set, launch the Setup Wizard
        if (currentBudget == null || currentBudget <= 0) {
          return const BudgetSetupWizard();
        }

        // Show the beautiful day-to-day dashboard
        return Scaffold(
          body: const ActiveBudgetView(),

          // Floating Debug Button (Only visible in debug mode)
          floatingActionButton: kDebugMode
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await authProvider.updateMonthlyBudget(0);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Debug: Budget reset. Relaunching Wizard.",
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Reset Budget"),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                )
              : null,
        );
      }
    );
  }
}
