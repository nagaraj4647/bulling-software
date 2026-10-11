import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/customer_provider.dart';
import '../models/customer_model.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  void _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Customer?'),
        content: const Text(
          'This customer will no longer be available for new transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref
          .read(customerControllerProvider.notifier)
          .deactivateCustomer(customer.customerId!);
      if (context.mounted) {
        context.pop(); // Go back to list
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: customersState.when(
        data: (customers) {
          final customer = customers
              .where((c) => c.customerId == customerId)
              .firstOrNull;

          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref, customer),
                const SizedBox(height: 24),
                _buildInfoCard(context, customer),
                const SizedBox(height: 24),
                _buildFinancialCard(context, customer),
                const SizedBox(height: 24),
                _buildPlaceholderSections(context),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: customer.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[300],
          child: Text(
            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 24,
              color: customer.isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: customer.isActive
                      ? null
                      : TextDecoration.lineThrough,
                ),
              ),
              if (!customer.isActive)
                const Text(
                  'Inactive',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Edit Customer',
          onPressed: () => context.go('/customers/edit/${customer.customerId}'),
        ),
        if (customer.isActive)
          IconButton(
            icon: const Icon(Icons.block, color: Colors.red),
            tooltip: 'Deactivate',
            onPressed: () => _confirmDeactivate(context, ref, customer),
          ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, CustomerModel customer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(Icons.phone, 'Phone', customer.phone ?? 'N/A'),
            if (customer.alternatePhone != null &&
                customer.alternatePhone!.isNotEmpty)
              _buildDetailRow(
                Icons.phone_android,
                'Alt Phone',
                customer.alternatePhone!,
              ),
            _buildDetailRow(Icons.email, 'Email', customer.email ?? 'N/A'),
            _buildDetailRow(
              Icons.location_on,
              'Address',
              [
                    customer.address,
                    customer.city,
                    customer.state,
                    customer.pincode,
                  ].where((e) => e != null && e.isNotEmpty).join(', ').isEmpty
                  ? 'N/A'
                  : [
                      customer.address,
                      customer.city,
                      customer.state,
                      customer.pincode,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),
            ),
            _buildDetailRow(
              Icons.receipt,
              'GST Number',
              customer.gstNumber ?? 'N/A',
            ),
            if (customer.notes != null && customer.notes!.isNotEmpty)
              _buildDetailRow(Icons.note, 'Notes', customer.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(BuildContext context, CustomerModel customer) {
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
            _buildDetailRow(
              Icons.account_balance_wallet,
              'Opening Balance',
              '₹${customer.openingBalance.toStringAsFixed(2)}',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 20,
                    color: customer.outstandingBalance > 0
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Outstanding',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '₹${customer.outstandingBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: customer.outstandingBalance > 0
                            ? Colors.red[700]
                            : Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDetailRow(
              Icons.credit_card,
              'Credit Limit',
              '₹${customer.creditLimit.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderSections(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Invoice History'),
            subtitle: const Text('Coming Soon'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice module not yet implemented.'),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Payment History'),
            subtitle: const Text('Coming Soon'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payments module not yet implemented.'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
