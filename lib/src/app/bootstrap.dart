import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import '../data/firebase_wallet_repository.dart';
import '../data/wallet_repository.dart';
import '../shared/common_widgets.dart';
import 'my_wallet_app.dart';

class MyWalletBootstrap extends StatefulWidget {
  const MyWalletBootstrap({super.key});

  @override
  State<MyWalletBootstrap> createState() => _MyWalletBootstrapState();
}

class _MyWalletBootstrapState extends State<MyWalletBootstrap> {
  late final Future<WalletRepository> _repositoryFuture = _initialize();

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
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WalletMark(),
                    const SizedBox(height: 24),
                    Text(
                      'MyWallet',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.hasError)
                      Text(
                        'Firebase setup needs attention: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
