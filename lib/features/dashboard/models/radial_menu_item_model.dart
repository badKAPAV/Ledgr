import 'package:flutter/material.dart';
import 'package:wallzy/core/utils/ledgr_max/paywall/paywall_features.dart';

class RadialMenuItem {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final PaywallFeature? feature;
  final int? currentCount;

  RadialMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.feature,
    this.currentCount,
  });
}
