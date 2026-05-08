import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/common/app_lock/app_lock_provider.dart';
import 'package:wallzy/common/app_lock/app_lock_screen.dart';

class BiometricGuard extends StatefulWidget {
  final Widget child;

  const BiometricGuard({super.key, required this.child});

  @override
  State<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<BiometricGuard>
    with WidgetsBindingObserver {
  bool _wasLockedByBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial Check on Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppLockProvider>(context, listen: false);
      if (provider.isLockEnabled && !provider.isAuthenticated) {
        provider.authenticate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = Provider.of<AppLockProvider>(context, listen: false);

    // CRITICAL FIX: The OS biometric overlay triggers a paused/inactive state.
    // If we are currently showing the prompt, DO NOT lock the app.
    if (provider.isAuthenticating) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (provider.isLockEnabled) {
        _wasLockedByBackground = true;
      }
      provider.lockApp();
    } else if (state == AppLifecycleState.resumed) {
      // App came back -> If locked, trigger auth
      if (provider.isLockEnabled && !provider.isAuthenticated && _wasLockedByBackground) {
        _wasLockedByBackground = false;
        // Give the native OS 200ms to fully wake the Activity window
        // before asking it to draw the biometric overlay.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) provider.authenticate();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We consume the provider to rebuild when locked/unlocked
    return Consumer<AppLockProvider>(
      builder: (context, provider, _) {
        // If not initialized, don't show the app yet to prevent a "flash"
        if (!provider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Stack(
          children: [
            // Always keep the child in the tree so it maintains its state
            widget.child,

            // If lock is enabled AND not authenticated, cover the app with LockScreen
            if (provider.isLockEnabled && !provider.isAuthenticated)
              const Positioned.fill(
                child: LockScreen(),
              ),
          ],
        );
      },
    );
  }
}
