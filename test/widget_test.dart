import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/src/app/my_wallet_app.dart';
import 'package:mywallet/src/data/wallet_repository.dart';
import 'package:mywallet/src/models/bill_reminder.dart';
import 'package:mywallet/src/models/budget.dart';
import 'package:mywallet/src/models/category_budget.dart';
import 'package:mywallet/src/models/recurring_transaction.dart';
import 'package:mywallet/src/models/savings_goal.dart';
import 'package:mywallet/src/models/transaction.dart';
import 'package:mywallet/src/models/wallet_account.dart';
import 'package:mywallet/src/models/wallet_user.dart';
import 'package:mywallet/src/shared/backup_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({WalletUser? initialUser})
    : _user = initialUser,
      _authController = StreamController.broadcast(),
      _transactionsController = StreamController.broadcast(),
      _categoriesController = StreamController.broadcast(),
      _budgetController = StreamController.broadcast(),
      _categoryBudgetsController = StreamController.broadcast(),
      _goalsController = StreamController.broadcast(),
      _walletsController = StreamController.broadcast(),
      _billsController = StreamController.broadcast(),
      _recurringController = StreamController.broadcast();

  WalletUser? _user;
  WalletBudget _budget = const WalletBudget(monthlyLimit: 0);
  final StreamController<WalletUser?> _authController;
  final StreamController<List<WalletTransaction>> _transactionsController;
  final StreamController<List<String>> _categoriesController;
  final StreamController<WalletBudget> _budgetController;
  final StreamController<List<CategoryBudget>> _categoryBudgetsController;
  final StreamController<List<SavingsGoal>> _goalsController;
  final StreamController<List<WalletAccount>> _walletsController;
  final StreamController<List<BillReminder>> _billsController;
  final StreamController<List<RecurringTransaction>> _recurringController;
  final List<WalletTransaction> _transactions = [];
  final List<String> _categories = List.of(defaultCategories);
  final List<CategoryBudget> _categoryBudgets = [];
  final List<SavingsGoal> _goals = [];
  final List<WalletAccount> _wallets = [WalletAccount.defaultAccount()];
  final List<BillReminder> _bills = [];
  final List<RecurringTransaction> _recurring = [];

  @override
  String get firestoreLocation => 'Mumbai';

  @override
  String get projectId => 'mywallet-d581d';

  @override
  Stream<WalletUser?> authStateChanges() async* {
    yield _user;
    yield* _authController.stream;
  }

  @override
  Future<void> signInAnonymously() async {
    _user = const WalletUser(
      uid: 'test-user',
      isAnonymous: true,
      emailVerified: false,
    );
    _authController.add(_user);
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _user;
    if (user == null) {
      return;
    }
    _user = WalletUser(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      emailVerified: user.emailVerified,
      email: user.email,
      displayName: name,
    );
    _authController.add(_user);
  }

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {
    _user = null;
    _authController.add(_user);
  }

  @override
  Future<void> syncUserProfile(WalletUser user) async {}

  @override
  Future<void> deleteWalletData(WalletUser user) async {
    _transactions.clear();
    _categories
      ..clear()
      ..addAll(defaultCategories);
    _categoryBudgets.clear();
    _goals.clear();
    _wallets
      ..clear()
      ..add(WalletAccount.defaultAccount());
    _bills.clear();
    _recurring.clear();
    await signOut();
  }

  @override
  Future<void> restoreBackup(WalletUser user, WalletBackup backup) async {
    _budget = backup.budget;
    _categories
      ..clear()
      ..addAll({...defaultCategories, ...backup.categories}.toList()..sort());
    _wallets
      ..clear()
      ..addAll(
        backup.wallets.isEmpty
            ? [WalletAccount.defaultAccount()]
            : backup.wallets,
      );
    _transactions
      ..clear()
      ..addAll(backup.transactions);
    _categoryBudgets
      ..clear()
      ..addAll(backup.categoryBudgets);
    _goals
      ..clear()
      ..addAll(backup.goals);
    _bills
      ..clear()
      ..addAll(backup.bills);
    _recurring
      ..clear()
      ..addAll(backup.recurring);

    _budgetController.add(_budget);
    _categoriesController.add(List.unmodifiable(_categories));
    _walletsController.add(List.unmodifiable(_wallets));
    _transactionsController.add(List.unmodifiable(_transactions));
    _categoryBudgetsController.add(List.unmodifiable(_categoryBudgets));
    _goalsController.add(List.unmodifiable(_goals));
    _billsController.add(List.unmodifiable(_bills));
    _recurringController.add(List.unmodifiable(_recurring));
  }

  @override
  Stream<List<WalletAccount>> watchWallets(WalletUser user) async* {
    yield List.unmodifiable(_wallets);
    yield* _walletsController.stream;
  }

  @override
  Future<void> addWallet(WalletUser user, WalletAccountDraft draft) async {
    _wallets.add(
      WalletAccount(
        id: 'wallet-${_wallets.length + 1}',
        name: draft.name,
        openingBalance: draft.openingBalance,
        showOnDashboard: draft.showOnDashboard,
        isArchived: draft.isArchived,
      ),
    );
    _walletsController.add(List.unmodifiable(_wallets));
  }

  @override
  Future<void> updateWallet(
    WalletUser user,
    WalletAccount wallet,
    WalletAccountDraft draft,
  ) async {
    final index = _wallets.indexWhere((item) => item.id == wallet.id);
    if (index >= 0) {
      _wallets[index] = WalletAccount(
        id: wallet.id,
        name: draft.name,
        openingBalance: draft.openingBalance,
        showOnDashboard: draft.showOnDashboard,
        isArchived: draft.isArchived,
      );
      _walletsController.add(List.unmodifiable(_wallets));
    }
  }

  @override
  Future<void> deleteWallet(WalletUser user, WalletAccount wallet) async {
    if (wallet.id == defaultWalletId) {
      return;
    }
    _wallets.removeWhere((item) => item.id == wallet.id);
    _walletsController.add(List.unmodifiable(_wallets));
  }

  @override
  Stream<List<WalletTransaction>> watchTransactions(WalletUser user) async* {
    yield List.unmodifiable(_transactions);
    yield* _transactionsController.stream;
  }

  @override
  Future<void> addTransaction(WalletUser user, TransactionDraft draft) async {
    _transactions.insert(
      0,
      WalletTransaction(
        id: 'transaction-${_transactions.length + 1}',
        amount: draft.amount,
        category: draft.category,
        type: draft.type,
        date: draft.date,
        walletId: draft.walletId,
        notes: draft.notes,
        transferWalletId: draft.transferWalletId,
        paymentMethod: draft.paymentMethod,
        linkedTransactionId: draft.linkedTransactionId,
        isSplit: draft.isSplit,
      ),
    );
    _transactionsController.add(List.unmodifiable(_transactions));
  }

  @override
  Future<void> updateTransaction(
    WalletUser user,
    WalletTransaction transaction,
    TransactionDraft draft,
  ) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index >= 0) {
      _transactions[index] = WalletTransaction(
        id: transaction.id,
        amount: draft.amount,
        category: draft.category,
        type: draft.type,
        date: draft.date,
        walletId: draft.walletId,
        notes: draft.notes,
        transferWalletId: draft.transferWalletId,
        paymentMethod: draft.paymentMethod,
        linkedTransactionId: draft.linkedTransactionId,
        isSplit: draft.isSplit,
      );
      _transactionsController.add(List.unmodifiable(_transactions));
    }
  }

  @override
  Future<void> deleteTransaction(
    WalletUser user,
    WalletTransaction transaction,
  ) async {
    _transactions.removeWhere((item) => item.id == transaction.id);
    _transactionsController.add(List.unmodifiable(_transactions));
  }

  @override
  Stream<List<String>> watchCategories(WalletUser user) async* {
    yield List.unmodifiable(_categories);
    yield* _categoriesController.stream;
  }

  @override
  Future<void> addCategory(WalletUser user, String category) async {
    _categories.add(category);
    _categories.sort();
    _categoriesController.add(List.unmodifiable(_categories));
  }

  @override
  Future<void> deleteCategory(WalletUser user, String category) async {
    _categories.remove(category);
    _categoriesController.add(List.unmodifiable(_categories));
  }

  @override
  Stream<WalletBudget> watchBudget(WalletUser user) async* {
    yield _budget;
    yield* _budgetController.stream;
  }

  @override
  Future<void> setMonthlyBudget(WalletUser user, double monthlyLimit) async {
    _budget = WalletBudget(monthlyLimit: monthlyLimit);
    _budgetController.add(_budget);
  }

  @override
  Stream<List<CategoryBudget>> watchCategoryBudgets(WalletUser user) async* {
    yield List.unmodifiable(_categoryBudgets);
    yield* _categoryBudgetsController.stream;
  }

  @override
  Future<void> setCategoryBudget(
    WalletUser user,
    String category,
    double monthlyLimit,
  ) async {
    _categoryBudgets.removeWhere((budget) => budget.category == category);
    if (monthlyLimit > 0) {
      _categoryBudgets.add(
        CategoryBudget(category: category, monthlyLimit: monthlyLimit),
      );
    }
    _categoryBudgetsController.add(List.unmodifiable(_categoryBudgets));
  }

  @override
  Stream<List<SavingsGoal>> watchGoals(WalletUser user) async* {
    yield List.unmodifiable(_goals);
    yield* _goalsController.stream;
  }

  @override
  Future<void> addGoal(WalletUser user, SavingsGoalDraft draft) async {
    _goals.add(
      SavingsGoal(
        id: 'goal-${_goals.length + 1}',
        name: draft.name,
        targetAmount: draft.targetAmount,
        currentAmount: draft.currentAmount,
        deadline: draft.deadline,
      ),
    );
    _goalsController.add(List.unmodifiable(_goals));
  }

  @override
  Future<void> updateGoal(
    WalletUser user,
    SavingsGoal goal,
    SavingsGoalDraft draft,
  ) async {}

  @override
  Future<void> deleteGoal(WalletUser user, SavingsGoal goal) async {
    _goals.removeWhere((item) => item.id == goal.id);
    _goalsController.add(List.unmodifiable(_goals));
  }

  @override
  Stream<List<BillReminder>> watchBillReminders(WalletUser user) async* {
    yield List.unmodifiable(_bills);
    yield* _billsController.stream;
  }

  @override
  Future<void> addBillReminder(WalletUser user, BillReminderDraft draft) async {
    _bills.add(
      BillReminder(
        id: 'bill-${_bills.length + 1}',
        name: draft.name,
        amount: draft.amount,
        category: draft.category,
        dueDate: draft.dueDate,
        isPaid: draft.isPaid,
      ),
    );
    _billsController.add(List.unmodifiable(_bills));
  }

  @override
  Future<void> updateBillReminder(
    WalletUser user,
    BillReminder reminder,
    BillReminderDraft draft,
  ) async {
    final index = _bills.indexWhere((item) => item.id == reminder.id);
    if (index >= 0) {
      _bills[index] = BillReminder(
        id: reminder.id,
        name: draft.name,
        amount: draft.amount,
        category: draft.category,
        dueDate: draft.dueDate,
        isPaid: draft.isPaid,
      );
      _billsController.add(List.unmodifiable(_bills));
    }
  }

  @override
  Future<void> deleteBillReminder(
    WalletUser user,
    BillReminder reminder,
  ) async {
    _bills.removeWhere((item) => item.id == reminder.id);
    _billsController.add(List.unmodifiable(_bills));
  }

  @override
  Future<void> setBillPaid(
    WalletUser user,
    BillReminder reminder,
    bool isPaid,
  ) async {
    final index = _bills.indexWhere((item) => item.id == reminder.id);
    if (index >= 0) {
      _bills[index] = BillReminder(
        id: reminder.id,
        name: reminder.name,
        amount: reminder.amount,
        category: reminder.category,
        dueDate: reminder.dueDate,
        isPaid: isPaid,
      );
      _billsController.add(List.unmodifiable(_bills));
    }
  }

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactions(
    WalletUser user,
  ) async* {
    yield List.unmodifiable(_recurring);
    yield* _recurringController.stream;
  }

  @override
  Future<void> addRecurringTransaction(
    WalletUser user,
    RecurringTransactionDraft draft,
  ) async {
    _recurring.add(
      RecurringTransaction(
        id: 'recurring-${_recurring.length + 1}',
        title: draft.title,
        amount: draft.amount,
        category: draft.category,
        type: draft.type,
        interval: draft.interval,
        nextDate: draft.nextDate,
        walletId: draft.walletId,
        notes: draft.notes,
        isPaused: draft.isPaused,
      ),
    );
    _recurringController.add(List.unmodifiable(_recurring));
  }

  @override
  Future<void> updateRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
    RecurringTransactionDraft draft,
  ) async {
    final index = _recurring.indexWhere((item) => item.id == recurring.id);
    if (index >= 0) {
      _recurring[index] = RecurringTransaction(
        id: recurring.id,
        title: draft.title,
        amount: draft.amount,
        category: draft.category,
        type: draft.type,
        interval: draft.interval,
        nextDate: draft.nextDate,
        walletId: draft.walletId,
        notes: draft.notes,
        isPaused: draft.isPaused,
      );
      _recurringController.add(List.unmodifiable(_recurring));
    }
  }

  @override
  Future<void> deleteRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
  ) async {
    _recurring.removeWhere((item) => item.id == recurring.id);
    _recurringController.add(List.unmodifiable(_recurring));
  }

  Future<void> dispose() async {
    await _authController.close();
    await _transactionsController.close();
    await _categoriesController.close();
    await _budgetController.close();
    await _categoryBudgetsController.close();
    await _goalsController.close();
    await _walletsController.close();
    await _billsController.close();
    await _recurringController.close();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpReady(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapCalculatorKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey('calculator_key_$key'));
    for (var attempt = 0; attempt < 8 && finder.evaluate().isEmpty; attempt++) {
      await tester.drag(
        find.byKey(const ValueKey('transaction_form_scroll')),
        const Offset(0, -240),
      );
      await tester.pump();
    }
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('shows private sign-in option before auth', (tester) async {
    final repository = FakeWalletRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(MyWalletApp(repository: repository));
    await pumpReady(tester);

    expect(find.text('MyWallet'), findsOneWidget);
    expect(find.text('Continue privately'), findsOneWidget);
  });

  testWidgets('shows dashboard after anonymous sign-in', (tester) async {
    final repository = FakeWalletRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(MyWalletApp(repository: repository));
    await pumpReady(tester);

    await tester.ensureVisible(find.text('Continue privately'));
    await tester.tap(find.text('Continue privately'));
    await pumpReady(tester);

    expect(find.text('Guest wallet'), findsOneWidget);
    expect(find.text('Monthly budget'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('adds a transaction from the dashboard sheet', (tester) async {
    final repository = FakeWalletRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(MyWalletApp(repository: repository));
    await pumpReady(tester);

    await tester.ensureVisible(find.text('Continue privately'));
    await tester.tap(find.text('Continue privately'));
    await pumpReady(tester);

    await tester.tap(find.text('Add'));
    await pumpReady(tester);

    expect(find.text('Add entry'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await pumpReady(tester);
    await tester.enterText(
      find.byKey(const ValueKey('transaction_notes')),
      'Lunch',
    );
    await tapCalculatorKey(tester, '1');
    await tapCalculatorKey(tester, '2');
    await tapCalculatorKey(tester, '0');
    await tester.tap(find.byTooltip('Save'));
    await pumpReady(tester);

    expect(find.text('Food'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Lunch'), findsOneWidget);
    expect(find.text('-INR 120.00'), findsAtLeastNWidgets(1));
  });
}
