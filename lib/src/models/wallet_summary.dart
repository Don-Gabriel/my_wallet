import '../shared/formatters.dart';
import 'transaction.dart';

class WalletSummary {
  const WalletSummary({
    required this.currentBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.todaySpend,
    required this.topCategory,
  });

  factory WalletSummary.fromTransactions(
    List<WalletTransaction> transactions,
    DateTime now,
  ) {
    var currentBalance = 0.0;
    var monthlyIncome = 0.0;
    var monthlyExpense = 0.0;
    var todaySpend = 0.0;
    final categoryTotals = <String, double>{};

    for (final transaction in transactions) {
      currentBalance += transaction.balanceImpact;
      final currentMonth = isSameMonth(transaction.date, now);
      final sameDay =
          transaction.date.year == now.year &&
          transaction.date.month == now.month &&
          transaction.date.day == now.day;

      switch (transaction.type) {
        case WalletTransactionType.expense:
          if (currentMonth) {
            monthlyExpense += transaction.amount;
            categoryTotals.update(
              transaction.category,
              (value) => value + transaction.amount,
              ifAbsent: () => transaction.amount,
            );
          }
          if (sameDay) {
            todaySpend += transaction.amount;
          }
        case WalletTransactionType.income || WalletTransactionType.refund:
          if (currentMonth) {
            monthlyIncome += transaction.amount;
          }
        case WalletTransactionType.transfer:
          break;
      }
    }

    final topCategory = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return WalletSummary(
      currentBalance: currentBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      todaySpend: todaySpend,
      topCategory: topCategory.isEmpty ? 'None yet' : topCategory.first.key,
    );
  }

  final double currentBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final double todaySpend;
  final String topCategory;

  double get savingsRate {
    if (monthlyIncome <= 0) {
      return 0;
    }
    return ((monthlyIncome - monthlyExpense) / monthlyIncome).clamp(-1.0, 1.0);
  }
}
