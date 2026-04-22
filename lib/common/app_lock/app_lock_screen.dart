import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/app_lock/app_lock_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AppLockProvider>(context, listen: false).authenticate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Subtle Background Glow (Top Center)
            Positioned(
              top: -100,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            // 2. Main Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFingerPrint,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 40),

                // Mixed Typography Headline
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: "Unlock ledgr",
                        style: TextStyle(
                          fontFamily: 'momo', // Custom font for brand
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w400,
                          fontSize: 36, // Slightly larger for emphasis
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Unlock Button
                SizedBox(
                  width: 220,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Provider.of<AppLockProvider>(
                        context,
                        listen: false,
                      ).authenticate();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28), // Pill shape
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text(
                      "Authenticate",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
    );
  }
}
