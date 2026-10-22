import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/error_formatter.dart';
import '../../business/models/business_model.dart';
import '../../business/providers/business_provider.dart';
import '../providers/billing_provider.dart';
import '../models/invoice_model.dart';
import '../services/invoice_pdf_service.dart';

class InvoiceDetailsScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  void _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: const Text(
          'This action cannot be undone. It will:\n\n'
          '• Restore product stock\n'
          '• Reverse customer outstanding balance\n'
          '• Mark the invoice as Cancelled',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Invoice'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel Invoice',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref
          .read(billingControllerProvider.notifier)
          .cancelInvoice(invoiceId);
      if (context.mounted) {
        final state = ref.read(billingControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${ErrorFormatter.format(state.error)}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedInvoicesProvider);
    final isCancelling = ref.watch(billingControllerProvider).isLoading;
    final business = ref.watch(currentBusinessProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Details')),
      body: Builder(
        builder: (context) {
          if (paginatedState.isLoading && paginatedState.invoices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (paginatedState.error != null) {
            return Center(
              child: Text(
                'Error: ${ErrorFormatter.format(paginatedState.error)}',
              ),
            );
          }

          final invoice = paginatedState.invoices
              .where((inv) => inv.invoiceId == invoiceId)
              .firstOrNull;

          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }

          final isConfirmed = invoice.status == InvoiceStatus.confirmed;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context, invoice),
                const SizedBox(height: 16),
                _buildCustomerCard(context, invoice),
                const SizedBox(height: 16),
                _buildItemsList(context, invoice),
                const SizedBox(height: 16),
                _buildTotalsCard(context, invoice),
                const SizedBox(height: 16),
                _buildUpiQrCard(context, business, invoice),
                _buildBillActions(context, business, invoice),
                const SizedBox(height: 8),
                if (isConfirmed)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: isCancelling
                        ? null
                        : () => _confirmCancel(context, ref, invoice),
                    icon: isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cancel),
                    label: Text(
                      isCancelling ? 'Cancelling...' : 'Cancel Invoice',
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, InvoiceModel invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.invoiceNumber.isNotEmpty
                      ? invoice.invoiceNumber
                      : 'Draft',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(invoice.status.name.toUpperCase()),
                  backgroundColor: invoice.status == InvoiceStatus.confirmed
                      ? Colors.green[100]
                      : (invoice.status == InvoiceStatus.cancelled
                            ? Colors.red[100]
                            : Colors.grey[200]),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date:'),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(invoice.issueDate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, InvoiceModel invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Billed To',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (invoice.customerSnapshot != null) ...[
              Text(
                invoice.customerSnapshot!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (invoice.customerSnapshot!.phone != null)
                Text('Ph: ${invoice.customerSnapshot!.phone}'),
              if (invoice.customerSnapshot!.city != null)
                Text(
                  '${invoice.customerSnapshot!.address ?? ''}, ${invoice.customerSnapshot!.city}',
                ),
              if (invoice.customerSnapshot!.gstNumber != null)
                Text('GSTIN: ${invoice.customerSnapshot!.gstNumber}'),
            ] else
              const Text('Walk-in Customer (Unregistered)'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, InvoiceModel invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...invoice.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productNameSnapshot,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${item.quantity} x ₹${item.unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (item.discount > 0)
                            Text(
                              'Discount: ₹${item.discount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${item.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'GST ${item.gstRate}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTotalsCard(BuildContext context, InvoiceModel invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAmountRow('Subtotal', invoice.subtotal),
            if (invoice.discountAmount > 0)
              _buildAmountRow(
                'Discount',
                -invoice.discountAmount,
                color: Colors.green,
              ),
            _buildAmountRow('Taxable Amount', invoice.taxableAmount),
            if (invoice.cgstTotal > 0)
              _buildAmountRow('CGST', invoice.cgstTotal),
            if (invoice.sgstTotal > 0)
              _buildAmountRow('SGST', invoice.sgstTotal),
            if (invoice.igstTotal > 0)
              _buildAmountRow('IGST', invoice.igstTotal),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${invoice.grandTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildAmountRow(
              'Paid (${invoice.payment.paymentMethod})',
              invoice.payment.paidAmount,
              color: Colors.blue,
            ),
            _buildAmountRow(
              'Balance Due',
              invoice.payment.balanceAmount,
              color: invoice.payment.balanceAmount > 0
                  ? Colors.red
                  : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildUpiQrCard(
    BuildContext context,
    BusinessModel? business,
    InvoiceModel invoice,
  ) {
    final upiId = business?.upiId;
    if (upiId == null || upiId.isEmpty) return const SizedBox.shrink();
    if (invoice.payment.balanceAmount <= 0) return const SizedBox.shrink();
    final amount = InvoicePdfService.qrAmount(invoice);
    final link = InvoicePdfService.buildUpiLink(
      upiId: upiId,
      payeeName: business!.businessName,
      amount: amount,
      note: invoice.invoiceNumber,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Scan to Pay - UPI',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            QrImageView(data: link, version: QrVersions.auto, size: 180),
            const SizedBox(height: 8),
            Text(
              '\u20B9${amount.toStringAsFixed(2)} - $upiId',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillActions(
    BuildContext context,
    BusinessModel? business,
    InvoiceModel invoice,
  ) {
    final fileName =
        '${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'invoice'}.pdf';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _runPdfAction(context, () async {
                      final bytes = await InvoicePdfService.buildInvoicePdf(
                        invoice: invoice,
                        business: business,
                      );
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: fileName,
                      );
                    }),
                icon: const Icon(Icons.share),
                label: const Text('Share Bill'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _runPdfAction(context, () async {
                      await Printing.layoutPdf(
                        name: fileName,
                        onLayout: (_) => InvoicePdfService.buildInvoicePdf(
                          invoice: invoice,
                          business: business,
                        ),
                      );
                    }),
                icon: const Icon(Icons.print),
                label: const Text('Print A4'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              _runPdfAction(context, () async {
                await Printing.layoutPdf(
                  name: fileName,
                  onLayout: (_) => InvoicePdfService.buildInvoicePdf(
                    invoice: invoice,
                    business: business,
                    thermal: true,
                  ),
                );
              }),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Thermal Print (80mm)'),
        ),
      ],
    );
  }

  Future<void> _runPdfAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

