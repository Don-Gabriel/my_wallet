import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../models/budget.dart';
import '../models/bill_reminder.dart';
import '../models/category_budget.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/wallet_account.dart';
import '../models/wallet_user.dart';
import '../shared/backup_tools.dart';
import 'wallet_repository.dart';

class FirebaseWalletRepository implements WalletRepository {
  FirebaseWalletRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _firestore.settings = const Settings(persistenceEnabled: true);
  }

  static const _webClientId =
      '343256388815-4cf9nj2rrvj5ovqb7nlioutcocon08ee.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _googleSignInReady = false;

  @override
  String get projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  @override
  String get firestoreLocation => 'Mumbai';

  @override
  Stream<WalletUser?> authStateChanges() {
    return _auth.userChanges().map((user) {
      if (user == null) {
        return null;
      }

      return WalletUser(
        uid: user.uid,
        isAnonymous: user.isAnonymous,
        emailVerified: user.emailVerified,
        email: user.email,
        displayName: user.displayName,
      );
    });
  }

  @override
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignIn();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const WalletAuthException(
        'Google Sign-In is not available on this platform.',
      );
    }

    final account = await GoogleSignIn.instance.authenticate();
    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );

    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const WalletAuthException('Please sign in again.');
    }
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  @override
  Future<void> updatePassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const WalletAuthException('Please sign in again.');
    }
    await user.updatePassword(password);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleSignInReady) {
      await GoogleSignIn.instance.signOut();
    }
  }

  @override
  Future<void> syncUserProfile(WalletUser user) async {
    await _userRef(user).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'isAnonymous': user.isAnonymous,
      'emailVerified': user.emailVerified,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _seedCategories(user);
    await _seedWallets(user);
  }

  @override
  Future<void> deleteWalletData(WalletUser user) async {
    for (final collection in [
      'transactions',
      'categories',
      'budgets',
      'goals',
      'wallets',
      'categoryBudgets',
      'billReminders',
      'recurringTransactions',
    ]) {
      await _deleteCollection(_userRef(user).collection(collection));
    }
    await _userRef(user).delete();
  }

  @override
  Future<void> restoreBackup(WalletUser user, WalletBackup backup) async {
    final operations = <void Function(WriteBatch batch)>[];

    operations.add(
      (batch) => batch.set(
        _budgetRef(user),
        backup.budget.toFirestore(),
        SetOptions(merge: true),
      ),
    );

    for (final category in backup.categories) {
      final name = category.trim();
      if (name.isEmpty) {
        continue;
      }
      operations.add(
        (batch) => batch.set(_categoriesRef(user).doc(_categoryId(name)), {
          'name': name,
          'restoredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    }

    for (final wallet in backup.wallets) {
      operations.add(
        (batch) => batch.set(
          _walletsRef(user).doc(_safeDocumentId(wallet.id, defaultWalletId)),
          {
            ...WalletAccountDraft.fromAccount(wallet).toFirestore(),
            'restoredAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
      );
    }

    for (final budget in backup.categoryBudgets) {
      if (budget.category.trim().isEmpty || budget.monthlyLimit <= 0) {
        continue;
      }
      operations.add(
        (batch) => batch.set(
          _categoryBudgetsRef(user).doc(_categoryId(budget.category)),
          budget.toFirestore(),
          SetOptions(merge: true),
        ),
      );
    }

    for (final goal in backup.goals) {
      operations.add(
        (batch) => batch.set(
          _goalsRef(user).doc(_safeDocumentId(goal.id, 'goal')),
          SavingsGoalDraft.fromGoal(goal).toFirestore(),
          SetOptions(merge: true),
        ),
      );
    }

    for (final bill in backup.bills) {
      operations.add(
        (batch) => batch.set(
          _billRemindersRef(user).doc(_safeDocumentId(bill.id, 'bill')),
          BillReminderDraft.fromReminder(bill).toFirestore(),
          SetOptions(merge: true),
        ),
      );
    }

    for (final item in backup.recurring) {
      operations.add(
        (batch) => batch.set(
          _recurringTransactionsRef(
            user,
          ).doc(_safeDocumentId(item.id, 'recurring')),
          RecurringTransactionDraft.fromRecurring(item).toFirestore(),
          SetOptions(merge: true),
        ),
      );
    }

    for (final transaction in backup.transactions) {
      operations.add(
        (batch) => batch.set(
          _transactionsRef(
            user,
          ).doc(_safeDocumentId(transaction.id, 'transaction')),
          TransactionDraft.fromTransaction(transaction).toFirestore(),
          SetOptions(merge: true),
        ),
      );
    }

    await _commitOperations(operations);
  }

  @override
  Stream<List<WalletAccount>> watchWallets(WalletUser user) {
    return _walletsRef(user).orderBy('name').snapshots().map((snapshot) {
      final wallets = snapshot.docs.map(WalletAccount.fromSnapshot).toList();
      if (wallets.isEmpty) {
        return [WalletAccount.defaultAccount()];
      }
      return wallets;
    });
  }

  @override
  Future<void> addWallet(WalletUser user, WalletAccountDraft draft) {
    return _walletsRef(
      user,
    ).add({...draft.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> updateWallet(
    WalletUser user,
    WalletAccount wallet,
    WalletAccountDraft draft,
  ) {
    return _walletsRef(user).doc(wallet.id).update(draft.toFirestore());
  }

  @override
  Future<void> deleteWallet(WalletUser user, WalletAccount wallet) {
    if (wallet.id == defaultWalletId) {
      return Future.value();
    }
    return _walletsRef(user).doc(wallet.id).delete();
  }

  @override
  Stream<List<WalletTransaction>> watchTransactions(WalletUser user) {
    return _transactionsRef(user)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(WalletTransaction.fromSnapshot).toList(),
        );
  }

  @override
  Future<void> addTransaction(WalletUser user, TransactionDraft draft) {
    return _transactionsRef(
      user,
    ).add({...draft.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> updateTransaction(
    WalletUser user,
    WalletTransaction transaction,
    TransactionDraft draft,
  ) {
    return _transactionsRef(
      user,
    ).doc(transaction.id).update(draft.toFirestore());
  }

  @override
  Future<void> deleteTransaction(
    WalletUser user,
    WalletTransaction transaction,
  ) {
    return _transactionsRef(user).doc(transaction.id).delete();
  }

  @override
  Stream<List<String>> watchCategories(WalletUser user) {
    return _categoriesRef(user).orderBy('name').snapshots().map((snapshot) {
      final names = snapshot.docs
          .map((doc) => (doc.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet();
      if (names.isEmpty) {
        return defaultCategories;
      }
      return names.toList()..sort();
    });
  }

  @override
  Future<void> addCategory(WalletUser user, String category) {
    final name = category.trim();
    if (name.isEmpty) {
      return Future.value();
    }

    return _categoriesRef(user).doc(_categoryId(name)).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCategory(WalletUser user, String category) {
    return _categoriesRef(user).doc(_categoryId(category)).delete();
  }

  @override
  Stream<WalletBudget> watchBudget(WalletUser user) {
    return _budgetRef(user).snapshots().map((snapshot) {
      return WalletBudget.fromData(snapshot.data());
    });
  }

  @override
  Future<void> setMonthlyBudget(WalletUser user, double monthlyLimit) {
    return _budgetRef(user).set(
      WalletBudget(monthlyLimit: monthlyLimit).toFirestore(),
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<CategoryBudget>> watchCategoryBudgets(WalletUser user) {
    return _categoryBudgetsRef(user)
        .orderBy('category')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CategoryBudget.fromSnapshot).toList(),
        );
  }

  @override
  Future<void> setCategoryBudget(
    WalletUser user,
    String category,
    double monthlyLimit,
  ) {
    final doc = _categoryBudgetsRef(user).doc(_categoryId(category));
    if (monthlyLimit <= 0) {
      return doc.delete();
    }
    return doc.set(
      CategoryBudget(
        category: category,
        monthlyLimit: monthlyLimit,
      ).toFirestore(),
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<SavingsGoal>> watchGoals(WalletUser user) {
    return _goalsRef(user)
        .orderBy('deadline')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(SavingsGoal.fromSnapshot).toList(),
        );
  }

  @override
  Future<void> addGoal(WalletUser user, SavingsGoalDraft draft) {
    return _goalsRef(
      user,
    ).add({...draft.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> updateGoal(
    WalletUser user,
    SavingsGoal goal,
    SavingsGoalDraft draft,
  ) {
    return _goalsRef(user).doc(goal.id).update(draft.toFirestore());
  }

  @override
  Future<void> deleteGoal(WalletUser user, SavingsGoal goal) {
    return _goalsRef(user).doc(goal.id).delete();
  }

  @override
  Stream<List<BillReminder>> watchBillReminders(WalletUser user) {
    return _billRemindersRef(user)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(BillReminder.fromSnapshot).toList(),
        );
  }

  @override
  Future<void> addBillReminder(WalletUser user, BillReminderDraft draft) {
    return _billRemindersRef(
      user,
    ).add({...draft.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> updateBillReminder(
    WalletUser user,
    BillReminder reminder,
    BillReminderDraft draft,
  ) {
    return _billRemindersRef(user).doc(reminder.id).update(draft.toFirestore());
  }

  @override
  Future<void> deleteBillReminder(WalletUser user, BillReminder reminder) {
    return _billRemindersRef(user).doc(reminder.id).delete();
  }

  @override
  Future<void> setBillPaid(
    WalletUser user,
    BillReminder reminder,
    bool isPaid,
  ) {
    return _billRemindersRef(user).doc(reminder.id).update({
      'isPaid': isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactions(
    WalletUser user,
  ) {
    return _recurringTransactionsRef(user)
        .orderBy('nextDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(RecurringTransaction.fromSnapshot).toList(),
        );
  }

  @override
  Future<void> addRecurringTransaction(
    WalletUser user,
    RecurringTransactionDraft draft,
  ) {
    return _recurringTransactionsRef(
      user,
    ).add({...draft.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> updateRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
    RecurringTransactionDraft draft,
  ) {
    return _recurringTransactionsRef(
      user,
    ).doc(recurring.id).update(draft.toFirestore());
  }

  @override
  Future<void> deleteRecurringTransaction(
    WalletUser user,
    RecurringTransaction recurring,
  ) {
    return _recurringTransactionsRef(user).doc(recurring.id).delete();
  }

  DocumentReference<Map<String, dynamic>> _userRef(WalletUser user) {
    return _firestore.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _transactionsRef(WalletUser user) {
    return _userRef(user).collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> _walletsRef(WalletUser user) {
    return _userRef(user).collection('wallets');
  }

  CollectionReference<Map<String, dynamic>> _categoriesRef(WalletUser user) {
    return _userRef(user).collection('categories');
  }

  DocumentReference<Map<String, dynamic>> _budgetRef(WalletUser user) {
    return _userRef(user).collection('budgets').doc('monthly');
  }

  CollectionReference<Map<String, dynamic>> _categoryBudgetsRef(
    WalletUser user,
  ) {
    return _userRef(user).collection('categoryBudgets');
  }

  CollectionReference<Map<String, dynamic>> _goalsRef(WalletUser user) {
    return _userRef(user).collection('goals');
  }

  CollectionReference<Map<String, dynamic>> _billRemindersRef(WalletUser user) {
    return _userRef(user).collection('billReminders');
  }

  CollectionReference<Map<String, dynamic>> _recurringTransactionsRef(
    WalletUser user,
  ) {
    return _userRef(user).collection('recurringTransactions');
  }

  Future<void> _seedCategories(WalletUser user) async {
    final snapshot = await _categoriesRef(user).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final category in defaultCategories) {
      batch.set(_categoriesRef(user).doc(_categoryId(category)), {
        'name': category,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _seedWallets(WalletUser user) async {
    final snapshot = await _walletsRef(user).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }

    await _walletsRef(user).doc(defaultWalletId).set({
      ...const WalletAccountDraft(
        name: 'Main wallet',
        openingBalance: 0,
      ).toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) {
        return;
      }
    }
  }

  Future<void> _commitOperations(
    List<void Function(WriteBatch batch)> operations,
  ) async {
    for (var index = 0; index < operations.length; index += 400) {
      final batch = _firestore.batch();
      for (final operation in operations.skip(index).take(400)) {
        operation(batch);
      }
      await batch.commit();
    }
  }

  Future<void> _ensureGoogleSignIn() async {
    if (_googleSignInReady) {
      return;
    }

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
    _googleSignInReady = true;
  }
}

class WalletAuthException implements Exception {
  const WalletAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _categoryId(String category) {
  return category.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

String _safeDocumentId(String value, String fallback) {
  final safe = value.trim().replaceAll('/', '-');
  return safe.isEmpty ? fallback : safe;
}
