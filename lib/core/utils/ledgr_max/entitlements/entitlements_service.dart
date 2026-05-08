import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/core/utils/ledgr_max/entitlements/feature_limits.dart';

class EntitlementsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cacheKey = 'cached_feature_limits';

  Future<Map<String, FeatureLimits>> fetchAllTiers() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Attempt to fetch fresh data from Firebase
      final freeDoc = await _db
          .collection('entitlements')
          .doc('free')
          .get(
            // Force server fetch to ensure we get updates when online
            const GetOptions(source: Source.server),
          );
      final proDoc = await _db
          .collection('entitlements')
          .doc('ledgr_max')
          .get(const GetOptions(source: Source.server));

      if (freeDoc.exists && proDoc.exists) {
        // 2. Parse the fresh data
        final freeLimits = FeatureLimits.fromJson(freeDoc.data()!);
        final proLimits = FeatureLimits.fromJson(proDoc.data()!);

        // 3. Save the fresh data to SharedPreferences for offline use
        final cacheData = {'free': freeDoc.data(), 'pro': proDoc.data()};
        await prefs.setString(_cacheKey, json.encode(cacheData));

        return {'free': freeLimits, 'pro': proLimits};
      } else {
        throw Exception("Documents missing in Firebase");
      }
    } catch (e) {
      debugPrint(
        "Firebase fetch failed. Attempting to load from local cache. Error: $e",
      );

      // 4. FALLBACK: Read from local SharedPreferences cache
      return _loadFromCache(prefs);
    }
  }

  Map<String, FeatureLimits> _loadFromCache(SharedPreferences prefs) {
    final cachedString = prefs.getString(_cacheKey);

    if (cachedString != null) {
      try {
        final decoded = json.decode(cachedString) as Map<String, dynamic>;
        return {
          'free': FeatureLimits.fromJson(decoded['free']),
          'pro': FeatureLimits.fromJson(decoded['pro']),
        };
      } catch (e) {
        debugPrint("Cache corrupted. Using hardcoded fallbacks.");
      }
    }

    // 5. LAST RESORT: Hardcoded fallbacks (Only happens on first launch ever without internet)
    return {
      'free': FeatureLimits.fallbackFree(),
      'pro': FeatureLimits.fallbackPro(),
    };
  }
}
