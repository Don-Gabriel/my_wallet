import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/wallet_user.dart';
import '../../shared/common_widgets.dart';
import '../shell/app_shell.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final WalletRepository repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WalletUser?>(
      stream: repository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(repository: repository);
        }

        return AppShell(
          repository: repository,
          user: user,
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
        );
      },
    );
  }
}

class LoadingAppScreen extends StatelessWidget {
  const LoadingAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WalletMark(),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
