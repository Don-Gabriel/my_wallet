import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/savings_goal.dart';
import '../../shared/error_handling.dart';
import '../../shared/formatters.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, required this.onSave, this.goal});

  final SavingsGoal? goal;
  final Future<void> Function(SavingsGoalDraft draft) onSave;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;
  late DateTime _deadline;
  var _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null ? '' : goal.targetAmount.toStringAsFixed(0),
    );
    _currentController = TextEditingController(
      text: goal == null ? '' : goal.currentAmount.toStringAsFixed(0),
    );
    _deadline = goal?.deadline ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
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
        SavingsGoalDraft(
          name: _nameController.text.trim(),
          targetAmount: double.parse(
            _targetController.text.trim().replaceAll(',', ''),
          ),
          currentAmount:
              double.tryParse(
                _currentController.text.trim().replaceAll(',', ''),
              ) ??
              0,
          deadline: _deadline,
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
    final title = widget.goal == null
        ? 'Add savings goal'
        : 'Edit savings goal';

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
                    Icons.savings_outlined,
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
                decoration: const InputDecoration(labelText: 'Goal name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Target amount',
                  prefixText: 'INR ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a target greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Current progress',
                  prefixText: 'INR ',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(formatDate(_deadline)),
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
                label: Text(widget.goal == null ? 'Save goal' : 'Update goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
