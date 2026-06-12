import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import '../data/firebase_wallet_repository.dart';
import '../data/wallet_repository.dart';
import '../shared/app_splash_screen.dart';
import 'my_wallet_app.dart';

class MyWalletBootstrap extends StatefulWidget {
  const MyWalletBootstrap({super.key});

  @override
  State<MyWalletBootstrap> createState() => _MyWalletBootstrapState();
}

class _MyWalletBootstrapState extends State<MyWalletBootstrap> {
  late final Future<WalletRepository> _repositoryFuture =
      _initializeWithSplash();

  Future<WalletRepository> _initializeWithSplash() async {
    final repositoryFuture = _initialize();
    await Future.wait<void>([
      repositoryFuture.then((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 2200)),
    ]);
    return repositoryFuture;
  }

  Future<WalletRepository> _initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    unawaited(FirebaseAnalytics.instance.logAppOpen());
    return FirebaseWalletRepository();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WalletRepository>(
      future: _repositoryFuture,
      builder: (context, snapshot) {
        final repository = snapshot.data;
        if (repository != null) {
          return MyWalletApp(repository: repository);
        }

        return MaterialApp(
          title: 'MyWallet',
          debugShowCheckedModeBanner: false,
          home: AppSplashScreen(
            status: 'Syncing your private wallet',
            error: snapshot.error,
          ),
        );
      },
    );
  }
}
