import 'package:cloud_firestore/cloud_firestore.dart';

class BillReminder {
  const BillReminder({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.isPaid,
  });

  factory BillReminder.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawDueDate = data['dueDate'];
    final dueDate = rawDueDate is Timestamp
        ? rawDueDate.toDate()
        : DateTime.tryParse('${data['dueDate']}') ??
              DateTime.now().add(const Duration(days: 7));

    return BillReminder(
      id: snapshot.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Bill',
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Bills',
      dueDate: dueDate,
      isPaid: (data['isPaid'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final double amount;
  final String category;
  final DateTime dueDate;
  final bool isPaid;

  int daysUntil(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }
}

class BillReminderDraft {
  const BillReminderDraft({
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDate,
    this.isPaid = false,
  });

  factory BillReminderDraft.fromReminder(BillReminder reminder) {
    return BillReminderDraft(
      name: reminder.name,
      amount: reminder.amount,
      category: reminder.category,
      dueDate: reminder.dueDate,
      isPaid: reminder.isPaid,
    );
  }

  final String name;
  final double amount;
  final String category;
  final DateTime dueDate;
  final bool isPaid;

  Map<String, Object?> toFirestore() {
    return {
      'name': name.trim(),
      'amount': amount,
      'category': category,
      'dueDate': Timestamp.fromDate(dueDate),
      'isPaid': isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
