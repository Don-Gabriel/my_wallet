import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bill_reminder.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';

class BillFormSheet extends StatefulWidget {
  const BillFormSheet({
    super.key,
    required this.categories,
    required this.onSave,
    this.reminder,
  });

  final List<String> categories;
  final BillReminder? reminder;
  final Future<void> Function(BillReminderDraft draft) onSave;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _category;
  late DateTime _dueDate;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _nameController = TextEditingController(text: reminder?.name ?? '');
    _amountController = TextEditingController(
      text: reminder == null ? '' : reminder.amount.toStringAsFixed(0),
    );
    _category = _categoryOrDefault(reminder?.category);
    _dueDate = reminder?.dueDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
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
        BillReminderDraft(
          name: _nameController.text.trim(),
          amount: double.parse(
            _amountController.text.trim().replaceAll(',', ''),
          ),
          category: _category,
          dueDate: _dueDate,
          isPaid: widget.reminder?.isPaid ?? false,
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
    final title = widget.reminder == null ? 'Add bill' : 'Edit bill';

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
                    Icons.event_note_outlined,
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
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Bill name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a bill name';
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(formatDate(_dueDate)),
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
                label: Text(widget.reminder == null ? 'Save bill' : 'Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _preferredCategory {
    if (widget.categories.contains('Bills')) {
      return 'Bills';
    }
    if (widget.categories.isEmpty) {
      return 'Bills';
    }
    return widget.categories.first;
  }

  String _categoryOrDefault(String? category) {
    if (category != null && widget.categories.contains(category)) {
      return category;
    }
    return _preferredCategory;
  }
}
