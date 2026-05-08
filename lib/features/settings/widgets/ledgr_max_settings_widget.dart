import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/core/utils/ledgr_max/provider/revenuecat_provider.dart';
import 'package:wallzy/core/utils/ledgr_max/screens/revenuecat_paywall_screen.dart';
import 'package:wallzy/core/utils/ledgr_max/services/revenuecat_service.dart';

class LedgrMaxSettingsButton extends StatelessWidget {
  const LedgrMaxSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RevenueCatProvider>(
      builder: (context, rcProvider, _) {
        return _LedgrMaxStatusButton(
          isPro: rcProvider.isPro,
          onTap: () {
            if (rcProvider.isPro) {
              RevenueCatService().showCustomerCenter();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PaywallScreen()),
              );
            }
          },
        );
      },
    );
  }
}

class _LedgrMaxStatusButton extends StatelessWidget {
  final bool isPro;
  final VoidCallback onTap;

  const _LedgrMaxStatusButton({required this.isPro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              Text(
                isPro ? "manage" : "unlock",
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
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onSurface.withOpacity(0.6),
                size: 16,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
