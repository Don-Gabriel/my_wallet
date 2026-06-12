import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/bill_reminder.dart';
import '../../models/recurring_transaction.dart';
import '../../models/savings_goal.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_user.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';
import 'bill_form_sheet.dart';
import 'goal_form_sheet.dart';
import 'recurring_form_sheet.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.repository, required this.user});

  final WalletRepository repository;
  final WalletUser user;

  Future<void> _openGoalSheet(BuildContext context, {SavingsGoal? goal}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => GoalFormSheet(
        goal: goal,
        onSave: (draft) {
          if (goal == null) {
            return repository.addGoal(user, draft);
          }
          return repository.updateGoal(user, goal, draft);
        },
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(goal == null ? 'Goal saved' : 'Goal updated')),
      );
    }
  }

  Future<void> _openBillSheet(
    BuildContext context, {
    BillReminder? reminder,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StreamBuilder<List<String>>(
          stream: repository.watchCategories(user),
          builder: (context, snapshot) {
            return BillFormSheet(
              categories: snapshot.data ?? defaultCategories,
              reminder: reminder,
              onSave: (draft) {
                if (reminder == null) {
                  return repository.addBillReminder(user, draft);
                }
                return repository.updateBillReminder(user, reminder, draft);
              },
            );
          },
        );
      },
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reminder == null ? 'Bill saved' : 'Bill updated'),
        ),
      );
    }
  }

  Future<void> _openRecurringSheet(
    BuildContext context, {
    RecurringTransaction? recurring,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StreamBuilder<List<String>>(
          stream: repository.watchCategories(user),
          builder: (context, categorySnapshot) {
            return StreamBuilder<List<WalletAccount>>(
              stream: repository.watchWallets(user),
              builder: (context, walletSnapshot) {
                return RecurringFormSheet(
                  categories: categorySnapshot.data ?? defaultCategories,
                  wallets:
                      walletSnapshot.data ?? [WalletAccount.defaultAccount()],
                  recurring: recurring,
                  onSave: (draft) {
                    if (recurring == null) {
                      return repository.addRecurringTransaction(user, draft);
                    }
                    return repository.updateRecurringTransaction(
                      user,
                      recurring,
                      draft,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recurring == null
                ? 'Recurring item saved'
                : 'Recurring item updated',
          ),
        ),
      );
    }
  }

  Future<void> _deleteGoal(BuildContext context, SavingsGoal goal) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete goal?',
      message: 'This removes the savings goal permanently.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await repository.deleteGoal(user, goal);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _deleteBill(BuildContext context, BillReminder reminder) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete bill?',
      message: 'This removes the reminder permanently.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await repository.deleteBillReminder(user, reminder);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bill deleted')));
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _deleteRecurring(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete recurring item?',
      message: 'This removes the recurring setup permanently.',
    );
    if (!confirmed) {
      return;
    }
    try {
      await repository.deleteRecurringTransaction(user, recurring);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recurring item deleted')));
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _postRecurring(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    if (recurring.isPaused) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume this item before posting it')),
      );
      return;
    }

    try {
      await repository.addTransaction(
        user,
        TransactionDraft(
          amount: recurring.amount,
          category: recurring.category,
          type: recurring.type,
          date: DateTime.now(),
          walletId: recurring.walletId,
          notes: recurring.title,
        ),
      );
      await repository.updateRecurringTransaction(
        user,
        recurring,
        RecurringTransactionDraft(
          title: recurring.title,
          amount: recurring.amount,
          category: recurring.category,
          type: recurring.type,
          interval: recurring.interval,
          nextDate: _nextRecurringDate(recurring),
          walletId: recurring.walletId,
          notes: recurring.notes,
          isPaused: recurring.isPaused,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring transaction posted')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _skipRecurring(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    try {
      await repository.updateRecurringTransaction(
        user,
        recurring,
        RecurringTransactionDraft(
          title: recurring.title,
          amount: recurring.amount,
          category: recurring.category,
          type: recurring.type,
          interval: recurring.interval,
          nextDate: _nextRecurringDate(recurring),
          walletId: recurring.walletId,
          notes: recurring.notes,
          isPaused: recurring.isPaused,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Skipped once')));
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _toggleRecurringPause(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    final shouldPause = !recurring.isPaused;
    try {
      await repository.updateRecurringTransaction(
        user,
        recurring,
        RecurringTransactionDraft(
          title: recurring.title,
          amount: recurring.amount,
          category: recurring.category,
          type: recurring.type,
          interval: recurring.interval,
          nextDate: recurring.nextDate,
          walletId: recurring.walletId,
          notes: recurring.notes,
          isPaused: shouldPause,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldPause ? 'Recurring item paused' : 'Recurring item resumed',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  DateTime _nextRecurringDate(RecurringTransaction recurring) {
    if (recurring.interval == RecurringInterval.weekly) {
      return recurring.nextDate.add(const Duration(days: 7));
    }

    final nextMonth = recurring.nextDate.month == 12
        ? 1
        : recurring.nextDate.month + 1;
    final nextYear = recurring.nextDate.month == 12
        ? recurring.nextDate.year + 1
        : recurring.nextDate.year;
    final lastDay = DateUtils.getDaysInMonth(nextYear, nextMonth);
    final nextDay = recurring.nextDate.day.clamp(1, lastDay).toInt();
    return DateTime(nextYear, nextMonth, nextDay);
  }

  Future<void> _toggleBill(
    BuildContext context,
    BillReminder reminder,
    bool isPaid,
  ) async {
    try {
      await repository.setBillPaid(user, reminder, isPaid);
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _postBill(BuildContext context, BillReminder reminder) async {
    try {
      await repository.addTransaction(
        user,
        TransactionDraft(
          amount: reminder.amount,
          category: reminder.category,
          type: WalletTransactionType.expense,
          date: DateTime.now(),
          walletId: defaultWalletId,
          notes: reminder.name,
          paymentMethod: 'Bills',
        ),
      );
      await repository.setBillPaid(user, reminder, true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill posted as transaction')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsGoal>>(
      stream: repository.watchGoals(user),
      builder: (context, goalSnapshot) {
        return StreamBuilder<List<BillReminder>>(
          stream: repository.watchBillReminders(user),
          builder: (context, billSnapshot) {
            return StreamBuilder<List<RecurringTransaction>>(
              stream: repository.watchRecurringTransactions(user),
              builder: (context, recurringSnapshot) {
                final goals = goalSnapshot.data ?? const <SavingsGoal>[];
                final bills = billSnapshot.data ?? const <BillReminder>[];
                final recurring =
                    recurringSnapshot.data ?? const <RecurringTransaction>[];

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GoalsSection(
                            goals: goals,
                            isLoading:
                                goalSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                goals.isEmpty,
                            error: goalSnapshot.error,
                            onAdd: () => _openGoalSheet(context),
                            onEdit: (goal) =>
                                _openGoalSheet(context, goal: goal),
                            onDelete: (goal) => _deleteGoal(context, goal),
                          ),
                          const SizedBox(height: 16),
                          _BillsSection(
                            bills: bills,
                            isLoading:
                                billSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                bills.isEmpty,
                            error: billSnapshot.error,
                            onAdd: () => _openBillSheet(context),
                            onEdit: (reminder) =>
                                _openBillSheet(context, reminder: reminder),
                            onDelete: (reminder) =>
                                _deleteBill(context, reminder),
                            onPost: (reminder) => _postBill(context, reminder),
                            onPaidChanged: (reminder, value) =>
                                _toggleBill(context, reminder, value),
                          ),
                          const SizedBox(height: 16),
                          _RecurringSection(
                            recurring: recurring,
                            isLoading:
                                recurringSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                recurring.isEmpty,
                            error: recurringSnapshot.error,
                            onAdd: () => _openRecurringSheet(context),
                            onEdit: (item) =>
                                _openRecurringSheet(context, recurring: item),
                            onPost: (item) => _postRecurring(context, item),
                            onSkip: (item) => _skipRecurring(context, item),
                            onPauseToggle: (item) =>
                                _toggleRecurringPause(context, item),
                            onDelete: (item) => _deleteRecurring(context, item),
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
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.goals,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.error,
  });

  final List<SavingsGoal> goals;
  final bool isLoading;
  final Object? error;
  final VoidCallback onAdd;
  final ValueChanged<SavingsGoal> onEdit;
  final ValueChanged<SavingsGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Savings goals',
      icon: Icons.savings_outlined,
      action: IconButton(
        tooltip: 'Add goal',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
      ),
      child: isLoading
          ? const LoadingSkeletonList()
          : error != null
          ? ErrorState(
              title: 'Goals unavailable',
              message: friendlyErrorMessage(error!),
            )
          : goals.isEmpty
          ? EmptyState(
              icon: Icons.flag_outlined,
              title: 'No savings goals yet',
              subtitle: 'Create goals for emergency funds, travel, or gadgets.',
              action: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add goal'),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final goal = goals[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(goal.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: goal.progress),
                      const SizedBox(height: 6),
                      Text(
                        '${formatMoney(goal.currentAmount)} of '
                        '${formatMoney(goal.targetAmount)} by '
                        '${formatDate(goal.deadline)}',
                      ),
                    ],
                  ),
                  trailing: _RowActions(
                    onEdit: () => onEdit(goal),
                    onDelete: () => onDelete(goal),
                  ),
                );
              },
            ),
    );
  }
}

class _BillsSection extends StatelessWidget {
  const _BillsSection({
    required this.bills,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onPost,
    required this.onPaidChanged,
    this.error,
  });

  final List<BillReminder> bills;
  final bool isLoading;
  final Object? error;
  final VoidCallback onAdd;
  final ValueChanged<BillReminder> onEdit;
  final ValueChanged<BillReminder> onDelete;
  final ValueChanged<BillReminder> onPost;
  final void Function(BillReminder reminder, bool isPaid) onPaidChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Upcoming bills',
      icon: Icons.event_note_outlined,
      action: IconButton(
        tooltip: 'Add bill',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
      ),
      child: isLoading
          ? const LoadingSkeletonList()
          : error != null
          ? ErrorState(
              title: 'Bills unavailable',
              message: friendlyErrorMessage(error!),
            )
          : bills.isEmpty
          ? EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming bills',
              action: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add bill'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BillCalendarStrip(bills: bills),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bills.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reminder = bills[index];
                    final status = _billStatus(reminder, DateTime.now());
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reminder.isPaid,
                      onChanged: (value) =>
                          onPaidChanged(reminder, value ?? false),
                      title: Text(reminder.name),
                      subtitle: Text(
                        '$status - ${formatMoney(reminder.amount)} - '
                        '${reminder.category}',
                      ),
                      secondary: _RowActions(
                        onPost: reminder.isPaid ? null : () => onPost(reminder),
                        onEdit: () => onEdit(reminder),
                        onDelete: () => onDelete(reminder),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  String _billStatus(BillReminder reminder, DateTime now) {
    if (reminder.isPaid) {
      return 'Paid';
    }
    final days = reminder.daysUntil(now);
    if (days < 0) {
      return 'Overdue';
    }
    if (days == 0) {
      return 'Due today';
    }
    return 'Due in $days days';
  }
}

class _BillCalendarStrip extends StatelessWidget {
  const _BillCalendarStrip({required this.bills});

  final List<BillReminder> bills;

  @override
  Widget build(BuildContext context) {
    final active = bills.where((bill) => !bill.isPaid).toList()
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    if (active.isEmpty) {
      return Text(
        'All bills are marked paid.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: active.take(7).map((bill) {
          final days = bill.daysUntil(DateTime.now());
          final isUrgent = days <= 1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Icon(
                isUrgent
                    ? Icons.priority_high_outlined
                    : Icons.event_available_outlined,
                size: 18,
              ),
              label: Text('${bill.dueDate.day}: ${bill.name}'),
              backgroundColor: isUrgent
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecurringSection extends StatelessWidget {
  const _RecurringSection({
    required this.recurring,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onPost,
    required this.onSkip,
    required this.onPauseToggle,
    required this.onDelete,
    this.error,
  });

  final List<RecurringTransaction> recurring;
  final bool isLoading;
  final Object? error;
  final VoidCallback onAdd;
  final ValueChanged<RecurringTransaction> onEdit;
  final ValueChanged<RecurringTransaction> onPost;
  final ValueChanged<RecurringTransaction> onSkip;
  final ValueChanged<RecurringTransaction> onPauseToggle;
  final ValueChanged<RecurringTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recurring items',
      icon: Icons.repeat_outlined,
      action: IconButton(
        tooltip: 'Add recurring item',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
      ),
      child: isLoading
          ? const LoadingSkeletonList()
          : error != null
          ? ErrorState(
              title: 'Recurring items unavailable',
              message: friendlyErrorMessage(error!),
            )
          : recurring.isEmpty
          ? EmptyState(
              icon: Icons.repeat_on_outlined,
              title: 'No recurring items',
              subtitle: 'Track rent, subscriptions, salary, or retainers.',
              action: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add recurring'),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recurring.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = recurring[index];
                final amount = item.type == WalletTransactionType.expense
                    ? -item.amount
                    : item.amount;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(item.type.icon, size: 20)),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.isPaused ? 'Paused - ' : ''}'
                    '${item.interval.label} ${item.type.label.toLowerCase()} '
                    '- next ${formatDate(item.nextDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 116),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(formatMoney(amount, signed: true)),
                        ),
                      ),
                      _RowActions(
                        onPost: item.isPaused ? null : () => onPost(item),
                        onSkip: () => onSkip(item),
                        onPauseToggle: () => onPauseToggle(item),
                        pauseLabel: item.isPaused ? 'Resume' : 'Pause',
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.onEdit,
    required this.onDelete,
    this.onPost,
    this.onSkip,
    this.onPauseToggle,
    this.pauseLabel = 'Pause',
  });

  final VoidCallback? onPost;
  final VoidCallback? onSkip;
  final VoidCallback? onPauseToggle;
  final String pauseLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) {
        if (value == 'post') {
          onPost?.call();
        }
        if (value == 'skip') {
          onSkip?.call();
        }
        if (value == 'pause') {
          onPauseToggle?.call();
        }
        if (value == 'edit') {
          onEdit();
        }
        if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        if (onPost != null)
          const PopupMenuItem(value: 'post', child: Text('Post now')),
        if (onSkip != null)
          const PopupMenuItem(value: 'skip', child: Text('Skip once')),
        if (onPauseToggle != null)
          PopupMenuItem(value: 'pause', child: Text(pauseLabel)),
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
