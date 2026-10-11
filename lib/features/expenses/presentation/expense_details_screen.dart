import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/error_formatter.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpenseDetailsScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailsScreen({super.key, required this.expenseId});

  void _confirmExpense(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Expense'),
        content: const Text(
          'Are you sure you want to confirm this expense? Once confirmed, the financial details cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(expenseControllerProvider.notifier)
                  .confirmExpense(expenseId)
                  .then((_) {
                    if (context.mounted) {
                      final state = ref.read(expenseControllerProvider);
                      if (!state.hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense confirmed')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ErrorFormatter.format(state.error)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  });
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _cancelExpense(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Expense'),
        content: const Text(
          'Are you sure you want to cancel this expense? This action will reverse its financial effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(expenseControllerProvider.notifier)
                  .cancelExpense(expenseId)
                  .then((_) {
                    if (context.mounted) {
                      final state = ref.read(expenseControllerProvider);
                      if (!state.hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense cancelled')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ErrorFormatter.format(state.error)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Expense'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedExpensesProvider);
    final controllerState = ref.watch(expenseControllerProvider);

    ExpenseModel? expense;
    try {
      expense = paginatedState.expenses.firstWhere(
        (e) => e.expenseId == expenseId,
      );
    } catch (_) {}

    if (expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Details')),
        body: const Center(child: Text('Expense not found')),
      );
    }

    final isDraft = expense.status == ExpenseStatus.draft;
    final isConfirmed = expense.status == ExpenseStatus.confirmed;
    final isCancelled = expense.status == ExpenseStatus.cancelled;

    Color statusColor;
    if (isDraft) {
      statusColor = Colors.orange;
    } else if (isConfirmed) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (isDraft)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Draft',
              onPressed: () => context.go('/expenses/edit/$expenseId'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controllerState.isLoading) const LinearProgressIndicator(),

            // Status Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withAlpha((255 * 0.3).toInt()),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDraft
                        ? Icons.edit_document
                        : isConfirmed
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: statusColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    expense.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      context,
                      'Category',
                      expense.category.name.toUpperCase(),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      'Date',
                      DateFormat('dd MMM yyyy').format(expense.expenseDate),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      'Description',
                      expense.description,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      'Amount',
                      '₹${expense.amount.toStringAsFixed(2)}',
                      isAmount: true,
                      isCancelled: isCancelled,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      context,
                      'Payment Method',
                      expense.paymentMethod,
                    ),
                    if (expense.notes?.isNotEmpty == true) ...[
                      const Divider(),
                      _buildDetailRow(context, 'Notes', expense.notes!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (isDraft) ...[
              FilledButton.icon(
                onPressed: () => _confirmExpense(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('Confirm Expense'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _cancelExpense(context, ref),
                icon: const Icon(Icons.close),
                label: const Text('Cancel Draft'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else if (isConfirmed) ...[
              OutlinedButton.icon(
                onPressed: () => _cancelExpense(context, ref),
                icon: const Icon(Icons.close),
                label: const Text('Cancel Expense'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
    bool isCancelled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
                color: isCancelled && isAmount ? Colors.grey : null,
                decoration: isCancelled && isAmount
                    ? TextDecoration.lineThrough
                    : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
