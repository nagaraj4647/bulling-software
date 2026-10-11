import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../products/models/product_model.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: productsAsync.when(
        data: (products) {
          final totalProducts = products.length;
          final lowStockProducts = products
              .where(
                (p) =>
                    p.stockQuantity > 0 &&
                    p.stockQuantity <= p.lowStockThreshold,
              )
              .toList();
          final outOfStockProducts = products
              .where((p) => p.stockQuantity <= 0)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Products',
                              totalProducts.toString(),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Low Stock',
                              lowStockProducts.length.toString(),
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Out of Stock',
                              outOfStockProducts.length.toString(),
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = products[index];
                  final isOutOfStock = product.stockQuantity <= 0;
                  final isLowStock =
                      !isOutOfStock &&
                      product.stockQuantity <= product.lowStockThreshold;

                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('SKU: ${product.sku ?? 'N/A'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${product.stockQuantity} ${product.unit ?? ''}'
                                  .trim(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock
                                    ? Colors.red
                                    : (isLowStock
                                          ? Colors.orange
                                          : Colors.green),
                              ),
                            ),
                            if (isOutOfStock)
                              const Text(
                                'Out of Stock',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              )
                            else if (isLowStock)
                              const Text(
                                'Low Stock',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.edit_note),
                          tooltip: 'Adjust Stock',
                          onPressed: () =>
                              _showAdjustStockDialog(context, ref, product),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Optionally show transaction history
                      _showTransactionHistory(context, ref, product);
                    },
                  );
                }, childCount: products.length),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustStockDialog(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    final typeController = ValueNotifier<String>('IN');
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Adjust Stock: ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Stock: ${product.stockQuantity}'),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: typeController,
                  builder: (context, type, _) {
                    return DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'IN',
                          child: Text('Stock In (+)'),
                        ),
                        DropdownMenuItem(
                          value: 'OUT',
                          child: Text('Stock Out (-)'),
                        ),
                        DropdownMenuItem(
                          value: 'ADJ',
                          child: Text('Manual Adjustment (=)'),
                        ),
                      ],
                      onChanged: (val) => typeController.value = val!,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity')),
                  );
                  return;
                }

                if (typeController.value == 'OUT' &&
                    qty > product.stockQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot stock out more than current stock'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context); // Close dialog

                try {
                  await ref
                      .read(inventoryControllerProvider.notifier)
                      .adjustStock(
                        productId: product.productId!,
                        type: typeController.value,
                        quantity: qty,
                        reason: reasonController.text.trim().isEmpty
                            ? 'Manual entry'
                            : reasonController.text.trim(),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stock adjusted successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showTransactionHistory(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            final historyAsync = ref.watch(
              inventoryTransactionsProvider(product.productId!),
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'History: ${product.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: historyAsync.when(
                    data: (history) {
                      if (history.isEmpty)
                        return const Center(
                          child: Text('No transaction history'),
                        );

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final tx = history[index];
                          final sign = tx.type == 'IN'
                              ? '+'
                              : (tx.type == 'OUT' ? '-' : '');
                          final color = tx.type == 'IN'
                              ? Colors.green
                              : (tx.type == 'OUT' ? Colors.red : Colors.blue);

                          return ListTile(
                            title: Text(tx.reason),
                            subtitle: Text(
                              tx.createdAt?.toString() ?? 'Unknown date',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$sign${tx.quantity}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Balance: ${tx.newStock}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
