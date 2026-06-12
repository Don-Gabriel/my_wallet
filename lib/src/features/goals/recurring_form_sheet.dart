import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';

class RecurringFormSheet extends StatefulWidget {
  const RecurringFormSheet({
    super.key,
    required this.categories,
    required this.wallets,
    required this.onSave,
    this.recurring,
  });

  final List<String> categories;
  final List<WalletAccount> wallets;
  final RecurringTransaction? recurring;
  final Future<void> Function(RecurringTransactionDraft draft) onSave;

  @override
  State<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late WalletTransactionType _type;
  late RecurringInterval _interval;
  late String _category;
  late String _walletId;
  late DateTime _nextDate;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final recurring = widget.recurring;
    _titleController = TextEditingController(text: recurring?.title ?? '');
    _amountController = TextEditingController(
      text: recurring == null ? '' : recurring.amount.toStringAsFixed(0),
    );
    _type = recurring?.type ?? WalletTransactionType.expense;
    _interval = recurring?.interval ?? RecurringInterval.monthly;
    _category = _categoryOrDefault(recurring?.category);
    _walletId = _walletIdOrDefault(recurring?.walletId);
    _nextDate =
        recurring?.nextDate ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _nextDate = picked);
    }
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
        RecurringTransactionDraft(
          title: _titleController.text.trim(),
          amount: double.parse(
            _amountController.text.trim().replaceAll(',', ''),
          ),
          category: _category,
          type: _type,
          interval: _interval,
          nextDate: _nextDate,
          walletId: _walletId,
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
    final title = widget.recurring == null ? 'Add recurring' : 'Edit recurring';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.repeat_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'INR ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WalletTransactionType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items:
                    [
                          WalletTransactionType.expense,
                          WalletTransactionType.income,
                        ]
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _type = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              if (widget.wallets.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _walletId,
                  decoration: const InputDecoration(labelText: 'Wallet'),
                  items: widget.wallets
                      .map(
                        (wallet) => DropdownMenuItem(
                          value: wallet.id,
                          child: Text(wallet.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _walletId = value);
                          }
                        },
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<RecurringInterval>(
                segments: RecurringInterval.values
                    .map(
                      (interval) => ButtonSegment(
                        value: interval,
                        label: Text(interval.label),
                      ),
                    )
                    .toList(),
                selected: {_interval},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) =>
                          setState(() => _interval = selection.first),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(formatDate(_nextDate)),
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
                label: Text(
                  widget.recurring == null ? 'Save recurring' : 'Update',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _firstWalletId {
    return widget.wallets.isEmpty ? defaultWalletId : widget.wallets.first.id;
  }

  String _categoryOrDefault(String? category) {
    if (category != null && widget.categories.contains(category)) {
      return category;
    }
    return widget.categories.isEmpty ? 'Other' : widget.categories.first;
  }

  String _walletIdOrDefault(String? walletId) {
    if (walletId != null &&
        widget.wallets.any((wallet) => wallet.id == walletId)) {
      return walletId;
    }
    return _firstWalletId;
  }
}
