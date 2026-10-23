import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../business/models/business_model.dart';
import '../models/invoice_model.dart';

/// Builds invoice PDFs (A4 and 80mm thermal) and UPI "scan to pay" links.
///
/// Pure Dart + pdf package - no platform channels, works fully offline.
/// Note: base PDF fonts cannot render the rupee glyph, so amounts use "Rs.".
class InvoicePdfService {
  /// Standard UPI intent link. Opening / scanning it launches any UPI app
  /// (GPay, PhonePe, Paytm) with payee, amount and note prefilled.
  static String buildUpiLink({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) {
    final params = <String, String>{
      'pa': upiId,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note != null && note.isNotEmpty) 'tn': note,
    };
    return 'upi://pay?' +
        params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
  }

  /// Amount the QR should ask for: the pending balance when partly paid,
  /// otherwise the full bill total.
  static double qrAmount(InvoiceModel invoice) {
    return invoice.payment.balanceAmount > 0
        ? invoice.payment.balanceAmount
        : invoice.grandTotal;
  }

  static Future<Uint8List> buildInvoicePdf({
    required InvoiceModel invoice,
    BusinessModel? business,
    bool thermal = false,
  }) async {
    final doc = pw.Document();
    if (thermal) {
      // Roll paper has infinite height; pw.Page (not MultiPage) accepts it.
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => _thermalContent(invoice, business),
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [_a4Content(invoice, business)],
        ),
      );
    }
    return doc.save();
  }

  // ---------------------------------------------------------------- A4 -----

  static pw.Widget _a4Content(InvoiceModel invoice, BusinessModel? business) {
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    business?.businessName ?? 'Invoice',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (business != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      business.address,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Ph: ${business.phone}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    if (business.gstNumber != null &&
                        business.gstNumber!.isNotEmpty)
                      pw.Text(
                        'GSTIN: ${business.gstNumber}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.invoiceNumber.isNotEmpty
                      ? invoice.invoiceNumber
                      : 'DRAFT',
                  style: bold,
                ),
                pw.Text(
                  _fmtDate(invoice.issueDate),
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 4),
                _statusChip(invoice),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.SizedBox(height: 6),
        pw.Text('Billed To', style: bold),
        pw.SizedBox(height: 4),
        if (invoice.customerSnapshot != null) ...[
          pw.Text(invoice.customerSnapshot!.name),
          if (invoice.customerSnapshot!.phone != null)
            pw.Text(
              'Ph: ${invoice.customerSnapshot!.phone}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          if (invoice.customerSnapshot!.gstNumber != null)
            pw.Text(
              'GSTIN: ${invoice.customerSnapshot!.gstNumber}',
              style: const pw.TextStyle(fontSize: 9),
            ),
        ] else
          pw.Text('Walk-in Customer'),
        pw.SizedBox(height: 12),
        _itemsTable(invoice, compact: false),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(width: 220, child: _totalsBlock(invoice)),
        ),
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Note: ${invoice.notes}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        ..._qrSection(invoice, business, qrSize: 90),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Center(
          child: pw.Text(
            'Thank you for your business!',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- thermal ---

  static pw.Widget _thermalContent(
    InvoiceModel invoice,
    BusinessModel? business,
  ) {
    const small = pw.TextStyle(fontSize: 8);
    final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            business?.businessName ?? 'Invoice',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (business != null) ...[
          pw.Center(
            child: pw.Text(
              business.address,
              style: small,
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Center(child: pw.Text('Ph: ${business.phone}', style: small)),
          if (business.gstNumber != null && business.gstNumber!.isNotEmpty)
            pw.Center(
              child: pw.Text('GSTIN: ${business.gstNumber}', style: small),
            ),
        ],
        pw.SizedBox(height: 4),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'DRAFT',
              style: bold,
            ),
            pw.Text(_fmtDate(invoice.issueDate), style: small),
          ],
        ),
        if (invoice.customerSnapshot != null)
          pw.Text('To: ${invoice.customerSnapshot!.name}', style: small),
        pw.Divider(),
        _itemsTable(invoice, compact: true),
        pw.Divider(),
        _totalsBlock(invoice, fontSize: 8),
        ..._qrSection(invoice, business, qrSize: 110, fontSize: 7),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('Thank you! Visit again', style: small)),
      ],
    );
  }

  // -------------------------------------------------------------- shared ---

  static pw.Widget _itemsTable(InvoiceModel invoice, {required bool compact}) {
    final headerStyle = pw.TextStyle(
      fontSize: compact ? 7 : 9,
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = pw.TextStyle(fontSize: compact ? 7 : 9);
    pw.Widget cell(String t, {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(t, style: cellStyle, textAlign: align),
        );

    return pw.Table(
      columnWidths: compact
          ? {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2.2),
            }
          : {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(2.4),
            },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.6)),
          ),
          children: [
            pw.Text('Item', style: headerStyle),
            pw.Text('Qty', style: headerStyle, textAlign: pw.TextAlign.center),
            pw.Text(
              'Rate',
              style: headerStyle,
              textAlign: pw.TextAlign.right,
            ),
            if (!compact)
              pw.Text(
                'GST%',
                style: headerStyle,
                textAlign: pw.TextAlign.right,
              ),
            pw.Text(
              'Amount',
              style: headerStyle,
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
        ...invoice.items.map((item) {
          final qty = item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toInt().toString()
              : item.quantity.toString();
          return pw.TableRow(
            children: [
              cell(item.productNameSnapshot),
              cell(qty, align: pw.TextAlign.center),
              cell(_money(item.unitPrice), align: pw.TextAlign.right),
              if (!compact)
                cell(
                  item.gstRate.toStringAsFixed(0),
                  align: pw.TextAlign.right,
                ),
              cell(_money(item.totalAmount), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _totalsBlock(InvoiceModel invoice, {double fontSize = 9}) {
    final style = pw.TextStyle(fontSize: fontSize);
    final bold = pw.TextStyle(
      fontSize: fontSize + 1,
      fontWeight: pw.FontWeight.bold,
    );
    pw.Widget row(String label, double amount, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: strong ? bold : style),
              pw.Text('Rs.${_money(amount)}', style: strong ? bold : style),
            ],
          ),
        );

    return pw.Column(
      children: [
        row('Subtotal', invoice.subtotal),
        if (invoice.discountAmount > 0) row('Discount', -invoice.discountAmount),
        row('Taxable', invoice.taxableAmount),
        if (invoice.cgstTotal > 0) row('CGST', invoice.cgstTotal),
        if (invoice.sgstTotal > 0) row('SGST', invoice.sgstTotal),
        if (invoice.igstTotal > 0) row('IGST', invoice.igstTotal),
        pw.Divider(height: 6),
        row('Grand Total', invoice.grandTotal, strong: true),
        row(
          'Paid (${invoice.payment.paymentMethod})',
          invoice.payment.paidAmount,
        ),
        row('Balance Due', invoice.payment.balanceAmount, strong: true),
      ],
    );
  }

  static List<pw.Widget> _qrSection(
    InvoiceModel invoice,
    BusinessModel? business, {
    required double qrSize,
    double fontSize = 9,
  }) {
    final upiId = business?.upiId;
    if (upiId == null || upiId.isEmpty) return const [];
    final amount = qrAmount(invoice);
    final link = buildUpiLink(
      upiId: upiId,
      payeeName: business!.businessName,
      amount: amount,
      note: invoice.invoiceNumber,
    );
    return [
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'Scan to Pay - Rs.${_money(amount)}',
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: link,
              width: qrSize,
              height: qrSize,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              upiId,
              style: pw.TextStyle(fontSize: fontSize - 1),
            ),
          ],
        ),
      ),
    ];
  }

  static pw.Widget _statusChip(InvoiceModel invoice) {
    final isPaid = invoice.payment.balanceAmount <= 0;
    final label = invoice.status == InvoiceStatus.cancelled
        ? 'CANCELLED'
        : (isPaid ? 'PAID' : 'BALANCE DUE');
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static String _money(double v) => v.toStringAsFixed(2);

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}, '
        '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}
