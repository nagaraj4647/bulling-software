import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class ExpenseReportView extends ConsumerWidget {
  const ExpenseReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(expenseReportSummaryProvider);
    final expenseState = ref.watch(reportExpensesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(expenseReportSummaryProvider);
        await ref.read(reportExpensesProvider.notifier).refresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: summaryAsync.when(
              data: (summary) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _SummaryCard(
                      title: 'Total Expenses',
                      value: '₹${summary.totalExpenses.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 16),
                    if (summary.categoryTotals.isNotEmpty) ...[
                      Text(
                        'Category-wise Totals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: summary.categoryTotals.entries.map((e) {
                          return Chip(
                            label: Text(
                              '${e.key}: ₹${e.value.toStringAsFixed(2)}',
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildDetailsSection(context, ref, expenseState),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    dynamic expenseState,
  ) {
    if (expenseState.isLoading && expenseState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (expenseState.error != null && expenseState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${expenseState.error}'),
        ),
      );
    }

    if (expenseState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No data found for this date range.'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Expenses',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Amount')),
              ],
              rows: expenseState.items.map<DataRow>((expense) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('dd MMM yyyy').format(expense.expenseDate),
                      ),
                    ),
                    DataCell(Text(expense.category.name)),
                    DataCell(Text(expense.description)),
                    DataCell(Text('₹${expense.amount.toStringAsFixed(2)}')),
                  ],
                );
              }).toList(),
            ),
          ),
          ReportPaginationFooter(
            hasMore: expenseState.hasMore,
            isLoadingMore: expenseState.isLoadingMore,
            totalLoaded: expenseState.items.length,
            onLoadMore: () =>
                ref.read(reportExpensesProvider.notifier).loadMore(),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
