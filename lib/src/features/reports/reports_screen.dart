import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/budget.dart';
import '../../models/category_budget.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_summary.dart';
import '../../models/wallet_user.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_handling.dart';
import '../../shared/finance_intelligence.dart';
import '../../shared/formatters.dart';
import '../budget/budget_form_sheet.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final WalletRepository repository;
  final WalletUser user;

  Future<void> _openCategoryBudgetSheet(
    BuildContext context, {
    required String category,
    CategoryBudget? budget,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BudgetFormSheet(
        title: '$category budget',
        labelText: 'Monthly limit',
        currentBudget: WalletBudget(monthlyLimit: budget?.monthlyLimit ?? 0),
        onSave: (amount) =>
            repository.setCategoryBudget(user, category, amount),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$category budget updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WalletTransaction>>(
      stream: repository.watchTransactions(user),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? const <WalletTransaction>[];
        if (snapshot.hasError && transactions.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ErrorState(
                  title: 'Reports unavailable',
                  message: friendlyErrorMessage(snapshot.error!),
                ),
              ),
            ),
          );
        }

        return StreamBuilder<List<CategoryBudget>>(
          stream: repository.watchCategoryBudgets(user),
          builder: (context, budgetSnapshot) {
            final summary = WalletSummary.fromTransactions(
              transactions,
              DateTime.now(),
            );
            final categoryTotals = _categoryTotals(transactions);
            final largest =
                transactions
                    .where(
                      (transaction) =>
                          transaction.type == WalletTransactionType.expense,
                    )
                    .toList()
                  ..sort((left, right) => right.amount.compareTo(left.amount));
            final categoryBudgets =
                budgetSnapshot.data ?? const <CategoryBudget>[];

            return StreamBuilder<List<WalletAccount>>(
              stream: repository.watchWallets(user),
              builder: (context, walletSnapshot) {
                final wallets = walletSnapshot.data ?? const <WalletAccount>[];

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionCard(
                            title: 'Monthly analytics',
                            icon: Icons.analytics_outlined,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth > 720
                                    ? 3
                                    : 1;
                                final metrics = [
                                  _ReportMetric(
                                    label: 'Average daily spend',
                                    value: formatMoney(
                                      summary.monthlyExpense /
                                          DateTime.now().day,
                                    ),
                                  ),
                                  _ReportMetric(
                                    label: 'Savings rate',
                                    value:
                                        '${(summary.savingsRate * 100).round()}%',
                                  ),
                                  _ReportMetric(
                                    label: 'Largest expense',
                                    value: largest.isEmpty
                                        ? formatMoney(0)
                                        : formatMoney(largest.first.amount),
                                  ),
                                ];
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: metrics.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: columns == 1
                                            ? 3.2
                                            : 1.55,
                                      ),
                                  itemBuilder: (context, index) =>
                                      metrics[index],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ComparisonSection(transactions: transactions),
                          _MonthlyCloseSection(transactions: transactions),
                          const SizedBox(height: 16),
                          _SpendingHeatmapSection(transactions: transactions),
                          if (_WalletBreakdownSection.shouldShow(wallets)) ...[
                            const SizedBox(height: 16),
                            _WalletBreakdownSection(
                              transactions: transactions,
                              wallets: wallets,
                              error: walletSnapshot.error,
                            ),
                          ],
                          const SizedBox(height: 16),
                          SectionCard(
                            title: 'Top categories',
                            icon: Icons.category_outlined,
                            child: categoryTotals.isEmpty
                                ? const EmptyState(
                                    icon: Icons.bar_chart_outlined,
                                    title: 'No expense categories yet',
                                  )
                                : Column(
                                    children: categoryTotals.map((entry) {
                                      final max = categoryTotals.first.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _CategoryBar(
                                          label: entry.key,
                                          value: entry.value,
                                          progress: max == 0
                                              ? 0
                                              : entry.value / max,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _CategoryBudgetSection(
                            totals: categoryTotals,
                            budgets: categoryBudgets,
                            error: budgetSnapshot.error,
                            onEdit: (category, budget) =>
                                _openCategoryBudgetSheet(
                                  context,
                                  category: category,
                                  budget: budget,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            title: 'This month',
                            icon: Icons.calendar_month_outlined,
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: 'Income',
                                  value: formatMoney(summary.monthlyIncome),
                                ),
                                _SummaryRow(
                                  label: 'Expense',
                                  value: formatMoney(summary.monthlyExpense),
                                ),
                                _SummaryRow(
                                  label: 'Net',
                                  value: formatMoney(
                                    summary.monthlyIncome -
                                        summary.monthlyExpense,
                                    signed: true,
                                  ),
                                ),
                                _IncomeExpenseRatioBar(summary: summary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<MapEntry<String, double>> _categoryTotals(
    List<WalletTransaction> transactions,
  ) {
    final now = DateTime.now();
    final totals = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type != WalletTransactionType.expense ||
          !isSameMonth(transaction.date, now)) {
        continue;
      }
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final current = _MonthStats.fromTransactions(transactions, now);
    final previous = _MonthStats.fromTransactions(transactions, previousMonth);

    return SectionCard(
      title: 'Compared to last month',
      icon: Icons.compare_arrows_outlined,
      child: Column(
        children: [
          _ComparisonRow(
            label: 'Income',
            current: current.income,
            previous: previous.income,
          ),
          _ComparisonRow(
            label: 'Expense',
            current: current.expense,
            previous: previous.expense,
          ),
          _ComparisonRow(
            label: 'Savings',
            current: current.net,
            previous: previous.net,
          ),
        ],
      ),
    );
  }
}

class _MonthlyCloseSection extends StatelessWidget {
  const _MonthlyCloseSection({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final snapshots = buildMonthCloseSnapshots(transactions, limit: 4);
    if (snapshots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SectionCard(
        title: 'Closed months',
        icon: Icons.fact_check_outlined,
        child: Column(
          children: snapshots.map((snapshot) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          snapshot.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(formatMoney(snapshot.savings, signed: true)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Income ${formatMoney(snapshot.income)} - Expense ${formatMoney(snapshot.expense)} - Top ${snapshot.topCategory}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SpendingHeatmapSection extends StatelessWidget {
  const _SpendingHeatmapSection({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = DateTime(now.year, now.month).weekday;
    final dailyTotals = <int, double>{};
    for (final transaction in transactions) {
      if (transaction.type != WalletTransactionType.expense ||
          !isSameMonth(transaction.date, now)) {
        continue;
      }
      dailyTotals.update(
        transaction.date.day,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final maxSpend = dailyTotals.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final cells = <Widget>[
      for (var index = 1; index < firstWeekday; index++)
        const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _HeatmapDay(
          day: day,
          amount: dailyTotals[day] ?? 0,
          maxAmount: maxSpend,
        ),
    ];

    return SectionCard(
      title: 'Spending calendar',
      icon: Icons.calendar_view_month_outlined,
      child: dailyTotals.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No daily spending yet',
            )
          : GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: cells,
            ),
    );
  }
}

class _HeatmapDay extends StatelessWidget {
  const _HeatmapDay({
    required this.day,
    required this.amount,
    required this.maxAmount,
  });

  final int day;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = maxAmount == 0
        ? 0.0
        : (amount / maxAmount).clamp(0.0, 1.0);
    final color = amount == 0
        ? scheme.surfaceContainerHighest
        : Color.lerp(
            scheme.secondaryContainer,
            scheme.error,
            0.18 + intensity * 0.45,
          )!;

    return Tooltip(
      message: amount == 0 ? 'No spending' : formatMoney(amount),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '$day',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: amount == 0 ? scheme.onSurfaceVariant : scheme.onError,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletBreakdownSection extends StatelessWidget {
  const _WalletBreakdownSection({
    required this.transactions,
    required this.wallets,
    this.error,
  });

  final List<WalletTransaction> transactions;
  final List<WalletAccount> wallets;
  final Object? error;

  static bool shouldShow(List<WalletAccount> wallets) {
    return wallets.where((wallet) => !wallet.isArchived).length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final activeWallets = wallets.where((wallet) => !wallet.isArchived).toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    if (error != null && activeWallets.isEmpty) {
      return SectionCard(
        title: 'Wallet breakdown',
        icon: Icons.account_balance_wallet_outlined,
        child: ErrorState(
          title: 'Wallets unavailable',
          message: friendlyErrorMessage(error!),
        ),
      );
    }

    return SectionCard(
      title: 'Wallet breakdown',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        children: [
          for (final wallet in activeWallets)
            _WalletBreakdownRow(
              name: wallet.name,
              balance: _balanceFor(wallet),
              monthlySpend: _monthlySpendFor(wallet),
            ),
        ],
      ),
    );
  }

  double _balanceFor(WalletAccount wallet) {
    return transactions.fold<double>(
      wallet.openingBalance,
      (balance, transaction) =>
          balance + transaction.impactForWallet(wallet.id),
    );
  }

  double _monthlySpendFor(WalletAccount wallet) {
    final now = DateTime.now();
    return transactions
        .where(
          (transaction) =>
              transaction.walletId == wallet.id &&
              transaction.type == WalletTransactionType.expense &&
              isSameMonth(transaction.date, now),
        )
        .fold<double>(0, (total, transaction) => total + transaction.amount);
  }
}

class _WalletBreakdownRow extends StatelessWidget {
  const _WalletBreakdownRow({
    required this.name,
    required this.balance,
    required this.monthlySpend,
  });

  final String name;
  final double balance;
  final double monthlySpend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(balance)),
              Text(
                '${formatMoney(monthlySpend)} spent',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetSection extends StatelessWidget {
  const _CategoryBudgetSection({
    required this.totals,
    required this.budgets,
    required this.onEdit,
    this.error,
  });

  final List<MapEntry<String, double>> totals;
  final List<CategoryBudget> budgets;
  final Object? error;
  final void Function(String category, CategoryBudget? budget) onEdit;

  @override
  Widget build(BuildContext context) {
    final byCategory = {for (final budget in budgets) budget.category: budget};
    final categories = {
      ...totals.map((entry) => entry.key),
      ...budgets.map((budget) => budget.category),
    }.toList()..sort();

    return SectionCard(
      title: 'Category budgets',
      icon: Icons.track_changes_outlined,
      child: error != null && budgets.isEmpty
          ? ErrorState(
              title: 'Category budgets unavailable',
              message: friendlyErrorMessage(error!),
            )
          : categories.isEmpty
          ? const EmptyState(
              icon: Icons.tune_outlined,
              title: 'No category budgets yet',
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                final spent = totals
                    .where((entry) => entry.key == category)
                    .fold<double>(0, (total, entry) => total + entry.value);
                final budget = byCategory[category];
                final progress = budget?.progressFor(spent) ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 6),
                      Text(
                        budget == null
                            ? '${formatMoney(spent)} spent'
                            : '${formatMoney(spent)} of '
                                  '${formatMoney(budget.monthlyLimit)}',
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit category budget',
                    onPressed: () => onEdit(category, budget),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                );
              },
            ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.previous,
  });

  final String label;
  final double current;
  final double previous;

  @override
  Widget build(BuildContext context) {
    final change = _changeLabel(current, previous);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatMoney(current)),
          const SizedBox(width: 10),
          Chip(label: Text(change)),
        ],
      ),
    );
  }

  String _changeLabel(double current, double previous) {
    if (previous == 0) {
      return current == 0 ? 'No change' : 'New';
    }
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) {
      return 'No change';
    }
    return '${change > 0 ? '+' : ''}$change%';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseRatioBar extends StatelessWidget {
  const _IncomeExpenseRatioBar({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.monthlyIncome + summary.monthlyExpense;
    final incomeShare = total == 0 ? 0.0 : summary.monthlyIncome / total;
    final expenseShare = total == 0 ? 0.0 : summary.monthlyExpense / total;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          children: [
            Expanded(
              flex: (incomeShare * 1000).round().clamp(1, 1000).toInt(),
              child: ColoredBox(
                color: const Color(0xFF1A7F64),
                child: const SizedBox(height: 8),
              ),
            ),
            Expanded(
              flex: (expenseShare * 1000).round().clamp(1, 1000).toInt(),
              child: ColoredBox(
                color: scheme.error,
                child: const SizedBox(height: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final double value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(formatMoney(value)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
      ],
    );
  }
}

class _MonthStats {
  const _MonthStats({required this.income, required this.expense});

  factory _MonthStats.fromTransactions(
    List<WalletTransaction> transactions,
    DateTime month,
  ) {
    var income = 0.0;
    var expense = 0.0;
    for (final transaction in transactions) {
      if (!isSameMonth(transaction.date, month)) {
        continue;
      }
      switch (transaction.type) {
        case WalletTransactionType.expense:
          expense += transaction.amount;
        case WalletTransactionType.income || WalletTransactionType.refund:
          income += transaction.amount;
        case WalletTransactionType.transfer:
          break;
      }
    }
    return _MonthStats(income: income, expense: expense);
  }

  final double income;
  final double expense;

  double get net => income - expense;
}
