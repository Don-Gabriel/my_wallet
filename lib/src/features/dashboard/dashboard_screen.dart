import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/bill_reminder.dart';
import '../../models/budget.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_summary.dart';
import '../../models/wallet_user.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_handling.dart';
import '../../shared/finance_intelligence.dart';
import '../../shared/formatters.dart';
import '../budget/budget_form_sheet.dart';
import '../transactions/transaction_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.syncStatus,
    required this.onAddTransaction,
    required this.onAddPreset,
  });

  final WalletRepository repository;
  final WalletUser user;
  final String syncStatus;
  final VoidCallback onAddTransaction;
  final ValueChanged<TransactionPreset> onAddPreset;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WalletTransaction>>(
      stream: repository.watchTransactions(user),
      builder: (context, transactionSnapshot) {
        final transactions =
            transactionSnapshot.data ?? const <WalletTransaction>[];
        final summary = WalletSummary.fromTransactions(
          transactions,
          DateTime.now(),
        );

        return StreamBuilder<WalletBudget>(
          stream: repository.watchBudget(user),
          builder: (context, budgetSnapshot) {
            final budget =
                budgetSnapshot.data ?? const WalletBudget(monthlyLimit: 0);
            return StreamBuilder<List<String>>(
              stream: repository.watchCategories(user),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? defaultCategories;
                return StreamBuilder<List<BillReminder>>(
                  stream: repository.watchBillReminders(user),
                  builder: (context, billSnapshot) {
                    final bills = billSnapshot.data ?? const <BillReminder>[];
                    return StreamBuilder<List<RecurringTransaction>>(
                      stream: repository.watchRecurringTransactions(user),
                      builder: (context, recurringSnapshot) {
                        final recurring =
                            recurringSnapshot.data ??
                            const <RecurringTransaction>[];
                        return StreamBuilder<List<WalletAccount>>(
                          stream: repository.watchWallets(user),
                          builder: (context, walletSnapshot) {
                            final wallets =
                                walletSnapshot.data ??
                                [WalletAccount.defaultAccount()];
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                96,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 980,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _BalanceHero(
                                        user: user,
                                        syncStatus: syncStatus,
                                        summary: summary,
                                      ),
                                      const SizedBox(height: 12),
                                      _QuickAddPanel(
                                        categories: categories,
                                        onSelect: onAddPreset,
                                      ),
                                      const SizedBox(height: 12),
                                      _MonthlySummaryPanel(summary: summary),
                                      const SizedBox(height: 12),
                                      _WalletBalancePanel(
                                        wallets: wallets,
                                        transactions: transactions,
                                      ),
                                      const SizedBox(height: 12),
                                      _MetricsGrid(
                                        summary: summary,
                                        budget: budget,
                                      ),
                                      const SizedBox(height: 12),
                                      _TrendPanel(transactions: transactions),
                                      const SizedBox(height: 12),
                                      _BudgetPanel(
                                        budget: budget,
                                        spent: summary.monthlyExpense,
                                        transactions: transactions,
                                        onEdit: () =>
                                            _openBudgetSheet(context, budget),
                                      ),
                                      const SizedBox(height: 12),
                                      _UpcomingBillsPanel(
                                        bills: bills,
                                        isLoading:
                                            billSnapshot.connectionState ==
                                                ConnectionState.waiting &&
                                            bills.isEmpty,
                                        error: billSnapshot.error,
                                      ),
                                      const SizedBox(height: 12),
                                      _RecurringSuggestionsPanel(
                                        transactions: transactions,
                                        recurring: recurring,
                                        onCreate: (suggestion) =>
                                            _createRecurring(
                                              context,
                                              suggestion,
                                            ),
                                      ),
                                      _SubscriptionsPanel(
                                        transactions: transactions,
                                      ),
                                      const SizedBox(height: 12),
                                      _InsightPanel(
                                        summary: summary,
                                        budget: budget,
                                        transactions: transactions,
                                        bills: bills,
                                      ),
                                      const SizedBox(height: 12),
                                      _RecentTransactions(
                                        transactions: transactions,
                                        isLoading:
                                            transactionSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting &&
                                            transactions.isEmpty,
                                        error: transactionSnapshot.error,
                                        onAddTransaction: onAddTransaction,
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
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openBudgetSheet(
    BuildContext context,
    WalletBudget currentBudget,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BudgetFormSheet(
        currentBudget: currentBudget,
        onSave: (amount) => repository.setMonthlyBudget(user, amount),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Monthly budget updated')));
    }
  }

  Future<void> _createRecurring(
    BuildContext context,
    _RecurringSuggestion suggestion,
  ) async {
    try {
      await repository.addRecurringTransaction(
        user,
        RecurringTransactionDraft(
          title: suggestion.title,
          amount: suggestion.amount,
          category: suggestion.category,
          type: suggestion.type,
          interval: RecurringInterval.monthly,
          nextDate: DateTime.now().add(const Duration(days: 30)),
          walletId: suggestion.walletId,
          notes: 'Suggested from repeated transactions',
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recurring item created')));
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.user,
    required this.syncStatus,
    required this.summary,
  });

  final WalletUser user;
  final String syncStatus;
  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSynced = syncStatus.startsWith('Synced');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSynced
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSynced ? syncStatus : 'Sync pending',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Net balance',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(summary.currentBalance),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Income',
                    value: formatMoney(summary.monthlyIncome),
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeroStat(
                    label: 'Expense',
                    value: formatMoney(summary.monthlyExpense),
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddPanel extends StatelessWidget {
  const _QuickAddPanel({required this.categories, required this.onSelect});

  final List<String> categories;
  final ValueChanged<TransactionPreset> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = categories.toSet();
    final templates = [
      for (final category in ['Food', 'Transport', 'Bills', 'Shopping'])
        if (active.contains(category))
          TransactionPreset(
            category: category,
            type: WalletTransactionType.expense,
            notes: category,
          ),
      if (active.contains('Salary'))
        const TransactionPreset(
          category: 'Salary',
          type: WalletTransactionType.income,
          notes: 'Salary',
        ),
    ];
    final effectiveTemplates = templates.isNotEmpty
        ? templates
        : categories
              .take(4)
              .map(
                (category) => TransactionPreset(
                  category: category,
                  type: category == 'Salary'
                      ? WalletTransactionType.income
                      : WalletTransactionType.expense,
                  notes: category,
                ),
              )
              .toList();

    if (effectiveTemplates.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Quick add',
      icon: Icons.flash_on_outlined,
      compact: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: effectiveTemplates.map((template) {
          return ActionChip(
            avatar: Icon(template.type.icon, size: 18),
            label: Text(template.category),
            onPressed: () => onSelect(template),
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlySummaryPanel extends StatelessWidget {
  const _MonthlySummaryPanel({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final savings = summary.monthlyIncome - summary.monthlyExpense;
    return SectionCard(
      title: 'Monthly summary',
      icon: Icons.summarize_outlined,
      child: Column(
        children: [
          _SummaryLine(
            label: 'Income',
            value: formatMoney(summary.monthlyIncome),
          ),
          _SummaryLine(
            label: 'Expense',
            value: formatMoney(summary.monthlyExpense),
          ),
          _SummaryLine(
            label: 'Savings',
            value: formatMoney(savings, signed: true),
          ),
          _SummaryLine(label: 'Top category', value: summary.topCategory),
        ],
      ),
    );
  }
}

class _WalletBalancePanel extends StatelessWidget {
  const _WalletBalancePanel({
    required this.wallets,
    required this.transactions,
  });

  final List<WalletAccount> wallets;
  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final visible = wallets
        .where((wallet) => wallet.showOnDashboard && !wallet.isArchived)
        .toList();
    if (visible.length <= 1) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Wallet balances',
      icon: Icons.account_balance_wallet_outlined,
      compact: true,
      child: Column(
        children: visible.take(4).map((wallet) {
          final balance =
              wallet.openingBalance +
              transactions.fold<double>(
                0,
                (total, transaction) =>
                    total + transaction.impactForWallet(wallet.id),
              );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatMoney(balance),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary, required this.budget});

  final WalletSummary summary;
  final WalletBudget budget;

  @override
  Widget build(BuildContext context) {
    final budgetValue = budget.hasBudget
        ? '${(budget.progressFor(summary.monthlyExpense) * 100).round()}%'
        : 'Unset';
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final remainingDays = (daysInMonth - now.day + 1).clamp(1, 31).toInt();
    final remainingBudget = (budget.monthlyLimit - summary.monthlyExpense)
        .clamp(0.0, double.infinity)
        .toDouble();
    final safeToday = budget.hasBudget ? remainingBudget / remainingDays : null;
    final stats = [
      _MetricData(
        label: 'Monthly expense',
        value: formatMoney(summary.monthlyExpense),
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFC84B31),
      ),
      _MetricData(
        label: 'Budget used',
        value: budgetValue,
        icon: Icons.pie_chart_outline,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      if (safeToday != null)
        _MetricData(
          label: 'Safe today',
          value: formatMoney(safeToday),
          icon: Icons.shield_outlined,
          color: Theme.of(context).colorScheme.secondary,
        ),
      _MetricData(
        label: 'Today spent',
        value: formatMoney(summary.todaySpend),
        icon: Icons.today_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      _MetricData(
        label: 'Savings rate',
        value: '${(summary.savingsRate * 100).round()}%',
        icon: Icons.savings_outlined,
        color: const Color(0xFF00A88A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 860
            ? 3
            : constraints.maxWidth > 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 4.3 : 2.8,
          ),
          itemBuilder: (context, index) => _MetricCard(data: stats[index]),
        );
      },
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final points = _lastSevenDays();
    final values = points.map((day) {
      return transactions
          .where(
            (transaction) =>
                transaction.type == WalletTransactionType.expense &&
                transaction.date.year == day.year &&
                transaction.date.month == day.month &&
                transaction.date.day == day.day,
          )
          .fold<double>(0, (total, transaction) => total + transaction.amount);
    }).toList();
    final maxValue = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    if (maxValue == 0) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: '7-day spending',
      icon: Icons.show_chart_outlined,
      child: SizedBox(
        height: 132,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < points.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _TrendBar(
                    label: points[index].day.toString(),
                    value: values[index],
                    maxValue: maxValue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _lastSevenDays() {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = maxValue == 0 ? 0.08 : (value / maxValue).clamp(0.08, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fill,
              widthFactor: 0.68,
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: value == 0
                      ? scheme.surfaceContainerHighest
                      : scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(data.icon, color: data.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel({
    required this.budget,
    required this.spent,
    required this.transactions,
    required this.onEdit,
  });

  final WalletBudget budget;
  final double spent;
  final List<WalletTransaction> transactions;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final suggested = suggestedMonthlyBudget(transactions);
    return SectionCard(
      title: 'Monthly budget',
      icon: Icons.track_changes_outlined,
      action: IconButton(
        tooltip: 'Edit budget',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: budget.progressFor(spent)),
          const SizedBox(height: 10),
          Text(
            budget.hasBudget
                ? '${formatMoney(spent)} of ${formatMoney(budget.monthlyLimit)} used'
                : 'Set a monthly budget to track progress',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (budget.hasBudget) ...[
            const SizedBox(height: 8),
            Text(
              safeToSpendLabel(budget, spent),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (suggested != null) ...[
            const SizedBox(height: 8),
            Text(
              'Suggested starter budget: ${formatMoney(suggested)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingBillsPanel extends StatelessWidget {
  const _UpcomingBillsPanel({
    required this.bills,
    required this.isLoading,
    this.error,
  });

  final List<BillReminder> bills;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final upcoming = bills.where((bill) => !bill.isPaid).take(3).toList();
    return SectionCard(
      title: 'Upcoming bills',
      icon: Icons.event_note_outlined,
      child: isLoading
          ? const LoadingSkeletonList()
          : error != null
          ? ErrorState(
              title: 'Bills unavailable',
              message: friendlyErrorMessage(error!),
            )
          : upcoming.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming bills',
            )
          : Column(
              children: upcoming.map((bill) {
                final days = bill.daysUntil(DateTime.now());
                final status = days < 0
                    ? 'Overdue'
                    : days == 0
                    ? 'Due today'
                    : 'Due in $days days';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(formatMoney(bill.amount)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _RecurringSuggestionsPanel extends StatelessWidget {
  const _RecurringSuggestionsPanel({
    required this.transactions,
    required this.recurring,
    required this.onCreate,
  });

  final List<WalletTransaction> transactions;
  final List<RecurringTransaction> recurring;
  final ValueChanged<_RecurringSuggestion> onCreate;

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions().take(2).toList();
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Suggested recurring',
      icon: Icons.repeat_on_outlined,
      child: Column(
        children: suggestions.map((suggestion) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(suggestion.title),
            subtitle: Text(
              '${suggestion.category} - ${formatMoney(suggestion.amount)}',
            ),
            trailing: TextButton(
              onPressed: () => onCreate(suggestion),
              child: const Text('Add'),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_RecurringSuggestion> _suggestions() {
    final existing = recurring
        .map((item) => _suggestionKey(item.category, item.title, item.type))
        .toSet();
    final grouped = <String, List<WalletTransaction>>{};

    for (final transaction in transactions) {
      if (transaction.type == WalletTransactionType.transfer ||
          transaction.notes.trim().isEmpty) {
        continue;
      }
      final key = _suggestionKey(
        transaction.category,
        transaction.notes,
        transaction.type,
      );
      grouped.putIfAbsent(key, () => []).add(transaction);
    }

    final suggestions = <_RecurringSuggestion>[];
    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.length < 2 || existing.contains(entry.key)) {
        continue;
      }
      items.sort((left, right) => right.date.compareTo(left.date));
      final latest = items.first;
      final average =
          items.fold<double>(0, (total, item) => total + item.amount) /
          items.length;
      suggestions.add(
        _RecurringSuggestion(
          title: latest.notes,
          category: latest.category,
          amount: average,
          type: latest.type,
          walletId: latest.walletId,
          count: items.length,
        ),
      );
    }

    suggestions.sort((left, right) => right.count.compareTo(left.count));
    return suggestions;
  }

  String _suggestionKey(
    String category,
    String notes,
    WalletTransactionType type,
  ) {
    return '${type.name}|${category.trim().toLowerCase()}|${notes.trim().toLowerCase()}';
  }
}

class _RecurringSuggestion {
  const _RecurringSuggestion({
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.walletId,
    required this.count,
  });

  final String title;
  final String category;
  final double amount;
  final WalletTransactionType type;
  final String walletId;
  final int count;
}

class _SubscriptionsPanel extends StatelessWidget {
  const _SubscriptionsPanel({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final subscriptions = detectSubscriptions(transactions).take(3).toList();
    if (subscriptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        title: 'Subscription watch',
        icon: Icons.subscriptions_outlined,
        compact: true,
        child: Column(
          children: subscriptions.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatMoney(item.amount)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.summary,
    required this.budget,
    required this.transactions,
    required this.bills,
  });

  final WalletSummary summary;
  final WalletBudget budget;
  final List<WalletTransaction> transactions;
  final List<BillReminder> bills;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final budgetProgress = budget.progressFor(summary.monthlyExpense);
    final insights = <String>[
      if (summary.topCategory != 'None yet')
        'Top category this month: ${summary.topCategory}.',
      if (summary.todaySpend > 0)
        'Today you spent ${formatMoney(summary.todaySpend)}.',
      ..._monthComparisonInsight(now),
      ..._weekendInsight(now),
      ..._categorySavingsInsight(now),
      ..._subscriptionInsight(),
      ..._biggestDayInsight(now),
      ..._unusualExpenseInsight(now),
      ..._savingsStreakInsight(now),
      if (bills.any((bill) => !bill.isPaid && bill.daysUntil(now) < 0))
        'You have overdue bills to review.',
      if (summary.currentBalance < summary.monthlyExpense / 2 &&
          summary.monthlyExpense > 0)
        'Cash-flow warning: your balance is low compared with current spending.',
      if (budget.hasBudget && budgetProgress >= 1)
        'Budget alert: you have reached 100% of your monthly budget.'
      else if (budget.hasBudget && budgetProgress >= 0.9)
        'Budget alert: you have used 90% of your monthly budget.'
      else if (budget.hasBudget && budgetProgress >= 0.75)
        'Budget alert: you have used 75% of your monthly budget.'
      else if (budget.hasBudget && budgetProgress >= 0.5)
        'Budget alert: you have used 50% of your monthly budget.',
      if (summary.monthlyIncome > 0 && summary.savingsRate >= 0.2)
        'Savings rate is looking healthy this month.',
    ];

    return SectionCard(
      title: 'Insight feed',
      icon: Icons.auto_awesome_outlined,
      child: insights.isEmpty
          ? const EmptyState(
              icon: Icons.lightbulb_outline,
              title: 'Add more activity to unlock insights',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights
                  .map(
                    (insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(insight)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  List<String> _monthComparisonInsight(DateTime now) {
    final previousMonth = DateTime(now.year, now.month - 1);
    final previousExpense = transactions
        .where(
          (transaction) =>
              transaction.type == WalletTransactionType.expense &&
              isSameMonth(transaction.date, previousMonth),
        )
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    if (previousExpense <= 0 || summary.monthlyExpense <= 0) {
      return const [];
    }
    final change =
        ((summary.monthlyExpense - previousExpense) / previousExpense * 100)
            .round();
    if (change.abs() < 10) {
      return const [];
    }
    return [
      'Monthly spending is ${change > 0 ? 'up' : 'down'} ${change.abs()}% versus last month.',
    ];
  }

  List<String> _weekendInsight(DateTime now) {
    var weekendSpend = 0.0;
    var weekdaySpend = 0.0;
    for (final transaction in transactions) {
      if (transaction.type != WalletTransactionType.expense ||
          !isSameMonth(transaction.date, now)) {
        continue;
      }
      final isWeekend =
          transaction.date.weekday == DateTime.saturday ||
          transaction.date.weekday == DateTime.sunday;
      if (isWeekend) {
        weekendSpend += transaction.amount;
      } else {
        weekdaySpend += transaction.amount;
      }
    }
    if (weekendSpend > 0 && weekendSpend > weekdaySpend) {
      return const ['Most of your spending this month happened on weekends.'];
    }
    return const [];
  }

  List<String> _categorySavingsInsight(DateTime now) {
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
    if (totals.isEmpty) {
      return const [];
    }
    final top = totals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final saving = top.first.value * 0.1;
    if (saving <= 0) {
      return const [];
    }
    return [
      'Reducing ${top.first.key} by 10% can save ${formatMoney(saving)} this month.',
    ];
  }

  List<String> _biggestDayInsight(DateTime now) {
    final byDay = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type != WalletTransactionType.expense ||
          !isSameMonth(transaction.date, now)) {
        continue;
      }
      final key = formatDate(transaction.date);
      byDay.update(
        key,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    if (byDay.length < 2) {
      return const [];
    }
    final top = byDay.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return ['Biggest spending day: ${top.first.key}.'];
  }

  List<String> _subscriptionInsight() {
    final subscriptions = detectSubscriptions(transactions);
    if (subscriptions.isEmpty) {
      return const [];
    }
    return [
      'Subscription-like spending detected: ${subscriptions.first.title}.',
    ];
  }

  List<String> _unusualExpenseInsight(DateTime now) {
    final expenses = transactions
        .where(
          (transaction) =>
              transaction.type == WalletTransactionType.expense &&
              isSameMonth(transaction.date, now),
        )
        .toList();
    if (expenses.length < 4) {
      return const [];
    }
    final average =
        expenses.fold<double>(0, (total, item) => total + item.amount) /
        expenses.length;
    final unusual = expenses.where((item) => item.amount > average * 2).toList()
      ..sort((left, right) => right.amount.compareTo(left.amount));
    if (unusual.isEmpty) {
      return const [];
    }
    return ['Unusual expense spotted: ${formatMoney(unusual.first.amount)}.'];
  }

  List<String> _savingsStreakInsight(DateTime now) {
    var positiveMonths = 0;
    for (var offset = 0; offset < 3; offset++) {
      final month = DateTime(now.year, now.month - offset);
      var income = 0.0;
      var expense = 0.0;
      for (final transaction in transactions) {
        if (!isSameMonth(transaction.date, month)) {
          continue;
        }
        if (transaction.type == WalletTransactionType.expense) {
          expense += transaction.amount;
        } else if (transaction.type == WalletTransactionType.income ||
            transaction.type == WalletTransactionType.refund) {
          income += transaction.amount;
        }
      }
      if (income > 0 && income >= expense) {
        positiveMonths++;
      }
    }
    if (positiveMonths >= 2) {
      return [
        'Savings streak: $positiveMonths months with positive cash flow.',
      ];
    }
    return const [];
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.transactions,
    required this.isLoading,
    required this.onAddTransaction,
    this.error,
  });

  final List<WalletTransaction> transactions;
  final bool isLoading;
  final Object? error;
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent transactions',
      icon: Icons.history,
      action: IconButton(
        tooltip: 'Add transaction',
        onPressed: onAddTransaction,
        icon: const Icon(Icons.add),
      ),
      child: isLoading
          ? const LoadingSkeletonList()
          : error != null
          ? ErrorState(
              title: 'Transactions unavailable',
              message: friendlyErrorMessage(error!),
            )
          : transactions.isEmpty
          ? EmptyState(
              icon: Icons.post_add_outlined,
              title: 'No transactions yet',
              action: FilledButton.icon(
                onPressed: onAddTransaction,
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.take(8).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return TransactionTile(transaction: transactions[index]);
              },
            ),
    );
  }
}
