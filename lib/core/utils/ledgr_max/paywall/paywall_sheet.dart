import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallzy/core/utils/ledgr_max/screens/revenuecat_paywall_screen.dart';

class PremiumUpsellSheet extends StatefulWidget {
  final String message;

  const PremiumUpsellSheet({super.key, required this.message});

  /// A helper function to easily summon the sheet from anywhere
  static void show(BuildContext context, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumUpsellSheet(message: message),
    );
  }

  @override
  State<PremiumUpsellSheet> createState() => _PremiumUpsellSheetState();
}

class _PremiumUpsellSheetState extends State<PremiumUpsellSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Frosted glass effect
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content tightly
          children: [
            // Premium Header (Styled like Settings Button)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.brightness == Brightness.dark
                      ? [const Color(0xFF1A1F26), const Color(0xFF000000)]
                      : [colorScheme.surface, colorScheme.surfaceContainer],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(
                    theme.brightness == Brightness.dark ? 0.3 : 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.2 : 0.05,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "unlock",
                    style: GoogleFonts.kodeMono(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SvgPicture.asset(
                    'assets/vectors/ledgr_max_logo.svg',
                    height: 40,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // The specific message passed from the Enum (e.g. "Unlock unlimited folders")
            Text(
              widget.message,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Quick Value Props to sweeten the deal
            _buildValueProp(
              context,
              Icons.cloud_done_rounded,
              "Secure Cloud Sync",
            ),
            _buildValueProp(
              context,
              Icons.bolt_rounded,
              "AI Automation & Quick Save",
            ),
            _buildValueProp(
              context,
              Icons.all_inclusive_rounded,
              "Unlimited Folders & History",
            ),
            const SizedBox(height: 22),

            // Primary Action Button (Navigates to Full Paywall)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  // 1. Dismiss the bottom sheet
                  Navigator.of(context).pop();

                  // 2. Push the full Paywall Screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // IMPORTANT: Rename to whatever your actual full screen is called
                      builder: (context) => const PaywallScreen(),
                    ),
                  );
                },
                child: const Text(
                  "See Plans",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Secondary Action (Dismiss)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text(
                "Maybe Later",
                style: TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueProp(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
