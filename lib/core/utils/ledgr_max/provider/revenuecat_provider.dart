import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:wallzy/core/utils/ledgr_max/services/revenuecat_service.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';

class RevenueCatProvider with ChangeNotifier {
  final RevenueCatService _revenueCatService = RevenueCatService();
  AuthProvider authProvider;

  bool _isPro;
  CustomerInfo? _customerInfo;

  bool get isPro => _isPro;
  CustomerInfo? get customerInfo => _customerInfo;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;
  String? _lastSeenUid;

  DateTime? get expirationDate {
    final entitlement =
        _customerInfo?.entitlements.all[RevenueCatService.entitlementId];
    final expStr = entitlement?.expirationDate;
    if (expStr == null) return null;
    return DateTime.tryParse(expStr);
  }

  RevenueCatProvider({required this.authProvider, bool initialIsPro = false})
    : _isPro = initialIsPro {
    _init();
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    final currentUid = authProvider.user?.uid;

    if (currentUid != null && currentUid != _lastSeenUid) {
      // 1. User logged in! Tell RevenueCat who they are.
      _lastSeenUid = currentUid;
      _revenueCatService.logIn(currentUid).then((_) {
        // 2. Fetch their specific data
        _checkEntitlements();
      });
    } else if (currentUid == null && _lastSeenUid != null) {
      // User logged out
      _lastSeenUid = null;
      _revenueCatService.logOut();
      _isPro = false;
      notifyListeners();
    }
  }

  Future<void> _init() async {
    await _revenueCatService.initialize();

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateCustomerInfo(customerInfo);
    });

    await _checkEntitlements();
  }

  Future<void> _checkEntitlements() async {
    if (!_revenueCatService.isConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _updateCustomerInfo(info);

      final offerings = await _revenueCatService.getOfferings();
      _offerings = offerings;
      notifyListeners();
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

  Future<bool> purchasePackage(Package package) async {
    final success = await _revenueCatService.purchasePackage(
      package,
      // customerInfo!,
    );
    if (success) {
      await _checkEntitlements(); // Refresh local state
    }
    return success;
  }
}
