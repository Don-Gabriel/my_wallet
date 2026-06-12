import 'package:cloud_firestore/cloud_firestore.dart';

const defaultWalletId = 'main';

class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.openingBalance,
    this.showOnDashboard = true,
    this.isArchived = false,
  });

  factory WalletAccount.defaultAccount() {
    return const WalletAccount(
      id: defaultWalletId,
      name: 'Main wallet',
      openingBalance: 0,
      showOnDashboard: true,
      isArchived: false,
    );
  }

  factory WalletAccount.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return WalletAccount(
      id: snapshot.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Wallet',
      openingBalance: ((data['openingBalance'] as num?) ?? 0).toDouble(),
      showOnDashboard: (data['showOnDashboard'] as bool?) ?? true,
      isArchived: (data['isArchived'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final double openingBalance;
  final bool showOnDashboard;
  final bool isArchived;
}

class WalletAccountDraft {
  const WalletAccountDraft({
    required this.name,
    required this.openingBalance,
    this.showOnDashboard = true,
    this.isArchived = false,
  });

  factory WalletAccountDraft.fromAccount(WalletAccount account) {
    return WalletAccountDraft(
      name: account.name,
      openingBalance: account.openingBalance,
      showOnDashboard: account.showOnDashboard,
      isArchived: account.isArchived,
    );
  }

  final String name;
  final double openingBalance;
  final bool showOnDashboard;
  final bool isArchived;

  Map<String, Object?> toFirestore() {
    return {
      'name': name.trim(),
      'openingBalance': openingBalance,
      'showOnDashboard': showOnDashboard,
      'isArchived': isArchived,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
