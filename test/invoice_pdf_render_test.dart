import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';
import 'package:billing_app/features/billing/services/invoice_pdf_service.dart';
import 'package:billing_app/features/business/models/business_model.dart';

void main() {
  test('invoice pdf renders A4 + thermal with UPI QR and correct balance', () async {
    final business = BusinessModel(
      ownerId: 'u1',
      businessName: 'Sri Balaji Stores',
      businessType: 'Retail',
      ownerName: 'Nagarajan M',
      phone: '9876543210',
      email: 'shop@example.com',
      address: 'No 16, Vaniga Valagam, Nenmeli, Sriperumbudur 602105',
      businessState: 'Tamil Nadu',
      gstNumber: '33AAAAA0000A1Z5',
      upiId: 'nagaraj4647@okhdfcbank',
    );

    final invoice = InvoiceModel(
      businessId: 'b1',
      invoiceNumber: 'INV-000042',
      issueDate: DateTime(2026, 10, 23, 12, 30),
      customerSnapshot: CustomerSnapshot(
        customerId: 'c1',
        name: 'Karthik Raja',
        phone: '9090909090',
        city: 'Chennai',
      ),
      items: [
        InvoiceItemModel(
          productId: 'p1',
          productNameSnapshot: 'Cotton Shirt (Blue, L)',
          skuSnapshot: 'SH-BLU-L',
          quantity: 2,
          unitPrice: 499,
          discount: 50,
          taxableValue: 848,
          gstRate: 5,
          cgstAmount: 21.20,
          sgstAmount: 21.20,
          igstAmount: 0,
          totalAmount: 890.40,
        ),
        InvoiceItemModel(
          productId: 'p2',
          productNameSnapshot: 'Denim Jeans (32)',
          skuSnapshot: 'DJ-32',
          quantity: 1,
          unitPrice: 999,
          discount: 0,
          taxableValue: 999,
          gstRate: 5,
          cgstAmount: 24.98,
          sgstAmount: 24.98,
          igstAmount: 0,
          totalAmount: 1048.95,
        ),
      ],
      subtotal: 1996,
      discountAmount: 50,
      taxableAmount: 1847,
      cgstTotal: 46.18,
      sgstTotal: 46.18,
      igstTotal: 0,
      grandTotal: 1939.35,
      payment: InvoicePayment(
        status: 'Partially Paid',
        paidAmount: 1000,
        balanceAmount: 939.35,
        paymentMethod: 'UPI',
      ),
      status: InvoiceStatus.confirmed,
      notes: 'Deliver before Friday evening',
    );

    final a4 = await InvoicePdfService.buildInvoicePdf(
      invoice: invoice,
      business: business,
    );
    File('/tmp/out/invoice_a4.pdf').writeAsBytesSync(a4);

    final thermal = await InvoicePdfService.buildInvoicePdf(
      invoice: invoice,
      business: business,
      thermal: true,
    );
    File('/tmp/out/invoice_thermal.pdf').writeAsBytesSync(thermal);

    final link = InvoicePdfService.buildUpiLink(
      upiId: business.upiId!,
      payeeName: business.businessName,
      amount: InvoicePdfService.qrAmount(invoice),
      note: invoice.invoiceNumber,
    );
    // balance (939.35), not grand total - QR must ask only what is due
    expect(link, contains('am=939.35'));
    expect(link, startsWith('upi://pay?'));
    expect(a4.length, greaterThan(1000));
    expect(thermal.length, greaterThan(1000));
  });
}
