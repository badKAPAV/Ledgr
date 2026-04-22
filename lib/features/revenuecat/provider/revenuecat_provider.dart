import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:wallzy/features/revenuecat/services/revenuecat_service.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';

class RevenueCatProvider with ChangeNotifier {
  final RevenueCatService _revenueCatService = RevenueCatService();
  AuthProvider authProvider;

  bool _isPro = false;
  CustomerInfo? _customerInfo;

  bool get isPro => _isPro;
  CustomerInfo? get customerInfo => _customerInfo;

  RevenueCatProvider({required this.authProvider}) {
    _init();
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    // If the user changed, we might want to re-check entitlements
    if (authProvider.user?.uid != newAuthProvider.user?.uid) {
      authProvider = newAuthProvider;
      _checkEntitlements();
    } else {
      authProvider = newAuthProvider;
    }
  }

  Future<void> _init() async {
    // Initialize the SDK if not already done
    await _revenueCatService.initialize();

    // Listen to changes in customer info (e.g. from purchases or expiration)
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateCustomerInfo(customerInfo);
    });

    // Check entitlements immediately
    await _checkEntitlements();
  }

  Future<void> _checkEntitlements() async {
    if (!_revenueCatService.isConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _updateCustomerInfo(info);
    } catch (e) {
      debugPrint("Error fetching customer info for Provider: $e");
    }
  }

  void _updateCustomerInfo(CustomerInfo info) {
    _customerInfo = info;

    // Check if the specific entitlement is active
    final entitlement = info.entitlements.all[RevenueCatService.entitlementId];
    final isActivePro = entitlement?.isActive == true;

    if (_isPro != isActivePro) {
      _isPro = isActivePro;

      // Update Firebase Auth Provider locally to sync state
      if (authProvider.user != null &&
          authProvider.user!.isProUser != isActivePro) {
        // Technically, you might want an update method in AuthProvider
        // that solely persists the new isProUser status to Firestore.
        // For now, it mirrors it logically via the RevenueCatProvider.
      }
      notifyListeners();
    }
  }

  /// Refreshes manually
  Future<void> refresh() async {
    await _checkEntitlements();
  }

  /// Restores purchases
  Future<bool> restorePurchases() async {
    final success = await _revenueCatService.restorePurchases();
    await _checkEntitlements();
    return success;
  }
}
