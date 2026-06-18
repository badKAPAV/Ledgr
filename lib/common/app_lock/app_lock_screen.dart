import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/app_lock/app_lock_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
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
                SvgPicture.asset(
                  'assets/vectors/ledgr.svg',
                  height: 120,
                  width: 120,
                  colorFilter: ColorFilter.mode(
                    colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),

                const SizedBox(height: 10),

                // Mixed Typography Headline
                // RichText(
                //   textAlign: TextAlign.center,
                //   text: TextSpan(
                //     style: theme.textTheme.headlineMedium?.copyWith(
                //       fontWeight: FontWeight.bold,
                //       color: colorScheme.onSurface,
                //       letterSpacing: -0.5,
                //     ),
                //     children: [
                //       TextSpan(
                //         text: "Unlock ledgr",
                //         style: TextStyle(
                //           fontFamily: 'momo', // Custom font for brand
                //           color: colorScheme.primary,
                //           fontWeight: FontWeight.w400,
                //           fontSize: 36, // Slightly larger for emphasis
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                // const SizedBox(height: 60),

                // Unlock Button
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Provider.of<AppLockProvider>(
                      context,
                      listen: false,
                    ).authenticate();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainer,
                    foregroundColor: colorScheme.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28), // Pill shape
                    ),
                  ),
                  label: const Text(
                    "Unlock",
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
