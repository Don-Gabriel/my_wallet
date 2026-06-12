import '../models/budget.dart';
import '../models/transaction.dart';
import 'formatters.dart';

class CategoryRule {
  const CategoryRule({required this.category, required this.keywords});

  final String category;
  final List<String> keywords;
}

class DuplicateCandidate {
  const DuplicateCandidate(this.transaction);

  final WalletTransaction transaction;
}

class SubscriptionCandidate {
  const SubscriptionCandidate({
    required this.title,
    required this.category,
    required this.amount,
    required this.count,
    required this.lastDate,
  });

  final String title;
  final String category;
  final double amount;
  final int count;
  final DateTime lastDate;
}

class MonthCloseSnapshot {
  const MonthCloseSnapshot({
    required this.month,
    required this.income,
    required this.expense,
    required this.savings,
    required this.topCategory,
  });

  final DateTime month;
  final double income;
  final double expense;
  final double savings;
  final String topCategory;

  String get title {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }
}

const defaultCategoryRules = [
  CategoryRule(
    category: 'Transport',
    keywords: ['uber', 'ola', 'rapido', 'metro', 'train', 'bus', 'fuel'],
  ),
  CategoryRule(
    category: 'Food',
    keywords: ['swiggy', 'zomato', 'restaurant', 'cafe', 'coffee', 'lunch'],
  ),
  CategoryRule(
    category: 'Shopping',
    keywords: ['amazon', 'flipkart', 'myntra', 'store', 'mall'],
  ),
  CategoryRule(
    category: 'Bills',
    keywords: ['electricity', 'wifi', 'internet', 'rent', 'recharge', 'bill'],
  ),
  CategoryRule(
    category: 'Health',
    keywords: ['doctor', 'pharmacy', 'medicine', 'hospital'],
  ),
  CategoryRule(
    category: 'Entertainment',
    keywords: ['netflix', 'prime', 'spotify', 'movie', 'game'],
  ),
];

String? suggestCategoryFromText(String text, List<String> activeCategories) {
  final query = text.trim().toLowerCase();
  if (query.isEmpty) {
    return null;
  }
  final active = activeCategories.map((item) => item.toLowerCase()).toSet();
  for (final rule in defaultCategoryRules) {
    if (!active.contains(rule.category.toLowerCase())) {
      continue;
    }
    if (rule.keywords.any(query.contains)) {
      return activeCategories.firstWhere(
        (item) => item.toLowerCase() == rule.category.toLowerCase(),
      );
    }
  }
  return null;
}

DuplicateCandidate? findDuplicateCandidate(
  TransactionDraft draft,
  List<WalletTransaction> transactions, {
  String? ignoreTransactionId,
}) {
  final draftDay = DateTime(draft.date.year, draft.date.month, draft.date.day);
  for (final transaction in transactions) {
    if (transaction.id == ignoreTransactionId) {
      continue;
    }
    final transactionDay = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final sameDay = transactionDay == draftDay;
    final sameAmount = (transaction.amount - draft.amount).abs() < 0.01;
    final sameCategory = transaction.category == draft.category;
    final sameType = transaction.type == draft.type;
    final sameWallet = transaction.walletId == draft.walletId;
    if (sameDay && sameAmount && sameCategory && sameType && sameWallet) {
      return DuplicateCandidate(transaction);
    }
  }
  return null;
}

List<SubscriptionCandidate> detectSubscriptions(
  List<WalletTransaction> transactions,
) {
  final grouped = <String, List<WalletTransaction>>{};
  for (final transaction in transactions) {
    if (transaction.type != WalletTransactionType.expense) {
      continue;
    }
    final title = _merchantTitle(transaction);
    if (title.length < 3) {
      continue;
    }
    final key = '${transaction.category.toLowerCase()}|${title.toLowerCase()}';
    grouped.putIfAbsent(key, () => []).add(transaction);
  }

  final candidates = <SubscriptionCandidate>[];
  for (final items in grouped.values) {
    if (items.length < 2) {
      continue;
    }
    items.sort((left, right) => right.date.compareTo(left.date));
    final months = {
      for (final item in items) DateTime(item.date.year, item.date.month),
    };
    if (months.length < 2) {
      continue;
    }
    final average =
        items.fold<double>(0, (total, item) => total + item.amount) /
        items.length;
    candidates.add(
      SubscriptionCandidate(
        title: _merchantTitle(items.first),
        category: items.first.category,
        amount: average,
        count: items.length,
        lastDate: items.first.date,
      ),
    );
  }

  candidates.sort((left, right) => right.count.compareTo(left.count));
  return candidates;
}

List<MonthCloseSnapshot> buildMonthCloseSnapshots(
  List<WalletTransaction> transactions, {
  int limit = 6,
}) {
  final now = DateTime.now();
  final months = <DateTime>{};
  for (final transaction in transactions) {
    final month = DateTime(transaction.date.year, transaction.date.month);
    if (month.isBefore(DateTime(now.year, now.month))) {
      months.add(month);
    }
  }

  final snapshots = <MonthCloseSnapshot>[];
  for (final month in months) {
    var income = 0.0;
    var expense = 0.0;
    final categoryTotals = <String, double>{};
    for (final transaction in transactions) {
      if (!isSameMonth(transaction.date, month)) {
        continue;
      }
      switch (transaction.type) {
        case WalletTransactionType.income || WalletTransactionType.refund:
          income += transaction.amount;
        case WalletTransactionType.expense:
          expense += transaction.amount;
          categoryTotals.update(
            transaction.category,
            (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        case WalletTransactionType.transfer:
          break;
      }
    }
    final top = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    snapshots.add(
      MonthCloseSnapshot(
        month: month,
        income: income,
        expense: expense,
        savings: income - expense,
        topCategory: top.isEmpty ? 'None yet' : top.first.key,
      ),
    );
  }

  snapshots.sort((left, right) => right.month.compareTo(left.month));
  return snapshots.take(limit).toList();
}

double? suggestedMonthlyBudget(List<WalletTransaction> transactions) {
  final now = DateTime.now();
  final totals = <DateTime, double>{};
  for (final transaction in transactions) {
    if (transaction.type != WalletTransactionType.expense) {
      continue;
    }
    final month = DateTime(transaction.date.year, transaction.date.month);
    if (!month.isBefore(DateTime(now.year, now.month))) {
      continue;
    }
    totals.update(
      month,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }
  if (totals.isEmpty) {
    return null;
  }
  final recent = totals.entries.toList()
    ..sort((left, right) => right.key.compareTo(left.key));
  final values = recent.take(3).map((entry) => entry.value).toList();
  final average =
      values.fold<double>(0, (total, value) => total + value) / values.length;
  return average * 1.05;
}

String safeToSpendLabel(WalletBudget budget, double spent) {
  if (!budget.hasBudget) {
    return 'Set a budget to see safe daily spending.';
  }
  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final remainingDays = (daysInMonth - now.day + 1).clamp(1, 31).toInt();
  final remaining = (budget.monthlyLimit - spent)
      .clamp(0.0, double.infinity)
      .toDouble();
  return 'You can spend ${formatMoney(remaining / remainingDays)} today.';
}

String _merchantTitle(WalletTransaction transaction) {
  final notes = transaction.notes.trim();
  if (notes.isEmpty) {
    return transaction.category;
  }
  return notes.split(RegExp(r'\s+')).take(3).join(' ');
}
