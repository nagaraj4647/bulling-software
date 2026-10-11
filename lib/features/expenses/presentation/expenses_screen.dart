import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../providers/expense_provider.dart';
import '../models/expense_model.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedExpensesProvider);
    final filterState = ref.watch(expenseFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
            onPressed: () => context.go('/expenses/new'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
          ).animate().fade().scale(delay: 200.ms),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(
            context,
            ref,
            filterState,
            theme,
          ).animate().fade().slideY(begin: -0.1),
          Expanded(
            child: paginatedState.isLoading && paginatedState.expenses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SkeletonList(itemCount: 8),
                  )
                : paginatedState.error != null &&
                      paginatedState.expenses.isEmpty
                ? AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'Failed to load expenses',
                    subtitle: paginatedState.error.toString(),
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.read(paginatedExpensesProvider.notifier).refresh(),
                  ).animate().fade().scale()
                : paginatedState.expenses.isEmpty
                ? AppEmptyState(
                    icon: Icons.receipt_long,
                    title: 'No expenses found',
                    subtitle: 'Add your first expense to track outgoing costs',
                    actionLabel: 'Add Expense',
                    onAction: () => context.go('/expenses/new'),
                  ).animate().fade().scale()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(paginatedExpensesProvider.notifier).refresh(),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo is ScrollEndNotification &&
                            scrollInfo.metrics.extentAfter < 200 &&
                            paginatedState.hasMore &&
                            !paginatedState.isLoading) {
                          ref
                              .read(paginatedExpensesProvider.notifier)
                              .loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount:
                            paginatedState.expenses.length +
                            (paginatedState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= paginatedState.expenses.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SkeletonLoader(
                                height: 80,
                                borderRadius: 16,
                              ),
                            );
                          }

                          final expense = paginatedState.expenses[index];
                          return _buildExpenseTile(
                            context,
                            expense,
                            index,
                            theme,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width < 600
          ? FloatingActionButton(
              onPressed: () => context.go('/expenses/new'),
              tooltip: 'Add Expense',
              child: const Icon(Icons.add),
            ).animate().fade().scale(delay: 500.ms)
          : null,
    );
  }

  Widget _buildFilters(
    BuildContext context,
    WidgetRef ref,
    ExpenseFilterState filterState,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Status Filter
          DropdownMenu<ExpenseStatus?>(
            initialSelection: filterState.status,
            label: const Text('Status'),
            onSelected: (status) =>
                ref.read(expenseFilterProvider.notifier).setStatus(status),
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: null, label: 'All Status'),
              ...ExpenseStatus.values.map(
                (s) => DropdownMenuEntry(value: s, label: s.name.toUpperCase()),
              ),
            ],
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Category Filter
          DropdownMenu<ExpenseCategory?>(
            initialSelection: filterState.category,
            label: const Text('Category'),
            onSelected: (category) =>
                ref.read(expenseFilterProvider.notifier).setCategory(category),
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: null, label: 'All Categories'),
              ...ExpenseCategory.values.map(
                (c) => DropdownMenuEntry(value: c, label: c.name.toUpperCase()),
              ),
            ],
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(
    BuildContext context,
    ExpenseModel expense,
    int index,
    ThemeData theme,
  ) {
    IconData icon;
    Color color;

    switch (expense.status) {
      case ExpenseStatus.draft:
        icon = Icons.edit_document;
        color = AppTheme.warning;
        break;
      case ExpenseStatus.confirmed:
        icon = Icons.check_circle;
        color = AppTheme.success;
        break;
      case ExpenseStatus.cancelled:
        icon = Icons.cancel;
        color = AppTheme.error;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(30),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: color.withAlpha((255 * 0.1).toInt()),
            child: Icon(icon, color: color),
          ),
          title: Text(
            expense.category.name.toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              decoration: expense.status == ExpenseStatus.cancelled
                  ? TextDecoration.lineThrough
                  : null,
              color: expense.status == ExpenseStatus.cancelled
                  ? theme.colorScheme.outline
                  : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(expense.expenseDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${expense.amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: expense.status == ExpenseStatus.cancelled
                      ? theme.colorScheme.outline
                      : AppTheme.expensesColor,
                  decoration: expense.status == ExpenseStatus.cancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  expense.status.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          onTap: () => context.go('/expenses/${expense.expenseId}'),
        ),
      ),
    ).animate().fade().slideX(
      begin: 0.1,
      delay: Duration(milliseconds: (index * 30).clamp(0, 300)),
    );
  }
}
