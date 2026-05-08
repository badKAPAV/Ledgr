import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  final date = DateTime.now();
  debugPrint(DateFormat("MMM ''yy").format(date));
  debugPrint(DateFormat('MMM \'y').format(date));
  debugPrint(DateFormat("MMM yyyy").format(date));
}
