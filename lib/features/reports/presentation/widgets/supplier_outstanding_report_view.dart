import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class SupplierOutstandingReportView extends ConsumerWidget {
  const SupplierOutstandingReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersState = ref.watch(reportSuppliersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(reportSuppliersProvider.notifier).refresh();
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
                    'Supplier Outstanding Report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildContent(context, ref, suppliersState),
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
    dynamic suppliersState,
  ) {
    if (suppliersState.isLoading && suppliersState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (suppliersState.error != null && suppliersState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${suppliersState.error}'),
        ),
      );
    }

    if (suppliersState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No suppliers found.'),
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
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Opening Bal')),
              DataColumn(label: Text('Outstanding')),
            ],
            rows: suppliersState.items.map<DataRow>((supplier) {
              return DataRow(
                cells: [
                  DataCell(Text(supplier.name)),
                  DataCell(
                    Text(
                      supplier.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: supplier.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  DataCell(
                    Text('₹${supplier.openingBalance.toStringAsFixed(2)}'),
                  ),
                  DataCell(
                    Text(
                      '₹${supplier.outstandingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        ReportPaginationFooter(
          hasMore: suppliersState.hasMore,
          isLoadingMore: suppliersState.isLoadingMore,
          totalLoaded: suppliersState.items.length,
          onLoadMore: () =>
              ref.read(reportSuppliersProvider.notifier).loadMore(),
        ),
      ],
    );
  }
}
