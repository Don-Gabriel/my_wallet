import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_user.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';
import 'transaction_tile.dart';

enum TransactionPeriodFilter { all, currentMonth, income, expense }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.onEditTransaction,
    required this.onDuplicateTransaction,
    required this.onRefundTransaction,
    required this.onSplitTransaction,
    required this.onMakeRecurring,
  });

  final WalletRepository repository;
  final WalletUser user;
  final ValueChanged<WalletTransaction> onEditTransaction;
  final ValueChanged<WalletTransaction> onDuplicateTransaction;
  final ValueChanged<WalletTransaction> onRefundTransaction;
  final ValueChanged<WalletTransaction> onSplitTransaction;
  final ValueChanged<WalletTransaction> onMakeRecurring;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  var _periodFilter = TransactionPeriodFilter.all;
  String? _categoryFilter;
  String? _walletFilter;
  String? _paymentMethodFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  List<WalletTransaction> _filtered(
    List<WalletTransaction> transactions,
    List<WalletAccount> wallets,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final minAmount = double.tryParse(_minAmountController.text.trim());
    final maxAmount = double.tryParse(_maxAmountController.text.trim());
    final walletNames = {for (final wallet in wallets) wallet.id: wallet.name};

    return transactions.where((transaction) {
      final matchesQuery =
          query.isEmpty ||
          transaction.category.toLowerCase().contains(query) ||
          transaction.notes.toLowerCase().contains(query) ||
          transaction.paymentMethod.toLowerCase().contains(query) ||
          (walletNames[transaction.walletId] ?? '').toLowerCase().contains(
            query,
          ) ||
          transaction.type.label.toLowerCase().contains(query) ||
          transaction.amount.toStringAsFixed(0).contains(query);
      final matchesPeriod = switch (_periodFilter) {
        TransactionPeriodFilter.all => true,
        TransactionPeriodFilter.currentMonth => isSameMonth(
          transaction.date,
          now,
        ),
        TransactionPeriodFilter.income =>
          transaction.type == WalletTransactionType.income ||
              transaction.type == WalletTransactionType.refund,
        TransactionPeriodFilter.expense =>
          transaction.type == WalletTransactionType.expense,
      };
      final matchesCategory =
          _categoryFilter == null || transaction.category == _categoryFilter;
      final matchesWallet =
          _walletFilter == null || transaction.walletId == _walletFilter;
      final matchesPayment =
          _paymentMethodFilter == null ||
          transaction.paymentMethod == _paymentMethodFilter;
      final matchesAmount =
          (minAmount == null || transaction.amount >= minAmount) &&
          (maxAmount == null || transaction.amount <= maxAmount);
      final matchesDateRange =
          (_startDate == null ||
              !transaction.date.isBefore(_dateOnly(_startDate!))) &&
          (_endDate == null ||
              !transaction.date.isAfter(
                _dateOnly(_endDate!).add(const Duration(days: 1)),
              ));

      return matchesQuery &&
          matchesPeriod &&
          matchesCategory &&
          matchesWallet &&
          matchesPayment &&
          matchesAmount &&
          matchesDateRange;
    }).toList();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _clearAdvancedFilters() {
    setState(() {
      _categoryFilter = null;
      _walletFilter = null;
      _paymentMethodFilter = null;
      _startDate = null;
      _endDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  Future<void> _openFiltersSheet(
    List<String> categories,
    List<WalletAccount> wallets,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            void update(VoidCallback action) {
              setState(action);
              sheetSetState(() {});
            }

            return _AdvancedFiltersSheet(
              categories: categories,
              wallets: wallets,
              category: _categoryFilter,
              walletId: _walletFilter,
              paymentMethod: _paymentMethodFilter,
              startDate: _startDate,
              endDate: _endDate,
              minAmountController: _minAmountController,
              maxAmountController: _maxAmountController,
              onCategoryChanged: (category) =>
                  update(() => _categoryFilter = category),
              onWalletChanged: (walletId) =>
                  update(() => _walletFilter = walletId),
              onPaymentMethodChanged: (paymentMethod) =>
                  update(() => _paymentMethodFilter = paymentMethod),
              onAmountChanged: () => update(() {}),
              onStartDate: () async {
                await _pickStartDate();
                sheetSetState(() {});
              },
              onEndDate: () async {
                await _pickEndDate();
                sheetSetState(() {});
              },
              onClear: () {
                _clearAdvancedFilters();
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTransaction(WalletTransaction transaction) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete transaction?',
      message: 'This removes the transaction permanently.',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteTransaction(widget.user, transaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _restoreDeletedTransaction(transaction),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _restoreDeletedTransaction(WalletTransaction transaction) async {
    try {
      await widget.repository.addTransaction(
        widget.user,
        TransactionDraft.fromTransaction(transaction),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction restored')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WalletTransaction>>(
      stream: widget.repository.watchTransactions(widget.user),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? const <WalletTransaction>[];

        return StreamBuilder<List<String>>(
          stream: widget.repository.watchCategories(widget.user),
          builder: (context, categorySnapshot) {
            final categories = categorySnapshot.data ?? defaultCategories;
            return StreamBuilder<List<WalletAccount>>(
              stream: widget.repository.watchWallets(widget.user),
              builder: (context, walletSnapshot) {
                final wallets =
                    walletSnapshot.data ?? [WalletAccount.defaultAccount()];
                final filtered = _filtered(transactions, wallets);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Search transactions',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                tooltip: 'Filters',
                                onPressed: () =>
                                    _openFiltersSheet(categories, wallets),
                                icon: const Icon(Icons.tune_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'All',
                                icon: Icons.list,
                                value: TransactionPeriodFilter.all,
                                selected: _periodFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'Month',
                                icon: Icons.calendar_month,
                                value: TransactionPeriodFilter.currentMonth,
                                selected: _periodFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'Income',
                                icon: Icons.arrow_upward,
                                value: TransactionPeriodFilter.income,
                                selected: _periodFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'Expense',
                                icon: Icons.arrow_downward,
                                value: TransactionPeriodFilter.expense,
                                selected: _periodFilter,
                                onSelected: _setFilter,
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.tune_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _advancedFilterCount == 0
                                      ? 'Filters'
                                      : 'Filters ($_advancedFilterCount)',
                                ),
                                onPressed: () =>
                                    _openFiltersSheet(categories, wallets),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            title: 'Transactions',
                            icon: Icons.receipt_long_outlined,
                            child:
                                snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    transactions.isEmpty
                                ? const LoadingSkeletonList()
                                : snapshot.hasError
                                ? ErrorState(
                                    title: 'Transactions unavailable',
                                    message: friendlyErrorMessage(
                                      snapshot.error!,
                                    ),
                                  )
                                : filtered.isEmpty
                                ? EmptyState(
                                    icon: Icons.search_off_outlined,
                                    title: 'No matching transactions',
                                    action: _advancedFilterCount > 0
                                        ? TextButton.icon(
                                            onPressed: _clearAdvancedFilters,
                                            icon: const Icon(Icons.clear),
                                            label: const Text('Clear filters'),
                                          )
                                        : null,
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filtered.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final transaction = filtered[index];
                                      return TransactionTile(
                                        transaction: transaction,
                                        onEdit: () => widget.onEditTransaction(
                                          transaction,
                                        ),
                                        onDuplicate: () =>
                                            widget.onDuplicateTransaction(
                                              transaction,
                                            ),
                                        onRefund: () => widget
                                            .onRefundTransaction(transaction),
                                        onSplit: () => widget
                                            .onSplitTransaction(transaction),
                                        onMakeRecurring: () =>
                                            widget.onMakeRecurring(transaction),
                                        onDelete: () =>
                                            _deleteTransaction(transaction),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _setFilter(TransactionPeriodFilter filter) {
    setState(() => _periodFilter = filter);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int get _advancedFilterCount {
    return [
      _categoryFilter,
      _walletFilter,
      _paymentMethodFilter,
      _startDate,
      _endDate,
      _minAmountController.text.trim().isEmpty ? null : 'min',
      _maxAmountController.text.trim().isEmpty ? null : 'max',
    ].where((value) => value != null).length;
  }
}

class _AdvancedFiltersSheet extends StatelessWidget {
  const _AdvancedFiltersSheet({
    required this.categories,
    required this.wallets,
    required this.category,
    required this.walletId,
    required this.paymentMethod,
    required this.startDate,
    required this.endDate,
    required this.minAmountController,
    required this.maxAmountController,
    required this.onCategoryChanged,
    required this.onWalletChanged,
    required this.onPaymentMethodChanged,
    required this.onAmountChanged,
    required this.onStartDate,
    required this.onEndDate,
    required this.onClear,
  });

  final List<String> categories;
  final List<WalletAccount> wallets;
  final String? category;
  final String? walletId;
  final String? paymentMethod;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final VoidCallback onAmountChanged;
  final VoidCallback onStartDate;
  final VoidCallback onEndDate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const paymentMethods = ['Cash', 'UPI', 'Card', 'Bank'];
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...categories.map(
                  (item) =>
                      DropdownMenuItem<String?>(value: item, child: Text(item)),
                ),
              ],
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: walletId,
              decoration: const InputDecoration(labelText: 'Wallet'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All wallets'),
                ),
                ...wallets.map(
                  (wallet) => DropdownMenuItem<String?>(
                    value: wallet.id,
                    child: Text(wallet.name),
                  ),
                ),
              ],
              onChanged: onWalletChanged,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Any method'),
                ),
                ...paymentMethods.map(
                  (method) => DropdownMenuItem<String?>(
                    value: method,
                    child: Text(method),
                  ),
                ),
              ],
              onChanged: onPaymentMethodChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min amount'),
                    onChanged: (_) => onAmountChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: maxAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max amount'),
                    onChanged: (_) => onAmountChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStartDate,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      startDate == null ? 'From' : formatDate(startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEndDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(endDate == null ? 'To' : formatDate(endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final TransactionPeriodFilter value;
  final TransactionPeriodFilter selected;
  final ValueChanged<TransactionPeriodFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => onSelected(value),
    );
  }
}
