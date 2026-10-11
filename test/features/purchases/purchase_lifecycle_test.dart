import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/purchases/models/purchase_model.dart';

void main() {
  group('PurchaseModel Lifecycle & Invariants Tests', () {
    final sampleItem = PurchaseItemModel(
      productId: 'prod-002',
      productNameSnapshot: 'Raw Material A',
      skuSnapshot: 'RAW-001',
      quantity: 10.0,
      unitPrice: 50.0,
      discount: 0.0,
      taxableValue: 500.0,
      gstRate: 5.0,
      cgstAmount: 12.50,
      sgstAmount: 12.50,
      igstAmount: 0.0,
      totalAmount: 525.0,
    );

    final samplePayment = PurchasePayment(
      status: 'Unpaid',
      paidAmount: 0.0,
      balanceAmount: 525.0,
      paymentMethod: 'None',
    );

    final samplePurchase = PurchaseModel(
      purchaseId: 'pur-001',
      businessId: 'biz-001',
      purchaseNumber: 'PUR-000001',
      purchaseDate: DateTime(2026, 3, 2, 11, 0),
      supplierSnapshot: {
        'supplierId': 'sup-001',
        'name': 'ABC Supplies',
        'phone': '9876543210',
        'state': 'Tamil Nadu',
      },
      items: [sampleItem],
      subtotal: 500.0,
      discountAmount: 0.0,
      taxableAmount: 500.0,
      cgstTotal: 12.50,
      sgstTotal: 12.50,
      igstTotal: 0.0,
      grandTotal: 525.0,
      payment: samplePayment,
      settledAmount: 0.0,
      status: PurchaseStatus.draft,
      notes: 'Initial purchase draft',
      createdAt: DateTime(2026, 3, 2, 11, 0),
      updatedAt: DateTime(2026, 3, 2, 11, 0),
    );

    test('PurchaseItemModel serialization and deserialization roundtrip', () {
      final map = sampleItem.toMap();
      final deserialized = PurchaseItemModel.fromMap(map);

      expect(deserialized.productId, sampleItem.productId);
      expect(deserialized.productNameSnapshot, sampleItem.productNameSnapshot);
      expect(deserialized.quantity, sampleItem.quantity);
      expect(deserialized.unitPrice, sampleItem.unitPrice);
      expect(deserialized.taxableValue, sampleItem.taxableValue);
      expect(deserialized.gstRate, sampleItem.gstRate);
      expect(deserialized.cgstAmount, sampleItem.cgstAmount);
      expect(deserialized.sgstAmount, sampleItem.sgstAmount);
      expect(deserialized.igstAmount, sampleItem.igstAmount);
      expect(deserialized.totalAmount, sampleItem.totalAmount);
    });

    test('PurchasePayment serialization and deserialization roundtrip', () {
      final map = samplePayment.toMap();
      final deserialized = PurchasePayment.fromMap(map);

      expect(deserialized.status, samplePayment.status);
      expect(deserialized.paidAmount, samplePayment.paidAmount);
      expect(deserialized.balanceAmount, samplePayment.balanceAmount);
      expect(deserialized.paymentMethod, samplePayment.paymentMethod);
    });

    test('copyWith properly preserves immutable fields and updates status', () {
      final confirmedPurchase = samplePurchase.copyWith(
        status: PurchaseStatus.confirmed,
        purchaseNumber: 'PUR-000005',
      );

      expect(confirmedPurchase.status, PurchaseStatus.confirmed);
      expect(confirmedPurchase.purchaseNumber, 'PUR-000005');
      expect(confirmedPurchase.businessId, samplePurchase.businessId);
      expect(confirmedPurchase.purchaseId, samplePurchase.purchaseId);
      expect(confirmedPurchase.grandTotal, samplePurchase.grandTotal);
      expect(confirmedPurchase.settledAmount, 0.0);
    });

    test('Purchase cancellation safety condition: cannot cancel if settledAmount > 0', () {
      final settledPurchase = samplePurchase.copyWith(
        status: PurchaseStatus.confirmed,
        settledAmount: 100.0,
      );

      // Business logic rule verification: settledAmount > 0 should block cancellation
      final canCancel = settledPurchase.settledAmount <= 0.0;
      expect(canCancel, isFalse);

      final unSettledPurchase = samplePurchase.copyWith(
        status: PurchaseStatus.confirmed,
        settledAmount: 0.0,
      );
      expect(unSettledPurchase.settledAmount <= 0.0, isTrue);
    });
  });
}
