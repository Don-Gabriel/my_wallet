import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/wallet_account.dart';
import '../../shared/error_handling.dart';

class WalletFormSheet extends StatefulWidget {
  const WalletFormSheet({super.key, required this.onSave, this.wallet});

  final WalletAccount? wallet;
  final Future<void> Function(WalletAccountDraft draft) onSave;

  @override
  State<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends State<WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late bool _showOnDashboard;
  late bool _isArchived;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _openingBalanceController = TextEditingController(
      text: wallet == null ? '' : wallet.openingBalance.toStringAsFixed(0),
    );
    _showOnDashboard = wallet?.showOnDashboard ?? true;
    _isArchived = wallet?.isArchived ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        WalletAccountDraft(
          name: _nameController.text.trim(),
          openingBalance:
              double.tryParse(
                _openingBalanceController.text.trim().replaceAll(',', ''),
              ) ??
              0,
          showOnDashboard: _showOnDashboard,
          isArchived: _isArchived,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.wallet == null ? 'Add wallet' : 'Edit wallet';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Wallet name'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter a wallet name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Opening balance',
                prefixText: 'INR ',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showOnDashboard,
              title: const Text('Show on dashboard'),
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _showOnDashboard = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isArchived,
              title: const Text('Archive wallet'),
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _isArchived = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(widget.wallet == null ? 'Save wallet' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}
