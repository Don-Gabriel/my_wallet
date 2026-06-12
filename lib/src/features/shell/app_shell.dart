import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_user.dart';
import '../../shared/error_handling.dart';
import '../dashboard/dashboard_screen.dart';
import '../goals/goals_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_form_sheet.dart';
import '../transactions/transactions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final WalletRepository repository;
  final WalletUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  var _syncStatus = 'Checking cloud profile';
  StreamSubscription<List<WalletTransaction>>? _transactionSubscription;
  List<WalletTransaction> _latestTransactions = const [];

  @override
  void initState() {
    super.initState();
    _transactionSubscription = widget.repository
        .watchTransactions(widget.user)
        .listen((transactions) => _latestTransactions = transactions);
    _syncProfile();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncProfile() async {
    try {
      await widget.repository.syncUserProfile(widget.user);
      if (mounted) {
        final now = DateTime.now();
        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');
        final time = '$hour:$minute';
        setState(() => _syncStatus = 'Synced $time');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _syncStatus = 'Sync pending');
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openTransactionSheet({
    WalletTransaction? transaction,
    TransactionPreset? preset,
  }) async {
    final savedDraft = await showModalBottomSheet<TransactionDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StreamBuilder<List<String>>(
          stream: widget.repository.watchCategories(widget.user),
          builder: (context, categorySnapshot) {
            return StreamBuilder<List<WalletAccount>>(
              stream: widget.repository.watchWallets(widget.user),
              builder: (context, walletSnapshot) {
                return StreamBuilder<List<WalletTransaction>>(
                  stream: widget.repository.watchTransactions(widget.user),
                  builder: (context, transactionSnapshot) {
                    return TransactionFormSheet(
                      categories: categorySnapshot.data ?? defaultCategories,
                      recentCategories: _recentCategories(
                        transactionSnapshot.data ?? const <WalletTransaction>[],
                      ),
                      existingTransactions:
                          transactionSnapshot.data ??
                          const <WalletTransaction>[],
                      wallets:
                          walletSnapshot.data ??
                          [WalletAccount.defaultAccount()],
                      transaction: transaction,
                      initialPreset: preset,
                      onSave: (draft) {
                        if (transaction == null) {
                          return widget.repository.addTransaction(
                            widget.user,
                            draft,
                          );
                        }
                        return widget.repository.updateTransaction(
                          widget.user,
                          transaction,
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
      },
    );

    if (savedDraft != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transaction == null ? 'Transaction saved' : 'Transaction updated',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => transaction == null
                ? _undoAddedTransaction(savedDraft)
                : _undoEditedTransaction(transaction),
          ),
        ),
      );
    }
  }

  Future<void> _undoAddedTransaction(TransactionDraft draft) async {
    final match = _latestTransactions.where((transaction) {
      final sameDay =
          transaction.date.year == draft.date.year &&
          transaction.date.month == draft.date.month &&
          transaction.date.day == draft.date.day;
      return sameDay &&
          transaction.type == draft.type &&
          transaction.category == draft.category &&
          transaction.walletId == draft.walletId &&
          (transaction.amount - draft.amount).abs() < 0.01 &&
          transaction.notes == draft.notes;
    }).toList();
    if (match.isEmpty) {
      return;
    }
    try {
      await widget.repository.deleteTransaction(widget.user, match.first);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction undone')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _undoEditedTransaction(WalletTransaction transaction) async {
    try {
      await widget.repository.updateTransaction(
        widget.user,
        transaction,
        TransactionDraft.fromTransaction(transaction),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Edit undone')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  List<String> _recentCategories(List<WalletTransaction> transactions) {
    final seen = <String>{};
    final recent = <String>[];
    for (final transaction in transactions) {
      if (seen.add(transaction.category)) {
        recent.add(transaction.category);
      }
      if (recent.length >= 5) {
        break;
      }
    }
    return recent;
  }

  Future<void> _createRecurringFromTransaction(
    WalletTransaction transaction,
  ) async {
    try {
      await widget.repository.addRecurringTransaction(
        widget.user,
        RecurringTransactionDraft(
          title: transaction.notes.isEmpty
              ? transaction.category
              : transaction.notes,
          amount: transaction.amount,
          category: transaction.category,
          type: transaction.type == WalletTransactionType.refund
              ? WalletTransactionType.income
              : transaction.type,
          interval: RecurringInterval.monthly,
          nextDate: DateTime.now().add(const Duration(days: 30)),
          walletId: transaction.walletId,
          notes: 'Created from transaction',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recurring item created')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        repository: widget.repository,
        user: widget.user,
        syncStatus: _syncStatus,
        onAddTransaction: () => _openTransactionSheet(),
        onAddPreset: (preset) => _openTransactionSheet(preset: preset),
      ),
      TransactionsScreen(
        repository: widget.repository,
        user: widget.user,
        onEditTransaction: (transaction) =>
            _openTransactionSheet(transaction: transaction),
        onDuplicateTransaction: (transaction) => _openTransactionSheet(
          preset: TransactionPreset(
            amount: transaction.amount,
            category: transaction.category,
            type: transaction.type,
            notes: transaction.notes,
            walletId: transaction.walletId,
            paymentMethod: transaction.paymentMethod,
          ),
        ),
        onRefundTransaction: (transaction) => _openTransactionSheet(
          preset: TransactionPreset(
            amount: transaction.amount,
            category: transaction.category,
            type: WalletTransactionType.refund,
            notes:
                'Refund for ${transaction.notes.isEmpty ? transaction.category : transaction.notes}',
            walletId: transaction.walletId,
            paymentMethod: transaction.paymentMethod,
            linkedTransactionId: transaction.id,
          ),
        ),
        onSplitTransaction: (transaction) => _openTransactionSheet(
          preset: TransactionPreset(
            amount: transaction.amount / 2,
            category: transaction.category,
            type: transaction.type,
            notes:
                'Split: ${transaction.notes.isEmpty ? transaction.category : transaction.notes}',
            walletId: transaction.walletId,
            paymentMethod: transaction.paymentMethod,
            linkedTransactionId: transaction.id,
            isSplit: true,
          ),
        ),
        onMakeRecurring: _createRecurringFromTransaction,
      ),
      ReportsScreen(repository: widget.repository, user: widget.user),
      GoalsScreen(repository: widget.repository, user: widget.user),
      SettingsScreen(
        repository: widget.repository,
        user: widget.user,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyWallet'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.repository.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openTransactionSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Entries',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
