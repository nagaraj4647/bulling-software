import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/supplier_provider.dart';
import '../models/supplier_model.dart';

class SupplierDetailsScreen extends ConsumerWidget {
  final String supplierId;

  const SupplierDetailsScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierDetailsProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Supplier',
            onPressed: () => context.go('/suppliers/edit/$supplierId'),
          ),
        ],
      ),
      body: supplierAsync.when(
        data: (supplier) {
          if (supplier == null) {
            return const Center(child: Text('Supplier not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context, supplier),
                const SizedBox(height: 16),
                _buildContactCard(context, supplier),
                const SizedBox(height: 16),
                _buildFinancialsCard(context, supplier),
                const SizedBox(height: 16),
                _buildRecentPurchasesPlaceholder(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, SupplierModel supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    supplier.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: supplier.isActive
                          ? null
                          : TextDecoration.lineThrough,
                      color: supplier.isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                Chip(
                  label: Text(supplier.isActive ? 'ACTIVE' : 'INACTIVE'),
                  backgroundColor: supplier.isActive
                      ? Colors.green[100]
                      : Colors.grey[300],
                  labelStyle: TextStyle(
                    color: supplier.isActive
                        ? Colors.green[800]
                        : Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Supplier Code:'),
                Text(
                  supplier.supplierCode,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Added on:'),
                Text(DateFormat('dd MMM yyyy').format(supplier.createdAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, SupplierModel supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact & Tax Info',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(supplier.phone!),
                ],
              ),
            ],
            if (supplier.email != null && supplier.email!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(supplier.email!),
                ],
              ),
            ],
            if (supplier.address != null && supplier.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${supplier.address}, ${supplier.city ?? ''}, ${supplier.state ?? ''} - ${supplier.pincode ?? ''}',
                    ),
                  ),
                ],
              ),
            ],
            if (supplier.gstNumber != null &&
                supplier.gstNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('GSTIN: ${supplier.gstNumber}'),
                ],
              ),
            ],
            if ((supplier.phone == null || supplier.phone!.isEmpty) &&
                (supplier.email == null || supplier.email!.isEmpty) &&
                (supplier.address == null || supplier.address!.isEmpty))
              const Text(
                'No contact information provided.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialsCard(BuildContext context, SupplierModel supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financials',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opening Balance'),
                Text('₹${supplier.openingBalance.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Outstanding Payable',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${supplier.outstandingBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPurchasesPlaceholder(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Recent Purchases',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Purchase history will appear here once the Purchases module is implemented.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
