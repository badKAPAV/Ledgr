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

    if (state == AppLifecycleState.paused) {
      // App went to background -> Lock it
      // Note: We don't authenticate immediately on pause, we just set the flag
      provider.lockApp();
    } else if (state == AppLifecycleState.resumed) {
      // App came back -> If locked, trigger auth
      if (provider.isLockEnabled && !provider.isAuthenticated) {
        provider.authenticate();
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

        // If lock is enabled AND not authenticated, show LockScreen
        // Otherwise show the actual app (child)
        if (provider.isLockEnabled && !provider.isAuthenticated) {
          return const LockScreen();
        }
        return widget.child;
      },
    );
  }
}
