import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryBudget {
  const CategoryBudget({required this.category, required this.monthlyLimit});

  factory CategoryBudget.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return CategoryBudget(
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : snapshot.id,
      monthlyLimit: ((data['monthlyLimit'] as num?) ?? 0).toDouble(),
    );
  }

  final String category;
  final double monthlyLimit;

  bool get hasLimit => monthlyLimit > 0;

  double progressFor(double spent) {
    if (!hasLimit) {
      return 0;
    }
    return (spent / monthlyLimit).clamp(0.0, 1.0);
  }

  Map<String, Object?> toFirestore() {
    return {
      'category': category,
      'monthlyLimit': monthlyLimit,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
