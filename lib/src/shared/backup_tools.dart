import 'dart:convert';

import '../models/bill_reminder.dart';
import '../models/budget.dart';
import '../models/category_budget.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/wallet_account.dart';

class WalletBackup {
  const WalletBackup({
    required this.exportedAt,
    required this.categories,
    required this.wallets,
    required this.transactions,
    required this.budget,
    required this.categoryBudgets,
    required this.goals,
    required this.bills,
    required this.recurring,
  });

  factory WalletBackup.fromJson(Map<String, dynamic> json) {
    return WalletBackup(
      exportedAt: _date(json['exportedAt']) ?? DateTime.now(),
      categories: _strings(json['categories']),
      wallets: _objects(json['wallets'])
          .asMap()
          .entries
          .map((entry) => _wallet(entry.value, entry.key))
          .toList(),
      transactions: _objects(json['transactions'])
          .asMap()
          .entries
          .map((entry) => _transaction(entry.value, entry.key))
          .toList(),
      budget: WalletBudget(monthlyLimit: _number(json['monthlyBudget'])),
      categoryBudgets: _objects(
        json['categoryBudgets'],
      ).map(_categoryBudget).toList(),
      goals: _objects(
        json['goals'],
      ).asMap().entries.map((entry) => _goal(entry.value, entry.key)).toList(),
      bills: _objects(
        json['bills'],
      ).asMap().entries.map((entry) => _bill(entry.value, entry.key)).toList(),
      recurring: _objects(json['recurring'])
          .asMap()
          .entries
          .map((entry) => _recurring(entry.value, entry.key))
          .toList(),
    );
  }

  final DateTime exportedAt;
  final List<String> categories;
  final List<WalletAccount> wallets;
  final List<WalletTransaction> transactions;
  final WalletBudget budget;
  final List<CategoryBudget> categoryBudgets;
  final List<SavingsGoal> goals;
  final List<BillReminder> bills;
  final List<RecurringTransaction> recurring;

  int get itemCount {
    return categories.length +
        wallets.length +
        transactions.length +
        categoryBudgets.length +
        goals.length +
        bills.length +
        recurring.length +
        (budget.hasBudget ? 1 : 0);
  }

  Map<String, Object?> toJson() {
    return {
      'format': 'mywallet.backup',
      'version': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'categories': categories,
      'wallets': wallets.map(_walletJson).toList(),
      'transactions': transactions.map(_transactionJson).toList(),
      'monthlyBudget': budget.monthlyLimit,
      'categoryBudgets': categoryBudgets.map(_categoryBudgetJson).toList(),
      'goals': goals.map(_goalJson).toList(),
      'bills': bills.map(_billJson).toList(),
      'recurring': recurring.map(_recurringJson).toList(),
    };
  }
}

String walletBackupToJson(WalletBackup backup) {
  return const JsonEncoder.withIndent('  ').convert(backup.toJson());
}

WalletBackup walletBackupFromJson(String input) {
  final decoded = jsonDecode(input);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('This is not a MyWallet backup file.');
  }
  if (decoded['format'] != 'mywallet.backup') {
    throw const FormatException('This backup file is not supported.');
  }
  return WalletBackup.fromJson(decoded);
}

Map<String, Object?> _walletJson(WalletAccount wallet) {
  return {
    'id': wallet.id,
    'name': wallet.name,
    'openingBalance': wallet.openingBalance,
    'showOnDashboard': wallet.showOnDashboard,
    'isArchived': wallet.isArchived,
  };
}

Map<String, Object?> _transactionJson(WalletTransaction transaction) {
  return {
    'id': transaction.id,
    'amount': transaction.amount,
    'category': transaction.category,
    'type': transaction.type.name,
    'date': transaction.date.toIso8601String(),
    'walletId': transaction.walletId,
    'transferWalletId': transaction.transferWalletId,
    'notes': transaction.notes,
    'paymentMethod': transaction.paymentMethod,
    'linkedTransactionId': transaction.linkedTransactionId,
    'isSplit': transaction.isSplit,
  };
}

Map<String, Object?> _categoryBudgetJson(CategoryBudget budget) {
  return {'category': budget.category, 'monthlyLimit': budget.monthlyLimit};
}

