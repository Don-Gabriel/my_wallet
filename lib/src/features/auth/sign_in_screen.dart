import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_handling.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.repository});

  final WalletRepository repository;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  var _isBusy = false;
  String? _error;

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WalletMark(size: 38),
                  const SizedBox(height: 22),
                  Text(
                    'MyWallet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track money privately. Sync when you choose.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _submit(widget.repository.signInWithGoogle),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _submit(widget.repository.signInAnonymously),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Continue privately'),
                  ),
                  if (_isBusy) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    ErrorState(title: 'Sign-in failed', message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
