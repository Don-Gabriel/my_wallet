class WalletUser {
  const WalletUser({
    required this.uid,
    required this.isAnonymous,
    required this.emailVerified,
    this.email,
    this.displayName,
  });

  final String uid;
  final bool isAnonymous;
  final bool emailVerified;
  final String? email;
  final String? displayName;

  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!;
    }
    return isAnonymous ? 'Guest wallet' : 'MyWallet user';
  }
}
