import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'wallet_account.dart';

enum WalletTransactionType { expense, income, transfer, refund }

extension WalletTransactionTypeLabel on WalletTransactionType {
  String get label {
    return switch (this) {
      WalletTransactionType.expense => 'Expense',
      WalletTransactionType.income => 'Income',
      WalletTransactionType.transfer => 'Transfer',
      WalletTransactionType.refund => 'Refund',
    };
  }

  double impactFor(double amount) {
    return switch (this) {
      WalletTransactionType.expense => -amount,
      WalletTransactionType.income => amount,
      WalletTransactionType.refund => amount,
      WalletTransactionType.transfer => 0,
    };
  }

  IconData get icon {
    return switch (this) {
      WalletTransactionType.expense => Icons.arrow_downward,
      WalletTransactionType.income => Icons.arrow_upward,
      WalletTransactionType.transfer => Icons.swap_horiz,
      WalletTransactionType.refund => Icons.undo,
    };
  }
}

WalletTransactionType transactionTypeFromStorage(String? value) {
  return WalletTransactionType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => WalletTransactionType.expense,
  );
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.walletId,
    this.notes = '',
    this.transferWalletId,
    this.paymentMethod = '',
    this.linkedTransactionId,
    this.isSplit = false,
  });

  factory WalletTransaction.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return WalletTransaction.fromData(snapshot.id, snapshot.data());
  }

  factory WalletTransaction.fromData(String id, Map<String, dynamic> data) {
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse('${data['date']}') ?? DateTime.now();

    return WalletTransaction(
      id: id,
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Other',
      type: transactionTypeFromStorage(data['type'] as String?),
      date: date,
      walletId: (data['walletId'] as String?)?.trim().isNotEmpty == true
          ? data['walletId'] as String
          : defaultWalletId,
      notes: (data['notes'] as String?)?.trim() ?? '',
      transferWalletId:
          (data['transferWalletId'] as String?)?.trim().isNotEmpty == true
          ? data['transferWalletId'] as String
          : null,
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? '',
      linkedTransactionId:
          (data['linkedTransactionId'] as String?)?.trim().isNotEmpty == true
          ? data['linkedTransactionId'] as String
          : null,
      isSplit: (data['isSplit'] as bool?) ?? false,
    );
  }

  final String id;
  final double amount;
  final String category;
  final WalletTransactionType type;
  final DateTime date;
  final String walletId;
  final String notes;
  final String? transferWalletId;
  final String paymentMethod;
  final String? linkedTransactionId;
  final bool isSplit;

  double get balanceImpact => type.impactFor(amount);

  double impactForWallet(String accountId) {
    if (type == WalletTransactionType.transfer) {
      if (walletId == accountId) {
        return -amount;
      }
      if (transferWalletId == accountId) {
        return amount;
      }
      return 0;
    }

    return walletId == accountId ? balanceImpact : 0;
  }
}

class TransactionDraft {
  const TransactionDraft({
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.walletId,
    this.notes = '',
    this.transferWalletId,
    this.paymentMethod = '',
    this.linkedTransactionId,
    this.isSplit = false,
  });

  factory TransactionDraft.fromTransaction(WalletTransaction transaction) {
    return TransactionDraft(
      amount: transaction.amount,
      category: transaction.category,
      type: transaction.type,
      date: transaction.date,
      walletId: transaction.walletId,
      notes: transaction.notes,
      transferWalletId: transaction.transferWalletId,
      paymentMethod: transaction.paymentMethod,
      linkedTransactionId: transaction.linkedTransactionId,
      isSplit: transaction.isSplit,
    );
  }

  final double amount;
  final String category;
  final WalletTransactionType type;
  final DateTime date;
  final String walletId;
  final String notes;
  final String? transferWalletId;
  final String paymentMethod;
  final String? linkedTransactionId;
  final bool isSplit;

  Map<String, Object?> toFirestore() {
    return {
      'amount': amount,
      'category': category,
      'type': type.name,
      'date': Timestamp.fromDate(date),
      'walletId': walletId,
      'transferWalletId': transferWalletId,
      'notes': notes,
      'paymentMethod': paymentMethod,
      'linkedTransactionId': linkedTransactionId,
      'isSplit': isSplit,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class TransactionPreset {
  const TransactionPreset({
    required this.category,
    required this.type,
    this.notes = '',
    this.walletId,
    this.amount,
    this.paymentMethod = '',
    this.linkedTransactionId,
    this.isSplit = false,
  });

  final String category;
  final WalletTransactionType type;
  final String notes;
  final String? walletId;
  final double? amount;
  final String paymentMethod;
  final String? linkedTransactionId;
  final bool isSplit;
}