Map<String, Object?> _goalJson(SavingsGoal goal) {
  return {
    'id': goal.id,
    'name': goal.name,
    'targetAmount': goal.targetAmount,
    'currentAmount': goal.currentAmount,
    'deadline': goal.deadline.toIso8601String(),
  };
}

Map<String, Object?> _billJson(BillReminder bill) {
  return {
    'id': bill.id,
    'name': bill.name,
    'amount': bill.amount,
    'category': bill.category,
    'dueDate': bill.dueDate.toIso8601String(),
    'isPaid': bill.isPaid,
  };
}

Map<String, Object?> _recurringJson(RecurringTransaction item) {
  return {
    'id': item.id,
    'title': item.title,
    'amount': item.amount,
    'category': item.category,
    'type': item.type.name,
    'interval': item.interval.name,
    'nextDate': item.nextDate.toIso8601String(),
    'walletId': item.walletId,
    'notes': item.notes,
    'isPaused': item.isPaused,
  };
}

WalletAccount _wallet(Map<String, dynamic> json, int index) {
  return WalletAccount(
    id: _text(
      json['id'],
      fallback: index == 0 ? defaultWalletId : 'wallet-$index',
    ),
    name: _text(json['name'], fallback: 'Wallet'),
    openingBalance: _number(json['openingBalance']),
    showOnDashboard: _boolean(json['showOnDashboard'], fallback: true),
    isArchived: _boolean(json['isArchived']),
  );
}

WalletTransaction _transaction(Map<String, dynamic> json, int index) {
  return WalletTransaction(
    id: _text(json['id'], fallback: 'transaction-$index'),
    amount: _number(json['amount']),
    category: _text(json['category'], fallback: 'Other'),
    type: transactionTypeFromStorage(_text(json['type'])),
    date: _date(json['date']) ?? DateTime.now(),
    walletId: _text(json['walletId'], fallback: defaultWalletId),
    transferWalletId: _nullableText(json['transferWalletId']),
    notes: _text(json['notes']),
    paymentMethod: _text(json['paymentMethod']),
    linkedTransactionId: _nullableText(json['linkedTransactionId']),
    isSplit: _boolean(json['isSplit']),
  );
}

CategoryBudget _categoryBudget(Map<String, dynamic> json) {
  return CategoryBudget(
    category: _text(json['category'], fallback: 'Other'),
    monthlyLimit: _number(json['monthlyLimit']),
  );
}

SavingsGoal _goal(Map<String, dynamic> json, int index) {
  return SavingsGoal(
    id: _text(json['id'], fallback: 'goal-$index'),
    name: _text(json['name'], fallback: 'Savings goal'),
    targetAmount: _number(json['targetAmount']),
    currentAmount: _number(json['currentAmount']),
    deadline: _date(json['deadline']) ?? DateTime.now(),
  );
}

BillReminder _bill(Map<String, dynamic> json, int index) {
  return BillReminder(
    id: _text(json['id'], fallback: 'bill-$index'),
    name: _text(json['name'], fallback: 'Bill'),
    amount: _number(json['amount']),
    category: _text(json['category'], fallback: 'Bills'),
    dueDate: _date(json['dueDate']) ?? DateTime.now(),
    isPaid: _boolean(json['isPaid']),
  );
}

RecurringTransaction _recurring(Map<String, dynamic> json, int index) {
  return RecurringTransaction(
    id: _text(json['id'], fallback: 'recurring-$index'),
    title: _text(json['title'], fallback: 'Recurring item'),
    amount: _number(json['amount']),
    category: _text(json['category'], fallback: 'Other'),
    type: transactionTypeFromStorage(_text(json['type'])),
    interval: recurringIntervalFromStorage(_text(json['interval'])),
    nextDate: _date(json['nextDate']) ?? DateTime.now(),
    walletId: _text(json['walletId'], fallback: defaultWalletId),
    notes: _text(json['notes']),
    isPaused: _boolean(json['isPaused']),
  );
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList();
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

String _text(Object? value, {String fallback = ''}) {
  final text = '$value'.trim();
  return text == 'null' || text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

double _number(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

bool _boolean(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

DateTime? _date(Object? value) {
  return DateTime.tryParse(_text(value));
}
