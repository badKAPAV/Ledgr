import 'package:flutter/material.dart';

class PieData {
  final double value;
  final Color color;
  final Gradient? gradient;

  const PieData({required this.value, this.color = Colors.grey, this.gradient});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PieData &&
        other.value == value &&
        other.color == color &&
        other.gradient == gradient;
  }

  @override
  int get hashCode => Object.hash(value, color, gradient);
}
