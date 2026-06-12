import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as picker;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../data/wallet_repository.dart';
import '../../models/bill_reminder.dart';
import '../../models/budget.dart';
import '../../models/category_budget.dart';
import '../../models/recurring_transaction.dart';
import '../../models/savings_goal.dart';
import '../../models/transaction.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_summary.dart';
import '../../models/wallet_user.dart';
import '../../shared/backup_tools.dart';
import '../../shared/common_widgets.dart';
import '../../shared/csv_tools.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';
import '../../security/security_controller.dart';
import '../../security/security_scope.dart';
import 'wallet_form_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final WalletRepository repository;
  final WalletUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _categoryController = TextEditingController();
  var _isAddingCategory = false;
  var _isDeletingData = false;

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      return;
    }

    setState(() => _isAddingCategory = true);
    try {
      await widget.repository.addCategory(widget.user, category);
      _categoryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category added')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingCategory = false);
      }
    }
  }

  Future<void> _deleteCategory(String category) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete category?',
      message: 'Existing transactions keep their category name.',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteCategory(widget.user, category);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openWalletSheet({WalletAccount? wallet}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WalletFormSheet(
        wallet: wallet,
        onSave: (draft) {
          if (wallet == null) {
            return widget.repository.addWallet(widget.user, draft);
          }
          return widget.repository.updateWallet(widget.user, wallet, draft);
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wallet == null ? 'Wallet saved' : 'Wallet updated'),
        ),
      );
    }
  }

  Future<void> _deleteWallet(WalletAccount wallet) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete wallet?',
      message: 'Transactions already saved to this wallet are not deleted.',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteWallet(widget.user, wallet);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wallet deleted')));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _saveTextFile({
    required String name,
    required String extension,
    required MimeType mimeType,
    required String content,
    required String successMessage,
  }) async {
    try {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: extension,
        mimeType: mimeType,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _saveCsv(
    List<WalletTransaction> transactions,
    List<WalletAccount> wallets,
  ) async {
    await _saveTextFile(
      name: 'mywallet-transactions-${_dateStamp()}',
      extension: 'csv',
      mimeType: MimeType.csv,
      content: transactionsToCsv(transactions, wallets),
      successMessage: 'CSV file saved',
    );
  }

  Future<void> _saveBackup(WalletBackup backup) async {
    await _saveTextFile(
      name: 'mywallet-backup-${_dateStamp()}',
      extension: 'mywallet',
      mimeType: MimeType.json,
      content: walletBackupToJson(backup),
      successMessage: 'Backup file saved',
    );
  }

  Future<void> _saveMonthlyReport(List<WalletTransaction> transactions) async {
    final summary = WalletSummary.fromTransactions(
      transactions,
      DateTime.now(),
    );
    final report = StringBuffer()
      ..writeln('MyWallet monthly report')
      ..writeln('Income: ${formatMoney(summary.monthlyIncome)}')
      ..writeln('Expense: ${formatMoney(summary.monthlyExpense)}')
      ..writeln(
        'Savings: ${formatMoney(summary.monthlyIncome - summary.monthlyExpense, signed: true)}',
      )
      ..writeln('Savings rate: ${(summary.savingsRate * 100).round()}%')
      ..writeln('Top category: ${summary.topCategory}');
    await _saveTextFile(
      name: 'mywallet-monthly-report-${_dateStamp()}',
      extension: 'txt',
      mimeType: MimeType.text,
      content: report.toString(),
      successMessage: 'Monthly report saved',
    );
  }

  Future<void> _openImportFile(
    List<String> categories,
    List<WalletAccount> wallets,
  ) async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        return;
      }
      await _openImportSheet(
        categories,
        wallets,
        initialText: utf8.decode(bytes, allowMalformed: true),
      );
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openBackupFile() async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: const ['mywallet', 'json'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        return;
      }
      final backup = walletBackupFromJson(
        utf8.decode(bytes, allowMalformed: true),
      );
      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Restore backup?'),
            content: Text(
              'This will merge ${backup.itemCount} saved items into this wallet. Matching items are updated.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await widget.repository.restoreBackup(widget.user, backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored ${backup.itemCount} items')),
        );
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  String _dateStamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _openProfileSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProfileSheet(
        currentName: widget.user.displayName ?? '',
        onSave: widget.repository.updateDisplayName,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _openPasswordSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _PasswordUpdateSheet(onSave: widget.repository.updatePassword),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  Future<void> _openImportSheet(
    List<String> categories,
    List<WalletAccount> wallets, {
    String initialText = '',
  }) async {
    final imported = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ImportCsvSheet(
        categories: categories,
        wallets: wallets,
        initialText: initialText,
        onImport: (drafts) async {
          for (final draft in drafts) {
            await widget.repository.addTransaction(widget.user, draft);
          }
        },
      ),
    );

    if (imported != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported transactions')),
      );
    }
  }

  Future<void> _deleteWalletData() async {
    if (!mounted) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: 'Delete wallet data?',
      message: 'This removes your cloud wallet data permanently.',
    );
    if (!confirmed) {
      return;
    }

    setState(() => _isDeletingData = true);
    try {
      await widget.repository.deleteWalletData(widget.user);
      await widget.repository.signOut();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingData = false);
      }
    }
  }

  Future<void> _resetLocalSettings() async {
    if (!mounted) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: 'Reset local settings?',
      message: 'This clears hidden amounts and local privacy preferences.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await SecurityScope.of(context).resetLocalSettings();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local settings reset')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Appearance',
                icon: Icons.contrast_outlined,
                compact: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThemeChip(
                      label: 'Auto',
                      icon: Icons.brightness_auto_outlined,
                      value: ThemeMode.system,
                      current: widget.themeMode,
                      onSelected: widget.onThemeModeChanged,
                    ),
                    _ThemeChip(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      value: ThemeMode.light,
                      current: widget.themeMode,
                      onSelected: widget.onThemeModeChanged,
                    ),
                    _ThemeChip(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      value: ThemeMode.dark,
                      current: widget.themeMode,
                      onSelected: widget.onThemeModeChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SecuritySection(controller: SecurityScope.of(context)),
              const SizedBox(height: 12),
              StreamBuilder<List<WalletAccount>>(
                stream: widget.repository.watchWallets(widget.user),
                builder: (context, walletSnapshot) {
                  return StreamBuilder<List<WalletTransaction>>(
                    stream: widget.repository.watchTransactions(widget.user),
                    builder: (context, transactionSnapshot) {
                      return _WalletsSection(
                        wallets:
                            walletSnapshot.data ??
                            [WalletAccount.defaultAccount()],
                        transactions:
                            transactionSnapshot.data ??
                            const <WalletTransaction>[],
                        isLoading:
                            walletSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            walletSnapshot.data == null,
                        error: walletSnapshot.error,
                        onAdd: () => _openWalletSheet(),
                        onEdit: (wallet) => _openWalletSheet(wallet: wallet),
                        onDelete: _deleteWallet,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              _CategoriesSection(
                repository: widget.repository,
                user: widget.user,
                controller: _categoryController,
                isAdding: _isAddingCategory,
                onAdd: _addCategory,
                onDelete: _deleteCategory,
              ),
              const SizedBox(height: 12),
              _DataToolsStream(
                repository: widget.repository,
                user: widget.user,
                onExport: _saveCsv,
                onImport: _openImportSheet,
                onImportFile: _openImportFile,
                onBackup: _saveBackup,
                onRestoreBackup: _openBackupFile,
                onMonthlyReport: _saveMonthlyReport,
              ),
              const SizedBox(height: 12),
              _AccountSection(
                user: widget.user,
                onEditProfile: _openProfileSheet,
                onChangePassword: _openPasswordSheet,
                onSignOut: widget.repository.signOut,
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Data privacy',
                icon: Icons.security_outlined,
                compact: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your financial data is private to this account. Receipt image uploads are not enabled.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isDeletingData ? null : _deleteWalletData,
                      icon: _isDeletingData
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('Delete cloud data'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _resetLocalSettings,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Delete local settings'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _AboutSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.controller});

  final SecuritySettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SectionCard(
          title: 'Privacy',
          icon: Icons.privacy_tip_outlined,
          compact: true,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.hideAmounts,
                title: const Text('Hide amounts'),
                subtitle: const Text('Mask balances and transaction amounts'),
                onChanged: controller.setHideAmounts,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.privacyScreenEnabled,
                title: const Text('Privacy screen'),
                subtitle: const Text('Hide app preview and screenshots'),
                onChanged: controller.setPrivacyScreenEnabled,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletsSection extends StatelessWidget {
  const _WalletsSection({
    required this.wallets,
    required this.transactions,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.error,
  });

  final List<WalletAccount> wallets;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final Object? error;
  final VoidCallback onAdd;
  final ValueChanged<WalletAccount> onEdit;
  final ValueChanged<WalletAccount> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Wallets',
      icon: Icons.account_balance_wallet_outlined,
      action: IconButton(
        tooltip: 'Add wallet',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorState(
              title: 'Wallets unavailable',
              message: friendlyErrorMessage(error!),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wallets.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                final balance =
                    wallet.openingBalance +
                    transactions.fold<double>(
                      0,
                      (total, transaction) =>
                          total + transaction.impactForWallet(wallet.id),
                    );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(wallet.name),
                  subtitle: Text(formatMoney(balance)),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Wallet actions',
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(wallet);
                      }
                      if (value == 'delete') {
                        onDelete(wallet);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (wallet.id != defaultWalletId)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.repository,
    required this.user,
    required this.controller,
    required this.isAdding,
    required this.onAdd,
    required this.onDelete,
  });

  final WalletRepository repository;
  final WalletUser user;
  final TextEditingController controller;
  final bool isAdding;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Categories',
      icon: Icons.category_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'New category'),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add category',
                onPressed: isAdding ? null : onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<String>>(
            stream: repository.watchCategories(user),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <String>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  categories.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && categories.isEmpty) {
                return ErrorState(
                  title: 'Categories unavailable',
                  message: friendlyErrorMessage(snapshot.error!),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (category) => InputChip(
                        label: Text(category),
                        onDeleted: () => onDelete(category),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DataToolsStream extends StatelessWidget {
  const _DataToolsStream({
    required this.repository,
    required this.user,
    required this.onExport,
    required this.onImport,
    required this.onImportFile,
    required this.onBackup,
    required this.onRestoreBackup,
    required this.onMonthlyReport,
  });

  final WalletRepository repository;
  final WalletUser user;
  final void Function(
    List<WalletTransaction> transactions,
    List<WalletAccount> wallets,
  )
  onExport;
  final void Function(List<String> categories, List<WalletAccount> wallets)
  onImport;
  final void Function(List<String> categories, List<WalletAccount> wallets)
  onImportFile;
  final ValueChanged<WalletBackup> onBackup;
  final VoidCallback onRestoreBackup;
  final ValueChanged<List<WalletTransaction>> onMonthlyReport;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WalletTransaction>>(
      stream: repository.watchTransactions(user),
      builder: (context, transactionSnapshot) {
        return StreamBuilder<List<String>>(
          stream: repository.watchCategories(user),
          builder: (context, categorySnapshot) {
            return StreamBuilder<List<WalletAccount>>(
              stream: repository.watchWallets(user),
              builder: (context, walletSnapshot) {
                return StreamBuilder<WalletBudget>(
                  stream: repository.watchBudget(user),
                  builder: (context, budgetSnapshot) {
                    return StreamBuilder<List<CategoryBudget>>(
                      stream: repository.watchCategoryBudgets(user),
                      builder: (context, categoryBudgetSnapshot) {
                        return StreamBuilder<List<SavingsGoal>>(
                          stream: repository.watchGoals(user),
                          builder: (context, goalSnapshot) {
                            return StreamBuilder<List<BillReminder>>(
                              stream: repository.watchBillReminders(user),
                              builder: (context, billSnapshot) {
                                return StreamBuilder<
                                  List<RecurringTransaction>
                                >(
                                  stream: repository.watchRecurringTransactions(
                                    user,
                                  ),
                                  builder: (context, recurringSnapshot) {
                                    final transactions =
                                        transactionSnapshot.data ??
                                        const <WalletTransaction>[];
                                    final categories =
                                        categorySnapshot.data ??
                                        defaultCategories;
                                    final wallets =
                                        walletSnapshot.data ??
                                        [WalletAccount.defaultAccount()];
                                    final backup = WalletBackup(
                                      exportedAt: DateTime.now(),
                                      categories: categories,
                                      wallets: wallets,
                                      transactions: transactions,
                                      budget:
                                          budgetSnapshot.data ??
                                          const WalletBudget(monthlyLimit: 0),
                                      categoryBudgets:
                                          categoryBudgetSnapshot.data ??
                                          const <CategoryBudget>[],
                                      goals:
                                          goalSnapshot.data ??
                                          const <SavingsGoal>[],
                                      bills:
                                          billSnapshot.data ??
                                          const <BillReminder>[],
                                      recurring:
                                          recurringSnapshot.data ??
                                          const <RecurringTransaction>[],
                                    );

                                    return _DataToolsSection(
                                      transactions: transactions,
                                      categories: categories,
                                      wallets: wallets,
                                      backup: backup,
                                      onExport: () =>
                                          onExport(transactions, wallets),
                                      onImport: () =>
                                          onImport(categories, wallets),
                                      onImportFile: () =>
                                          onImportFile(categories, wallets),
                                      onBackup: () => onBackup(backup),
                                      onRestoreBackup: onRestoreBackup,
                                      onMonthlyReport: () =>
                                          onMonthlyReport(transactions),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DataToolsSection extends StatelessWidget {
  const _DataToolsSection({
    required this.transactions,
    required this.categories,
    required this.wallets,
    required this.backup,
    required this.onExport,
    required this.onImport,
    required this.onImportFile,
    required this.onBackup,
    required this.onRestoreBackup,
    required this.onMonthlyReport,
  });

  final List<WalletTransaction> transactions;
  final List<String> categories;
  final List<WalletAccount> wallets;
  final WalletBackup backup;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onImportFile;
  final VoidCallback onBackup;
  final VoidCallback onRestoreBackup;
  final VoidCallback onMonthlyReport;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Data tools',
      icon: Icons.import_export_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${transactions.length} transactions, ${categories.length} categories, ${wallets.length} wallets, ${backup.itemCount} backup items.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cloud sync is automatic when you are online. Offline changes save locally and sync when the connection returns.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'If two devices edit the same item, the latest saved change is kept.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Save backup'),
              ),
              OutlinedButton.icon(
                onPressed: onRestoreBackup,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restore backup'),
              ),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Save CSV'),
              ),
              OutlinedButton.icon(
                onPressed: onImportFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Restore CSV'),
              ),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('Paste CSV'),
              ),
              OutlinedButton.icon(
                onPressed: onMonthlyReport,
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('Save report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.user,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onSignOut,
  });

  final WalletUser user;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Account',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            user.label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            user.isAnonymous
                ? 'Anonymous mode'
                : '${user.email ?? 'Signed in'} - ${user.emailVerified ? 'verified' : 'not verified'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: user.isAnonymous ? null : onEditProfile,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Edit profile'),
              ),
              OutlinedButton.icon(
                onPressed: user.isAnonymous ? null : onChangePassword,
                icon: const Icon(Icons.password_outlined),
                label: const Text('Change password'),
              ),
              TextButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.currentName, required this.onSave});

  final String currentName;
  final Future<void> Function(String name) onSave;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
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
      await widget.onSave(_controller.text.trim());
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
            Text(
              'Edit profile',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter your name';
                }
                return null;
              },
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
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordUpdateSheet extends StatefulWidget {
  const _PasswordUpdateSheet({required this.onSave});

  final Future<void> Function(String password) onSave;

  @override
  State<_PasswordUpdateSheet> createState() => _PasswordUpdateSheetState();
}

class _PasswordUpdateSheetState extends State<_PasswordUpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  var _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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
      await widget.onSave(_controller.text);
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
            Text(
              'Change password',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.password_outlined),
              ),
              validator: (value) {
                final password = value ?? '';
                if (password.length < 8) {
                  return 'Use at least 8 characters';
                }
                if (!RegExp('[A-Z]').hasMatch(password) ||
                    !RegExp('[a-z]').hasMatch(password) ||
                    !RegExp(r'\d').hasMatch(password)) {
                  return 'Use uppercase, lowercase, and a number';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Avoid passwords you have used before. Firebase requires a recent sign-in for this change.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              label: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportCsvSheet extends StatefulWidget {
  const _ImportCsvSheet({
    required this.categories,
    required this.wallets,
    required this.initialText,
    required this.onImport,
  });

  final List<String> categories;
  final List<WalletAccount> wallets;
  final String initialText;
  final Future<void> Function(List<TransactionDraft> drafts) onImport;

  @override
  State<_ImportCsvSheet> createState() => _ImportCsvSheetState();
}

class _ImportCsvSheetState extends State<_ImportCsvSheet> {
  late final TextEditingController _controller;
  var _isImporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final result = parseTransactionsCsv(
      _controller.text,
      categories: widget.categories,
      wallets: widget.wallets,
    );
    if (result.drafts.isEmpty) {
      setState(
        () => _error = 'Paste CSV rows with date, type, category, amount.',
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      await widget.onImport(result.drafts);
      if (mounted) {
        Navigator.of(context).pop(result.drafts.length);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = parseTransactionsCsv(
      _controller.text,
      categories: widget.categories,
      wallets: widget.wallets,
    );

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
            Row(
              children: [
                Icon(
                  Icons.upload_file_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Import CSV',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'CSV data',
                hintText:
                    'date,type,category,amount,notes,paymentMethod,wallet',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text(
              '${preview.drafts.length} ready'
              '${preview.skippedRows == 0 ? '' : ', ${preview.skippedRows} skipped'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (preview.drafts.isNotEmpty) ...[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: preview.drafts.take(5).map((draft) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${draft.category} - ${formatDate(draft.date)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(formatMoney(draft.amount)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isImporting ? null : _import,
              icon: _isImporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Import transactions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final subtleStyle = textStyle?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return SectionCard(
      title: 'About',
      icon: Icons.info_outline,
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MyWallet',
            style: textStyle?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('Version 2.0.0', style: subtleStyle),
          const SizedBox(height: 12),
          Text(
            'Privacy policy: your financial data is used only for wallet features, sync, backups, and reports. It is not sold, shared for advertising, or used outside the app experience.',
            style: subtleStyle,
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: current == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => onSelected(value),
    );
  }
}
