import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockProvider extends ChangeNotifier {
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefKey = 'is_app_lock_enabled';

  bool _isLockEnabled = false;
  bool _isAuthenticated = false;
  bool _canCheckBiometrics = false;
  bool _isInitialized = false;
  bool _isAuthenticating = false;

  bool get isLockEnabled => _isLockEnabled;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;

  AppLockProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool(_prefKey) ?? false;

    // Check hardware support
    final canCheck = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    _canCheckBiometrics = canCheck || isDeviceSupported;

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> toggleLock(bool enable) async {
    // Always authenticate before changing the lock state
    final success = await _authenticateInternal(
      enable
          ? 'Verify your identity to enable App Lock'
          : 'Verify your identity to disable App Lock'
    );
    if (!success) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enable);
    _isLockEnabled = enable;

    // User is now authenticated for this session
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  /// Locks the app (e.g. on background)
  void lockApp() {
    if (_isLockEnabled) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  /// Internal helper that doesn't check _isLockEnabled flag
  Future<bool> _authenticateInternal(String reason) async {
    if (!_canCheckBiometrics) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }

    if (_isAuthenticating) {
      debugPrint("Auth skipped: already in progress");
      return false;
    }

    _isAuthenticating = true;
    try {
      // Using direct params for compatibility with the environment's local_auth version
      final didAuth = await _auth.authenticate(
        localizedReason: reason,
        // ignore: deprecated_member_use
        biometricOnly: false,
      );

      _isAuthenticated = didAuth;
      return didAuth;
    } on PlatformException catch (e) {
      if (e.code == 'authInProgress') {
        debugPrint("Auth skipped: system says auth in progress");
        return false;
      }
      debugPrint("Auth Error: $e");
      return false;
    } catch (e) {
      debugPrint("Auth Error: $e");
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Triggers the native biometric prompt
  Future<bool> authenticate() async {
    if (!_isLockEnabled) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return _authenticateInternal('Use your biometrics to unlock Ledgr');
  }
}
