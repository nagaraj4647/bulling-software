import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class CustomerOutstandingReportView extends ConsumerWidget {
  const CustomerOutstandingReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(reportCustomersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(reportCustomersProvider.notifier).refresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Outstanding Report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildContent(context, ref, customersState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    dynamic customersState,
  ) {
    if (customersState.isLoading && customersState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (customersState.error != null && customersState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${customersState.error}'),
        ),
      );
    }

    if (customersState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No customers found.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Opening Bal')),
              DataColumn(label: Text('Outstanding')),
              DataColumn(label: Text('Credit Limit')),
            ],
            rows: customersState.items.map<DataRow>((customer) {
              return DataRow(
                cells: [
                  DataCell(Text(customer.name)),
                  DataCell(
                    Text(
                      customer.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: customer.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  DataCell(
                    Text('₹${customer.openingBalance.toStringAsFixed(2)}'),
                  ),
                  DataCell(
                    Text(
                      '₹${customer.outstandingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text('₹${customer.creditLimit.toStringAsFixed(2)}')),
                ],
              );
            }).toList(),
          ),
        ),
        ReportPaginationFooter(
          hasMore: customersState.hasMore,
          isLoadingMore: customersState.isLoadingMore,
          totalLoaded: customersState.items.length,
          onLoadMore: () =>
              ref.read(reportCustomersProvider.notifier).loadMore(),
        ),
      ],
    );
  }
}
