import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/provider/account_provider.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/dashboard/widgets/rotating_balance.dart';
import 'dart:math' as math;

class NetWorthWidget extends StatefulWidget {
  const NetWorthWidget({super.key});

  @override
  State<NetWorthWidget> createState() => _NetWorthWidgetState();
}

class _NetWorthWidgetState extends State<NetWorthWidget> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    // --- LOGIC SECTION (UNCHANGED) ---
    final currentBalance = accountProvider.getTotalAvailableCash(
      txProvider.transactions,
    );

    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    final thisMonthFlow = txProvider.transactions
        .where((t) => t.timestamp.isAfter(startOfThisMonth))
        .fold<double>(0.0, (sum, t) {
          if (t.type == 'income') return sum + t.amount;
          if (t.type == 'expense') return sum - t.amount;
          return sum;
        });

    final lastMonthBalance = currentBalance - thisMonthFlow;
    final diff = currentBalance - lastMonthBalance;
    final percentChange = lastMonthBalance == 0
        ? (diff > 0 ? 100.0 : 0.0)
        : (diff / lastMonthBalance) * 100;

    final isAhead = percentChange >= 0;

    // --- UI SECTION ---
    return Container(
      // Fixed height ensures it works well in the Smart Stack
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Stack(
        children: [
          // 1. BACKGROUND WATERMARK (Premium Feel)
          Positioned(
            bottom: -40,
            right: -30,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: HugeIcon(
                strokeWidth: 2,
                icon: HugeIcons.strokeRoundedWallet03,
                size: 220,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),

          // 2. PRIVACY TOGGLE (Top Right)
          Positioned(
            right: 20,
            top: 20,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isBalanceVisible = !_isBalanceVisible);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: _isBalanceVisible
                      ? HugeIcons.strokeRoundedView
                      : HugeIcons.strokeRoundedViewOffSlash,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // 3. MAIN CONTENT (Perfectly Centered)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Shrink to fit content
                children: [
                  // Label
                  Text(
                    "TOTAL BALANCE",
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                      color: theme.colorScheme.outline,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BIG BALANCE (Momo Font)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isBalanceVisible = !_isBalanceVisible);
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RollingBalance(
                        isVisible: _isBalanceVisible,
                        symbol: currencySymbol,
                        amount: currentBalance,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 64,
                          height: 1.0,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // BOTTOM INSIGHT PILL
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isAhead
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAhead
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAhead
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 18,
                              color: isAhead
                                  ? Colors.green[300]
                                  : Colors.orange[400],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isAhead
                                        ? Colors.green[400]
                                        : Colors.orange[500],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: isAhead
                                          ? "Nice work! "
                                          : "Heads up! ",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontVariations: [
                                          FontVariation('wght', 800),
                                        ],
                                      ),
                                    ),
                                    TextSpan(
                                      text: isAhead
                                          ? "You're +${percentChange.toStringAsFixed(0)}% over last month."
                                          : "You're ${percentChange.toStringAsFixed(0)}% below last month.",
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
