import '../models/budget.dart';
import '../models/bill_reminder.dart';
import '../models/category_budget.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/wallet_account.dart';
import '../models/wallet_user.dart';
import '../shared/backup_tools.dart';

abstract class WalletRepository {
  String get projectId;

  String get firestoreLocation;

  Stream<WalletUser?> authStateChanges();

  Future<void> signInAnonymously();

  Future<void> signInWithGoogle();

  Future<void> updateDisplayName(String name);

  Future<void> updatePassword(String password);

  Future<void> signOut();

  Future<void> syncUserProfile(WalletUser user);

  Future<void> deleteWalletData(WalletUser user);

  Future<void> restoreBackup(WalletUser user, WalletBackup backup);

  Stream<List<WalletAccount>> watchWallets(WalletUser user);

  Future<void> addWallet(WalletUser user, WalletAccountDraft draft);

  Future<void> updateWallet(
    WalletUser user,
    WalletAccount wallet,
    WalletAccountDraft draft,
  );

  Future<void> deleteWallet(WalletUser user, WalletAccount wallet);

  Stream<List<WalletTransaction>> watchTransactions(WalletUser user);

  Future<void> addTransaction(WalletUser user, TransactionDraft draft);

  Future<void> updateTransaction(
    WalletUser user,
    WalletTransaction transaction,
    TransactionDraft draft,
  );

  Future<void> deleteTransaction(
    WalletUser user,
    WalletTransaction transaction,
  );

  Stream<List<String>> watchCategories(WalletUser user);

  Future<void> addCategory(WalletUser user, String category);

  Future<void> deleteCategory(WalletUser user, String category);

  Stream<WalletBudget> watchBudget(WalletUser user);

  Future<void> setMonthlyBudget(WalletUser user, double monthlyLimit);

  Stream<List<CategoryBudget>> watchCategoryBudgets(WalletUser user);

  Future<void> setCategoryBudget(
    WalletUser user,
    String category,
    double monthlyLimit,
  );

  Stream<List<SavingsGoal>> watchGoals(WalletUser user);

  Future<void> addGoal(WalletUser user, SavingsGoalDraft draft);

  Future<void> updateGoal(
    WalletUser user,
    SavingsGoal goal,
    SavingsGoalDraft draft,
  );

  Future<void> deleteGoal(WalletUser user, SavingsGoal goal);

  Stream<List<BillReminder>> watchBillReminders(WalletUser user);

  Future<void> addBillReminder(WalletUser user, BillReminderDraft draft);

  Future<void> updateBillReminder(
    WalletUser user,
    BillReminder reminder,
    BillReminderDraft draft,
  );

  Future<void> deleteBillReminder(WalletUser user, BillReminder reminder);

  Future<void> setBillPaid(WalletUser user, BillReminder reminder, bool isPaid);

  Stream<List<RecurringTransaction>> watchRecurringTransactions(
    WalletUser user,
  );

  Future<void> addRecurringTransaction(
    WalletUser user,
    RecurringTransactionDraft draft,
  );

  Future<void> updateRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
    RecurringTransactionDraft draft,
  );

  Future<void> deleteRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
  );
}

const defaultCategories = [
  'Food',
  'Transport',
  'Bills',
  'Shopping',
  'Entertainment',
  'Health',
  'Education',
  'Rent',
  'Salary',
  'Freelance',
  'Other',
];
