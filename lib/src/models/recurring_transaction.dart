import 'package:cloud_firestore/cloud_firestore.dart';

import 'transaction.dart';
import 'wallet_account.dart';

enum RecurringInterval { weekly, monthly }

extension RecurringIntervalLabel on RecurringInterval {
  String get label {
    return switch (this) {
      RecurringInterval.weekly => 'Weekly',
      RecurringInterval.monthly => 'Monthly',
    };
  }
}

RecurringInterval recurringIntervalFromStorage(String? value) {
  return RecurringInterval.values.firstWhere(
    (interval) => interval.name == value,
    orElse: () => RecurringInterval.monthly,
  );
}

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.interval,
    required this.nextDate,
    required this.walletId,
    this.notes = '',
    this.isPaused = false,
  });

  factory RecurringTransaction.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawNextDate = data['nextDate'];
    final nextDate = rawNextDate is Timestamp
        ? rawNextDate.toDate()
        : DateTime.tryParse('${data['nextDate']}') ??
              DateTime.now().add(const Duration(days: 30));

    return RecurringTransaction(
      id: snapshot.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Recurring item',
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Other',
      type: transactionTypeFromStorage(data['type'] as String?),
      interval: recurringIntervalFromStorage(data['interval'] as String?),
      nextDate: nextDate,
      walletId: (data['walletId'] as String?)?.trim().isNotEmpty == true
          ? data['walletId'] as String
          : defaultWalletId,
      notes: (data['notes'] as String?)?.trim() ?? '',
      isPaused: (data['isPaused'] as bool?) ?? false,
    );
  }

  final String id;
  final String title;
  final double amount;
  final String category;
  final WalletTransactionType type;
  final RecurringInterval interval;
  final DateTime nextDate;
  final String walletId;
  final String notes;
  final bool isPaused;
}

class RecurringTransactionDraft {
  const RecurringTransactionDraft({
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.interval,
    required this.nextDate,
    required this.walletId,
    this.notes = '',
    this.isPaused = false,
  });

  factory RecurringTransactionDraft.fromRecurring(
    RecurringTransaction recurring,
  ) {
    return RecurringTransactionDraft(
      title: recurring.title,
      amount: recurring.amount,
      category: recurring.category,
      type: recurring.type,
      interval: recurring.interval,
      nextDate: recurring.nextDate,
      walletId: recurring.walletId,
      notes: recurring.notes,
      isPaused: recurring.isPaused,
    );
  }

  final String title;
  final double amount;
  final String category;
  final WalletTransactionType type;
  final RecurringInterval interval;
  final DateTime nextDate;
  final String walletId;
  final String notes;
  final bool isPaused;

  Map<String, Object?> toFirestore() {
    return {
      'title': title.trim(),
      'amount': amount,
      'category': category,
      'type': type.name,
      'interval': interval.name,
      'nextDate': Timestamp.fromDate(nextDate),
      'walletId': walletId,
      'notes': notes.trim(),
      'isPaused': isPaused,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
