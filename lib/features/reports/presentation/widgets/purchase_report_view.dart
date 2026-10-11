import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class PurchaseReportView extends ConsumerWidget {
  const PurchaseReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(purchaseReportSummaryProvider);
    final purchaseState = ref.watch(reportPurchasesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(purchaseReportSummaryProvider);
        await ref.read(reportPurchasesProvider.notifier).refresh();
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
                      'Purchases Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Purchases',
                            value:
                                '₹${summary.totalPurchases.toStringAsFixed(2)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Purchases',
                            value: '${summary.purchaseCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Tax',
                            value: '₹${summary.taxTotal.toStringAsFixed(2)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Discounts',
                            value:
                                '₹${summary.discountTotal.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
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
            child: _buildDetailsSection(context, ref, purchaseState),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    dynamic purchaseState,
  ) {
    if (purchaseState.isLoading && purchaseState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (purchaseState.error != null && purchaseState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${purchaseState.error}'),
        ),
      );
    }

    if (purchaseState.items.isEmpty) {
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
            'Detailed Purchases',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Purchase #')),
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Total')),
              ],
              rows: purchaseState.items.map<DataRow>((purchase) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('dd MMM yyyy')
                            .format(purchase.createdAt ?? DateTime.now()),
                      ),
                    ),
                    DataCell(Text(purchase.purchaseNumber)),
                    DataCell(
                      Text(purchase.supplierSnapshot?['name'] ?? 'Unknown'),
                    ),
                    DataCell(
                      Text('₹${purchase.grandTotal.toStringAsFixed(2)}'),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          ReportPaginationFooter(
            hasMore: purchaseState.hasMore,
            isLoadingMore: purchaseState.isLoadingMore,
            totalLoaded: purchaseState.items.length,
            onLoadMore: () =>
                ref.read(reportPurchasesProvider.notifier).loadMore(),
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
