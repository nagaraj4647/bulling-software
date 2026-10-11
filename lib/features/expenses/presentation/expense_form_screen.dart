import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/error_formatter.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../../business/providers/business_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? expenseId;

  const ExpenseFormScreen({super.key, this.expenseId});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  DateTime _expenseDate = DateTime.now();
  ExpenseCategory _category = ExpenseCategory.office;
  String _paymentMethod = 'Cash';

  bool _isInit = false;
  ExpenseModel? _editingExpense;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadExpense(List<ExpenseModel> expenses) {
    if (_isInit || widget.expenseId == null) return;

    try {
      _editingExpense = expenses.firstWhere(
        (e) => e.expenseId == widget.expenseId,
      );

      // Only drafts can be edited
      if (_editingExpense!.status != ExpenseStatus.draft) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only draft expenses can be edited')),
          );
          context.pop();
        });
        return;
      }

      _descriptionController.text = _editingExpense!.description;
      _amountController.text = _editingExpense!.amount.toString();
      _notesController.text = _editingExpense!.notes ?? '';
      _expenseDate = _editingExpense!.expenseDate;
      _category = _editingExpense!.category;
      _paymentMethod = _editingExpense!.paymentMethod;
      _isInit = true;
    } catch (_) {
      // Not found
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final business = ref.read(currentBusinessProvider).value;
      if (business == null) return;

      final isEditing = _editingExpense != null;
      final amount = double.parse(_amountController.text.trim());

      final ExpenseModel expense;

      if (isEditing) {
        expense = _editingExpense!.copyWith(
          expenseDate: _expenseDate,
          category: _category,
          description: _descriptionController.text.trim(),
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        expense = ExpenseModel(
          businessId: business.businessId!,
          expenseDate: _expenseDate,
          category: _category,
          description: _descriptionController.text.trim(),
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          status: ExpenseStatus.draft,
        );
      }

      final controller = ref.read(expenseControllerProvider.notifier);

      if (isEditing) {
        await controller.updateDraft(expense);
      } else {
        await controller.saveDraft(expense);
      }

      if (mounted) {
        final state = ref.read(expenseControllerProvider);
        if (!state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? 'Expense draft updated' : 'Expense draft created',
              ),
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorFormatter.format(state.error)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expenseId != null;

    if (isEditing) {
      final expensesState = ref.watch(paginatedExpensesProvider);
      _loadExpense(expensesState.expenses);

      if (!_isInit && expensesState.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    final controllerState = ref.watch(expenseControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense Draft' : 'Add Expense Draft'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expense Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_expenseDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<ExpenseCategory>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                initialValue: _category,
                items: ExpenseCategory.values.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final num = double.tryParse(val.trim());
                  if (num == null) return 'Enter a valid number';
                  if (num <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Method Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                initialValue: _paymentMethod,
                items: ['Cash', 'UPI', 'Card', 'Bank', 'Other'].map((pm) {
                  return DropdownMenuItem(value: pm, child: Text(pm));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              FilledButton(
                onPressed: controllerState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: controllerState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
