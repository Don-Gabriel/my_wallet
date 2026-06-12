import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../shared/error_handling.dart';
import '../../shared/finance_intelligence.dart';
import '../../shared/formatters.dart';

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({
    super.key,
    required this.categories,
    required this.wallets,
    required this.onSave,
    this.recentCategories = const [],
    this.existingTransactions = const [],
    this.transaction,
    this.initialPreset,
  });

  final List<String> categories;
  final List<String> recentCategories;
  final List<WalletTransaction> existingTransactions;
  final List<WalletAccount> wallets;
  final WalletTransaction? transaction;
  final TransactionPreset? initialPreset;
  final Future<void> Function(TransactionDraft draft) onSave;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late WalletTransactionType _type;
  late String _category;
  late String _walletId;
  String? _transferWalletId;
  late DateTime _date;
  late String _expression;
  late final TextEditingController _notesController;
  String _paymentMethod = 'Cash';
  String? _suggestedCategory;
  var _showDetails = false;
  var _isSaving = false;
  var _duplicateAccepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final preset = widget.initialPreset;
    _type = transaction?.type ?? preset?.type ?? WalletTransactionType.expense;
    _category = _categoryOrDefault(transaction?.category ?? preset?.category);
    _walletId = _walletIdOrDefault(transaction?.walletId ?? preset?.walletId);
    _transferWalletId = _transferWalletIdOrNull(transaction?.transferWalletId);
    _date = transaction?.date ?? DateTime.now();
    _expression =
        (transaction?.amount ?? preset?.amount)?.toStringAsFixed(0) ?? '0';
    _notesController = TextEditingController(
      text: transaction?.notes ?? preset?.notes ?? '',
    );
    _notesController.addListener(_updateSuggestedCategory);
    _paymentMethod = transaction?.paymentMethod.isNotEmpty == true
        ? transaction!.paymentMethod
        : preset?.paymentMethod.isNotEmpty == true
        ? preset!.paymentMethod
        : 'Cash';
    _updateSuggestedCategory();
  }

  @override
  void didUpdateWidget(covariant TransactionFormSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.categories.contains(_category)) {
      _category = widget.categories.isEmpty ? 'Other' : widget.categories.first;
    }
    if (!widget.wallets.any((wallet) => wallet.id == _walletId)) {
      _walletId = _firstWalletId;
    }
    if (_transferWalletId != null &&
        !widget.wallets.any((wallet) => wallet.id == _transferWalletId)) {
      _transferWalletId = null;
    }
  }

  @override
  void dispose() {
    _notesController.removeListener(_updateSuggestedCategory);
    _notesController.dispose();
    super.dispose();
  }

  void _updateSuggestedCategory() {
    final suggestion = suggestCategoryFromText(
      _notesController.text,
      widget.categories,
    );
    if (suggestion == _suggestedCategory) {
      return;
    }
    setState(() {
      _suggestedCategory = suggestion;
      _duplicateAccepted = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final amount = _evaluateExpression(_expression);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (_type == WalletTransactionType.transfer &&
        widget.wallets.length > 1 &&
        _transferWalletId == null) {
      setState(() => _error = 'Choose the receiving wallet');
      return;
    }

    final draft = TransactionDraft(
      amount: amount,
      category: _category,
      type: _type,
      date: _date,
      walletId: _walletId,
      notes: _notesController.text.trim(),
      transferWalletId: _type == WalletTransactionType.transfer
          ? _transferWalletId
          : null,
      paymentMethod: _paymentMethod,
      linkedTransactionId: widget.initialPreset?.linkedTransactionId,
      isSplit: widget.initialPreset?.isSplit ?? false,
    );

    final duplicate = findDuplicateCandidate(
      draft,
      widget.existingTransactions,
      ignoreTransactionId: widget.transaction?.id,
    );
    if (!_duplicateAccepted && duplicate != null) {
      final proceed = await _confirmDuplicate(duplicate.transaction);
      if (!proceed) {
        return;
      }
      _duplicateAccepted = true;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(draft);
      if (mounted) {
        Navigator.of(context).pop(draft);
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

  Future<bool> _confirmDuplicate(WalletTransaction duplicate) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Possible duplicate'),
          content: Text(
            '${duplicate.category} for ${formatMoney(duplicate.amount)} already exists on ${formatDate(duplicate.date)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save anyway'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final amount = _evaluateExpression(_expression);
    final templates = _templates();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            ColoredBox(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                        const Spacer(),
                        Text(
                          widget.transaction == null ? 'Add entry' : 'Edit',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton.filled(
                          tooltip: 'Save',
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<WalletTransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: WalletTransactionType.income,
                          label: Text('Income'),
                        ),
                        ButtonSegment(
                          value: WalletTransactionType.expense,
                          label: Text('Expense'),
                        ),
                        ButtonSegment(
                          value: WalletTransactionType.transfer,
                          label: Text('Transfer'),
                        ),
                      ],
                      selected: {
                        _type == WalletTransactionType.refund
                            ? WalletTransactionType.income
                            : _type,
                      },
                      onSelectionChanged: _isSaving
                          ? null
                          : (selection) {
                              setState(() {
                                _type = selection.first;
                                if (_type != WalletTransactionType.transfer) {
                                  _transferWalletId = null;
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              amount == null
                                  ? formatCalculatorExpression(_expression)
                                  : formatNumberWithCommas(
                                      amount,
                                      fractionDigits: 2,
                                      trimTrailingZeros: true,
                                    ),
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'INR',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerButton(
                            label: 'Account',
                            value: _walletName(_walletId),
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: _pickWallet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PickerButton(
                            label: _type == WalletTransactionType.transfer
                                ? 'To account'
                                : 'Category',
                            value: _type == WalletTransactionType.transfer
                                ? _walletName(_transferWalletId)
                                : _category,
                            icon: _type == WalletTransactionType.transfer
                                ? Icons.swap_horiz
                                : Icons.category_outlined,
                            onTap: _type == WalletTransactionType.transfer
                                ? _pickTransferWallet
                                : _pickCategory,
                          ),
                        ),
                      ],
                    ),
                    if (templates.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: templates.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = templates[index];
                            return ActionChip(
                              label: Text(category),
                              onPressed: () =>
                                  setState(() => _category = category),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView(
                key: const ValueKey('transaction_form_scroll'),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                children: [
                  _DetailsPanel(
                    expanded: _showDetails,
                    notesController: _notesController,
                    date: _date,
                    paymentMethod: _paymentMethod,
                    suggestedCategory:
                        _suggestedCategory != null &&
                            _suggestedCategory != _category
                        ? _suggestedCategory
                        : null,
                    onToggle: () =>
                        setState(() => _showDetails = !_showDetails),
                    onPickDate: _pickDate,
                    onPaymentMethodChanged: (value) =>
                        setState(() => _paymentMethod = value),
                    onSuggestedCategorySelected: (value) =>
                        setState(() => _category = value),
                  ),
                  const SizedBox(height: 10),
                  _Keypad(onTap: _handleKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleKey(String key) {
    setState(() {
      _error = null;
      if (key == 'back') {
        _expression = _expression.length <= 1
            ? '0'
            : _expression.substring(0, _expression.length - 1);
        return;
      }
      if (key == 'clear') {
        _expression = '0';
        return;
      }
      if (key == '=') {
        final value = _evaluateExpression(_expression);
        if (value != null) {
          _expression = value.toStringAsFixed(
            value.truncateToDouble() == value ? 0 : 2,
          );
        }
        return;
      }
      if ('+-*/'.contains(key)) {
        if ('+-*/'.contains(_expression.characters.last)) {
          _expression = _expression.substring(0, _expression.length - 1) + key;
        } else {
          _expression += key;
        }
        return;
      }
      if (key == '.' && _currentNumberContainsDecimal()) {
        return;
      }
      _expression = _expression == '0' && key != '.' ? key : _expression + key;
      _duplicateAccepted = false;
    });
  }

  bool _currentNumberContainsDecimal() {
    final parts = _expression.split(RegExp(r'[+\-*/]'));
    return parts.isNotEmpty && parts.last.contains('.');
  }

  Future<void> _pickCategory() async {
    final value = await _pickFromList(
      title: 'Category',
      values: widget.categories,
      labelFor: (item) => item,
    );
    if (value != null) {
      setState(() {
        _category = value;
        _duplicateAccepted = false;
      });
    }
  }

  Future<void> _pickWallet() async {
    final value = await _pickFromList(
      title: 'Account',
      values: widget.wallets,
      labelFor: (wallet) => wallet.name,
    );
    if (value != null) {
      setState(() {
        _walletId = value.id;
        if (_transferWalletId == _walletId) {
          _transferWalletId = null;
        }
      });
    }
  }

  Future<void> _pickTransferWallet() async {
    final value = await _pickFromList(
      title: 'To account',
      values: widget.wallets.where((wallet) => wallet.id != _walletId).toList(),
      labelFor: (wallet) => wallet.name,
    );
    if (value != null) {
      setState(() => _transferWalletId = value.id);
    }
  }

  Future<T?> _pickFromList<T>({
    required String title,
    required List<T> values,
    required String Function(T value) labelFor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          shrinkWrap: true,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final value in values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labelFor(value)),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        );
      },
    );
  }

  List<String> _templates() {
    final active = widget.categories.toSet();
    final preferred = [
      ...widget.recentCategories,
      'Food',
      'Transport',
      'Bills',
      'Shopping',
      'Salary',
    ].where(active.contains).toSet().toList();
    if (preferred.isNotEmpty) {
      return preferred.take(8).toList();
    }
    return widget.categories.take(8).toList();
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

  String? _transferWalletIdOrNull(String? walletId) {
    if (walletId == null || walletId == _walletId) {
      return null;
    }
    return widget.wallets.any((wallet) => wallet.id == walletId)
        ? walletId
        : null;
  }

  String _walletName(String? walletId) {
    if (walletId == null) {
      return 'Select';
    }
    return widget.wallets
        .firstWhere(
          (wallet) => wallet.id == walletId,
          orElse: WalletAccount.defaultAccount,
        )
        .name;
  }

  double? _evaluateExpression(String expression) {
    try {
      final tokens = _tokenize(expression);
      if (tokens.isEmpty) {
        return null;
      }
      final values = <double>[];
      final ops = <String>[];
      for (final token in tokens) {
        final number = double.tryParse(token);
        if (number != null) {
          values.add(number);
        } else if ('+-*/'.contains(token)) {
          while (ops.isNotEmpty &&
              _precedence(ops.last) >= _precedence(token)) {
            _applyOp(values, ops.removeLast());
          }
          ops.add(token);
        }
      }
      while (ops.isNotEmpty) {
        _applyOp(values, ops.removeLast());
      }
      return values.length == 1 && values.first.isFinite ? values.first : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _tokenize(String expression) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    for (final char in expression.characters) {
      if ('+-*/'.contains(char)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }

  int _precedence(String op) => op == '+' || op == '-' ? 1 : 2;

  void _applyOp(List<double> values, String op) {
    if (values.length < 2) {
      throw StateError('Invalid expression');
    }
    final right = values.removeLast();
    final left = values.removeLast();
    values.add(switch (op) {
      '+' => left + right,
      '-' => left - right,
      '*' => left * right,
      '/' => right == 0 ? double.nan : left / right,
      _ => double.nan,
    });
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.expanded,
    required this.notesController,
    required this.date,
    required this.paymentMethod,
    required this.suggestedCategory,
    required this.onToggle,
    required this.onPickDate,
    required this.onPaymentMethodChanged,
    required this.onSuggestedCategorySelected,
  });

  final bool expanded;
  final TextEditingController notesController;
  final DateTime date;
  final String paymentMethod;
  final String? suggestedCategory;
  final VoidCallback onToggle;
  final VoidCallback onPickDate;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<String> onSuggestedCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  const Icon(Icons.tune_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(formatDate(date)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Cash', 'UPI', 'Card', 'Bank']
                    .map(
                      (method) => ChoiceChip(
                        selected: paymentMethod == method,
                        label: Text(method),
                        onSelected: (_) => onPaymentMethodChanged(method),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('transaction_notes'),
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional',
                ),
              ),
              if (suggestedCategory != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: Text('Use $suggestedCategory'),
                    onPressed: () =>
                        onSuggestedCategorySelected(suggestedCategory!),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onTap});

  final ValueChanged<String> onTap;

  String _displayForKey(String key) {
    return switch (key) {
      '*' => 'x',
      'clear' => 'C',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      '7',
      '8',
      '9',
      '/',
      '4',
      '5',
      '6',
      '*',
      '1',
      '2',
      '3',
      '-',
      '.',
      '0',
      'back',
      '+',
      'clear',
      '=',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.35,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        final isAction = '+-*/=clear'.contains(key) || key == 'back';
        return FilledButton.tonal(
          key: ValueKey('calculator_key_$key'),
          style: FilledButton.styleFrom(
            backgroundColor: isAction
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => onTap(key),
          child: key == 'back'
              ? const Icon(Icons.backspace_outlined)
              : Text(
                  _displayForKey(key),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
        );
      },
    );
  }
}
