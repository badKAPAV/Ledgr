import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/accounts/models/account.dart';
import 'package:wallzy/features/settings/provider/settings_provider.dart';
import 'package:wallzy/common/progress_bar/segmented_progress_bar.dart';

class CreditLimitBlock extends StatelessWidget {
  final Account account;
  final double totalCreditDue;

  const CreditLimitBlock({
    super.key,
    required this.account,
    required this.totalCreditDue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final limit = account.creditLimit ?? 0.0;

    if (limit <= 0) return const SizedBox.shrink();

    final used = totalCreditDue;
    final available = limit - used;
    final utilization = (used / limit).clamp(0.0, 1.0);

    final isHighUtilization = utilization > 0.75;
    final healthColor = isHighUtilization
        ? colorScheme.error
        : colorScheme.primary;
    final emptyColor = colorScheme.onSurface.withAlpha(38);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CREDIT HEALTH",
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(178),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHighUtilization
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: healthColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHighUtilization ? "High Usage" : "Good",
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(available),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Available Limit",
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(130),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedProgressBar(
            height: 12,
            gap: 6,
            segments: [
              if (used > 0) Segment(value: used, color: healthColor),
              if (available > 0) Segment(value: available, color: emptyColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "USED",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(used),
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: colorScheme.onSurface.withAlpha(50),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL LIMIT",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(153),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(limit),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
