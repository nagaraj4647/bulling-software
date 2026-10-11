import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class ProductStockReportView extends ConsumerWidget {
  const ProductStockReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(reportProductsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(reportProductsProvider.notifier).refresh();
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
                    'Product Stock Report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildContent(context, ref, productsState),
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
    dynamic productsState,
  ) {
    if (productsState.isLoading && productsState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (productsState.error != null && productsState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${productsState.error}'),
        ),
      );
    }

    if (productsState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No products found.'),
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
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Current Stock')),
              DataColumn(label: Text('Min Alert')),
              DataColumn(label: Text('Purchase Price')),
              DataColumn(label: Text('Sale Price')),
              DataColumn(label: Text('Status')),
            ],
            rows: productsState.items.map<DataRow>((product) {
              final isLowStock =
                  product.stockQuantity <= product.lowStockThreshold;
              final isOutOfStock = product.stockQuantity <= 0;
              final statusText = isOutOfStock
                  ? 'Out of Stock'
                  : (isLowStock ? 'Low Stock' : 'In Stock');
              final statusColor = isOutOfStock
                  ? Colors.red
                  : (isLowStock ? Colors.orange : Colors.green);

              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text(product.sku ?? '-')),
                  DataCell(Text(product.stockQuantity.toString())),
                  DataCell(Text(product.lowStockThreshold.toString())),
                  DataCell(
                    Text('₹${product.purchasePrice.toStringAsFixed(2)}'),
                  ),
                  DataCell(Text('₹${product.sellingPrice.toStringAsFixed(2)}')),
                  DataCell(
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        ReportPaginationFooter(
          hasMore: productsState.hasMore,
          isLoadingMore: productsState.isLoadingMore,
          totalLoaded: productsState.items.length,
          onLoadMore: () =>
              ref.read(reportProductsProvider.notifier).loadMore(),
        ),
      ],
    );
  }
}
