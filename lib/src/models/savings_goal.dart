import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
  });

  factory SavingsGoal.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawDeadline = data['deadline'];
    final deadline = rawDeadline is Timestamp
        ? rawDeadline.toDate()
        : DateTime.tryParse('${data['deadline']}') ??
              DateTime.now().add(const Duration(days: 30));

    return SavingsGoal(
      id: snapshot.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Savings goal',
      targetAmount: ((data['targetAmount'] as num?) ?? 0).toDouble(),
      currentAmount: ((data['currentAmount'] as num?) ?? 0).toDouble(),
      deadline: deadline,
    );
  }

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;

  double get progress {
    if (targetAmount <= 0) {
      return 0;
    }
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }
}

class SavingsGoalDraft {
  const SavingsGoalDraft({
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
  });

  factory SavingsGoalDraft.fromGoal(SavingsGoal goal) {
    return SavingsGoalDraft(
      name: goal.name,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      deadline: goal.deadline,
    );
  }

  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;

  Map<String, Object?> toFirestore() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
