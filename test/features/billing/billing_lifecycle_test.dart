import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';

void main() {
  group('InvoiceModel Lifecycle and Invariant Tests', () {
    final sampleItem = InvoiceItemModel(
      productId: 'prod-001',
      productNameSnapshot: 'Test Product',
      skuSnapshot: 'SKU-100',
      quantity: 2.0,
      unitPrice: 100.0,
      discount: 10.0,
      taxableValue: 190.0,
      gstRate: 18.0,
      cgstAmount: 17.10,
      sgstAmount: 17.10,
      igstAmount: 0.0,
      totalAmount: 224.20,
    );

    final samplePayment = InvoicePayment(
      status: 'Partially Paid',
      paidAmount: 100.0,
      balanceAmount: 124.20,
      paymentMethod: 'Cash',
    );

    final sampleCustomer = CustomerSnapshot(
      customerId: 'cust-001',
      name: 'John Doe',
      phone: '9876543210',
      address: '123 Main Street',
      city: 'Chennai',
      state: 'Tamil Nadu',
      gstNumber: '33ABCDE1234F1Z5',
    );

    final sampleInvoice = InvoiceModel(
      invoiceId: 'inv-001',
      businessId: 'biz-001',
      invoiceNumber: 'INV-000001',
      issueDate: DateTime(2026, 3, 1, 10, 0),
      customerSnapshot: sampleCustomer,
      items: [sampleItem],
      subtotal: 200.0,
      discountAmount: 10.0,
      taxableAmount: 190.0,
      cgstTotal: 17.10,
      sgstTotal: 17.10,
      igstTotal: 0.0,
      grandTotal: 224.20,
      payment: samplePayment,
      status: InvoiceStatus.draft,
      notes: 'Test invoice notes',
      createdAt: DateTime(2026, 3, 1, 10, 0),
      updatedAt: DateTime(2026, 3, 1, 10, 0),
    );

    test('InvoiceItemModel serialization and deserialization roundtrip', () {
      final map = sampleItem.toMap();
      final deserialized = InvoiceItemModel.fromMap(map);

      expect(deserialized.productId, sampleItem.productId);
      expect(deserialized.productNameSnapshot, sampleItem.productNameSnapshot);
      expect(deserialized.skuSnapshot, sampleItem.skuSnapshot);
      expect(deserialized.quantity, sampleItem.quantity);
      expect(deserialized.unitPrice, sampleItem.unitPrice);
      expect(deserialized.discount, sampleItem.discount);
      expect(deserialized.taxableValue, sampleItem.taxableValue);
      expect(deserialized.gstRate, sampleItem.gstRate);
      expect(deserialized.cgstAmount, sampleItem.cgstAmount);
      expect(deserialized.sgstAmount, sampleItem.sgstAmount);
      expect(deserialized.igstAmount, sampleItem.igstAmount);
      expect(deserialized.totalAmount, sampleItem.totalAmount);
    });

    test('InvoicePayment serialization and deserialization roundtrip', () {
      final map = samplePayment.toMap();
      final deserialized = InvoicePayment.fromMap(map);

      expect(deserialized.status, samplePayment.status);
      expect(deserialized.paidAmount, samplePayment.paidAmount);
      expect(deserialized.balanceAmount, samplePayment.balanceAmount);
      expect(deserialized.paymentMethod, samplePayment.paymentMethod);
    });

    test('CustomerSnapshot serialization and deserialization roundtrip', () {
      final map = sampleCustomer.toMap();
      final deserialized = CustomerSnapshot.fromMap(map);

      expect(deserialized.customerId, sampleCustomer.customerId);
      expect(deserialized.name, sampleCustomer.name);
      expect(deserialized.phone, sampleCustomer.phone);
      expect(deserialized.address, sampleCustomer.address);
      expect(deserialized.city, sampleCustomer.city);
      expect(deserialized.state, sampleCustomer.state);
      expect(deserialized.gstNumber, sampleCustomer.gstNumber);
    });

    test('copyWith properly preserves immutable values and updates status', () {
      final confirmedInvoice = sampleInvoice.copyWith(
        status: InvoiceStatus.confirmed,
        invoiceNumber: 'INV-000042',
      );

      expect(confirmedInvoice.status, InvoiceStatus.confirmed);
      expect(confirmedInvoice.invoiceNumber, 'INV-000042');
      expect(confirmedInvoice.businessId, sampleInvoice.businessId);
      expect(confirmedInvoice.invoiceId, sampleInvoice.invoiceId);
      expect(confirmedInvoice.grandTotal, sampleInvoice.grandTotal);

      final cancelledInvoice = confirmedInvoice.copyWith(
        status: InvoiceStatus.cancelled,
      );
      expect(cancelledInvoice.status, InvoiceStatus.cancelled);
    });

    test('Invoice financial invariants hold true', () {
      // Subtotal minus discount equals taxableAmount
      expect(
        sampleInvoice.subtotal - sampleInvoice.discountAmount,
        sampleInvoice.taxableAmount,
      );

      // Taxable amount plus all taxes equals grandTotal
      final computedTotal =
          sampleInvoice.taxableAmount +
          sampleInvoice.cgstTotal +
          sampleInvoice.sgstTotal +
          sampleInvoice.igstTotal;
      expect((computedTotal * 100).round() / 100, sampleInvoice.grandTotal);

      // Paid amount plus balance amount equals grandTotal
      final paymentSum =
          sampleInvoice.payment.paidAmount +
          sampleInvoice.payment.balanceAmount;
      expect((paymentSum * 100).round() / 100, sampleInvoice.grandTotal);
    });
  });
}
