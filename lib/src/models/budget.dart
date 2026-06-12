import 'package:cloud_firestore/cloud_firestore.dart';

class WalletBudget {
  const WalletBudget({required this.monthlyLimit});

  factory WalletBudget.fromData(Map<String, dynamic>? data) {
    return WalletBudget(
      monthlyLimit: ((data?['monthlyLimit'] as num?) ?? 0).toDouble(),
    );
  }

  final double monthlyLimit;

  bool get hasBudget => monthlyLimit > 0;

  double progressFor(double spent) {
    if (!hasBudget) {
      return 0;
    }
    return (spent / monthlyLimit).clamp(0.0, 1.0);
  }

  Map<String, Object?> toFirestore() {
    return {
      'monthlyLimit': monthlyLimit,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
