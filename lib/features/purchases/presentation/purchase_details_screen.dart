import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/error_formatter.dart';
import '../providers/purchase_provider.dart';
import '../models/purchase_model.dart';
import '../data/purchase_service.dart';

class PurchaseDetailsScreen extends ConsumerWidget {
  final String purchaseId;
  const PurchaseDetailsScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(purchaseServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Details')),
      body: service == null
          ? const Center(child: Text('Service unavailable'))
          : FutureBuilder<PurchaseModel?>(
              future: _loadPurchase(service),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${ErrorFormatter.format(snapshot.error)}',
                    ),
                  );
                }
                final purchase = snapshot.data;
                if (purchase == null) {
                  return const Center(child: Text('Purchase not found'));
                }
                return _PurchaseDetailsBody(
                  purchase: purchase,
                  purchaseId: purchaseId,
                );
              },
            ),
    );
  }

  Future<PurchaseModel?> _loadPurchase(PurchaseService service) async {
    // Load by doc ID directly
    final doc = await service.getPurchaseById(purchaseId);
    return doc;
  }
}

class _PurchaseDetailsBody extends ConsumerWidget {
  final PurchaseModel purchase;
  final String purchaseId;

  const _PurchaseDetailsBody({
    required this.purchase,
    required this.purchaseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = ref.watch(purchaseControllerProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeaderCard(context),
          const SizedBox(height: 16),

          // Supplier
          _buildSupplierCard(context),
          const SizedBox(height: 16),

          // Items
          _buildItemsCard(context),
          const SizedBox(height: 16),

          // Totals
          _buildTotalsCard(context),
          const SizedBox(height: 16),

          // Payment
          _buildPaymentCard(context),
          const SizedBox(height: 24),

          // Cancel button (only for confirmed + settledAmount == 0)
          if (purchase.status == PurchaseStatus.confirmed &&
              purchase.settledAmount == 0)
            FilledButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => _cancelPurchase(context, ref),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cancel),
              label: Text(isProcessing ? 'Cancelling...' : 'Cancel Purchase'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

          if (purchase.status == PurchaseStatus.confirmed &&
              purchase.settledAmount > 0)
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Cannot cancel: ₹${purchase.settledAmount.toStringAsFixed(2)} has been paid to the supplier against this purchase.',
                  style: TextStyle(color: Colors.orange[900]),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    Color statusColor;
    switch (purchase.status) {
      case PurchaseStatus.draft:
        statusColor = Colors.orange;
        break;
      case PurchaseStatus.confirmed:
        statusColor = Colors.green;
        break;
      case PurchaseStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  purchase.purchaseNumber.isNotEmpty
                      ? purchase.purchaseNumber
                      : 'DRAFT',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(purchase.status.name.toUpperCase()),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Purchase Date:'),
                Text(DateFormat('dd MMM yyyy').format(purchase.purchaseDate)),
              ],
            ),
            if (purchase.createdAt != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Created:'),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(purchase.createdAt!),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierCard(BuildContext context) {
    final snap = purchase.supplierSnapshot;
    if (snap == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text(
              snap['name'] as String? ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (snap['supplierCode'] != null)
              Text('Code: ${snap['supplierCode']}'),
            if (snap['phone'] != null && (snap['phone'] as String).isNotEmpty)
              Text('Phone: ${snap['phone']}'),
            if (snap['gstNumber'] != null &&
                (snap['gstNumber'] as String).isNotEmpty)
              Text('GSTIN: ${snap['gstNumber']}'),
            if (snap['state'] != null && (snap['state'] as String).isNotEmpty)
              Text('State: ${snap['state']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items (${purchase.items.length})',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...purchase.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productNameSnapshot,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity} × ₹${item.unitPrice.toStringAsFixed(2)}',
                        ),
                        Text('₹${item.totalAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                    if (item.discount > 0)
                      Text(
                        'Discount: ₹${item.discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                    if (item.gstRate > 0)
                      Text(
                        'GST ${item.gstRate}%: CGST ₹${item.cgstAmount.toStringAsFixed(2)} + SGST ₹${item.sgstAmount.toStringAsFixed(2)} + IGST ₹${item.igstAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _row('Subtotal', purchase.subtotal),
            _row('Discount', purchase.discountAmount),
            _row('Taxable Amount', purchase.taxableAmount),
            if (purchase.cgstTotal > 0) _row('CGST', purchase.cgstTotal),
            if (purchase.sgstTotal > 0) _row('SGST', purchase.sgstTotal),
            if (purchase.igstTotal > 0) _row('IGST', purchase.igstTotal),
            const Divider(),
            _row('Grand Total', purchase.grandTotal, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _row('Paid Amount', purchase.payment.paidAmount),
            _row(
              'Balance (Payable)',
              purchase.payment.balanceAmount,
              bold: true,
            ),
            _row('Settled to Supplier', purchase.settledAmount),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status:'),
                Chip(
                  label: Text(purchase.payment.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Method:'),
                Text(purchase.payment.paymentMethod),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: bold
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelPurchase(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Purchase'),
        content: const Text(
          'This will reverse stock and supplier balance changes. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Purchase'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(purchaseControllerProvider.notifier)
            .cancelPurchase(purchaseId);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Purchase cancelled')));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
