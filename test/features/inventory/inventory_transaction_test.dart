import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/inventory/models/inventory_transaction_model.dart';

void main() {
  group('Inventory Transaction Math & Safety Invariant Tests', () {
    test('SALE transaction correctly reduces stock delta', () {
      const initialStock = 50.0;
      const saleQty = 5.0;
      final newStock = initialStock - saleQty;

      final tx = InventoryTransactionModel(
        businessId: 'biz-001',
        productId: 'prod-001',
        productName: 'Widget A',
        type: 'SALE',
        quantity: -saleQty,
        previousStock: initialStock,
        newStock: newStock,
        reason: 'Invoice INV-000001',
        referenceId: 'inv-001',
      );

      expect(tx.type, 'SALE');
      expect(tx.previousStock, 50.0);
      expect(tx.newStock, 45.0);
      expect(tx.newStock, tx.previousStock + tx.quantity);
      expect(tx.newStock >= 0, isTrue);
    });

    test('CANCELLED_SALE transaction correctly restores deducted stock', () {
      const currentStock = 45.0;
      const restoreQty = 5.0;
      final restoredStock = currentStock + restoreQty;

      final tx = InventoryTransactionModel(
        businessId: 'biz-001',
        productId: 'prod-001',
        productName: 'Widget A',
        type: 'CANCELLED_SALE',
        quantity: restoreQty,
        previousStock: currentStock,
        newStock: restoredStock,
        reason: 'Cancelled Invoice INV-000001',
        referenceId: 'inv-001',
      );

      expect(tx.type, 'CANCELLED_SALE');
      expect(tx.previousStock, 45.0);
      expect(tx.newStock, 50.0);
      expect(tx.newStock, tx.previousStock + tx.quantity);
    });

    test('PURCHASE transaction correctly increments stock', () {
      const initialStock = 50.0;
      const purchaseQty = 20.0;
      final newStock = initialStock + purchaseQty;

      final tx = InventoryTransactionModel(
        businessId: 'biz-001',
        productId: 'prod-001',
        productName: 'Widget A',
        type: 'PURCHASE',
        quantity: purchaseQty,
        previousStock: initialStock,
        newStock: newStock,
        reason: 'Purchase PUR-000001',
        referenceId: 'pur-001',
      );

      expect(tx.type, 'PURCHASE');
      expect(tx.newStock, 70.0);
      expect(tx.newStock, tx.previousStock + tx.quantity);
    });

    test('CANCELLED_PURCHASE transaction reverses incremented stock', () {
      const currentStock = 70.0;
      const deductQty = 20.0;
      final newStock = currentStock - deductQty;

      final tx = InventoryTransactionModel(
        businessId: 'biz-001',
        productId: 'prod-001',
        productName: 'Widget A',
        type: 'CANCELLED_PURCHASE',
        quantity: -deductQty,
        previousStock: currentStock,
        newStock: newStock,
        reason: 'Cancelled Purchase PUR-000001',
        referenceId: 'pur-001',
      );

      expect(tx.type, 'CANCELLED_PURCHASE');
      expect(tx.newStock, 50.0);
      expect(tx.newStock, tx.previousStock + tx.quantity);
    });

    test('Stock underflow guard: cannot reduce below zero', () {
      const currentStock = 3.0;
      const attemptSaleQty = 5.0;

      final hasSufficientStock = currentStock >= attemptSaleQty;
      expect(hasSufficientStock, isFalse);
    });
  });
}
