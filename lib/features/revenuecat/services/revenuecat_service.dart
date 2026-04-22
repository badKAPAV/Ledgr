import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class RevenueCatService {
  // Singleton pattern
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // The API key provided for testing
  static const String _apiKey = 'test_aNGdnUNtEsYSIcseOHnkMucBCJz';
  
  // Entitlement ID
  static const String entitlementId = 'Ledgr Max';

  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  Future<void> initialize() async {
    if (_isConfigured) return;

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      
      PurchasesConfiguration configuration;
      // Using the single API key provided. In production, consider splitting
      // keys based on Platform.isIOS / Platform.isAndroid.
      if (Platform.isIOS || Platform.isMacOS) {
        configuration = PurchasesConfiguration(_apiKey);
      } else if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_apiKey);
      } else {
        debugPrint('RevenueCat is not supported on this platform');
        return;
      }

      await Purchases.configure(configuration);
      _isConfigured = true;
      debugPrint("RevenueCat initialized successfully.");
    } catch (e) {
      debugPrint("Error initializing RevenueCat: $e");
    }
  }

  /// Logs the user in with their Firebase UID
  Future<void> logIn(String appUserId) async {
    if (!_isConfigured) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (e) {
      debugPrint("Error logging in RevenueCat: $e");
    }
  }

  /// Logs the user out
  Future<void> logOut() async {
    if (!_isConfigured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint("Error logging out RevenueCat: $e");
    }
  }

  /// Checks if the user has the pro entitlement
  Future<bool> isUserPro() async {
    if (!_isConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _hasProEntitlement(customerInfo);
    } catch (e) {
      debugPrint("Error fetching customer info: $e");
      return false;
    }
  }

  /// Restores purchases
  Future<bool> restorePurchases() async {
    if (!_isConfigured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _hasProEntitlement(customerInfo);
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
      return false;
    }
  }

  /// Presents the Paywall only if the user does NOT have the specific entitlement
  Future<bool> presentPaywallIfNeeded() async {
    if (!_isConfigured) return false;
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
        entitlementId,
        displayCloseButton: true,
      );
      return paywallResult == PaywallResult.purchased || paywallResult == PaywallResult.restored;
    } catch (e) {
      debugPrint("Error presenting conditional paywall: $e");
      return false;
    }
  }

  /// Presents the Paywall unconditionally (e.g., from settings or upgrade button)
  Future<bool> presentPaywall() async {
    if (!_isConfigured) return false;
    try {
      final paywallResult = await RevenueCatUI.presentPaywall(
        displayCloseButton: true,
      );
      return paywallResult == PaywallResult.purchased || paywallResult == PaywallResult.restored;
    } catch (e) {
      debugPrint("Error presenting paywall: $e");
      return false;
    }
  }

  /// Presents the RevenueCat Customer Center (for managing sub / contacting support)
  Future<void> showCustomerCenter() async {
    if (!_isConfigured) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint("Error presenting Customer Center: $e");
    }
  }

  bool _hasProEntitlement(CustomerInfo customerInfo) {
    return customerInfo.entitlements.all[entitlementId]?.isActive == true;
  }
}
