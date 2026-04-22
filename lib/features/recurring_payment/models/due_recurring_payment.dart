import 'package:uuid/uuid.dart';
import 'package:wallzy/features/recurring_payment/services/recurring_payment_info.dart';

class DueSubscription {
  final String id;
  final String subscriptionName;
  final double averageAmount;
  final String lastCategory;
  final String? lastCategoryId;
  final String lastPaymentMethod;
  final DateTime dueDate;
  final SubscriptionFrequency frequency;

  DueSubscription({
    required this.id,
    required this.subscriptionName,
    required this.averageAmount,
    required this.lastCategory,
    this.lastCategoryId,
    required this.lastPaymentMethod,
    required this.dueDate,
    required this.frequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subscriptionName': subscriptionName,
      'averageAmount': averageAmount,
      'lastCategory': lastCategory,
      'lastCategoryId': lastCategoryId,
      'lastPaymentMethod': lastPaymentMethod,
      'dueDate': dueDate.toIso8601String(),
      'frequency': frequency.name,
    };
  }

  factory DueSubscription.fromMap(Map<String, dynamic> map) {
    return DueSubscription(
      id: map['id'] ?? const Uuid().v4(),
      subscriptionName: map['subscriptionName'] ?? '',
      averageAmount: (map['averageAmount'] ?? 0.0).toDouble(),
      lastCategory: map['lastCategory'] ?? 'Others',
      lastCategoryId: map['lastCategoryId'],
      lastPaymentMethod: map['lastPaymentMethod'] ?? 'Other',
      dueDate: DateTime.parse(map['dueDate']),
      frequency: SubscriptionFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => SubscriptionFrequency.monthly,
      ),
    );
  }
}
