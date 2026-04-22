import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Image.asset(
                  'assets/images/landing_content.png',
                  // Optional fallback styling in case aspect ratio is tall
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),

              // Small Logo + Name row (or column)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/ledgr_logo.png', height: 60),
                  const SizedBox(width: 8),
                  Text(
                    'ledgr',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      fontFamily: 'momo',
                      letterSpacing: -1,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your money, mastered.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  fontFamily: 'momo',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),
              TextButton(
                onPressed: () {
                  context.read<AuthProvider>().markLandingSeen();
                },
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 24,
                        color: colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}
