import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_transaction_model.dart';
import '../../products/models/product_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore;
  final String businessId;

  InventoryService(this.businessId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<ProductModel> get _productsRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .withConverter<ProductModel>(
          fromFirestore: ProductModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  CollectionReference<InventoryTransactionModel> get _inventoryRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryTransactions')
        .withConverter<InventoryTransactionModel>(
          fromFirestore: InventoryTransactionModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  Future<void> adjustStock({
    required String productId,
    required String type, // 'IN', 'OUT', 'ADJ'
    required double quantity, // for ADJ this is the new total stock, for IN/OUT this is the delta
    required String reason,
    required String userId,
  }) async {
    final productRef = _productsRef.doc(productId);
    final inventoryRef = _inventoryRef.doc();

    await _firestore.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw Exception('Product does not exist');
      }

      final product = productSnapshot.data()!;
      final previousStock = product.stockQuantity;
      double newStock = previousStock;

      if (type == 'IN') {
        if (quantity < 0) throw Exception('Quantity cannot be negative');
        newStock = previousStock + quantity;
      } else if (type == 'OUT') {
        if (quantity < 0) throw Exception('Quantity cannot be negative');
        if (previousStock - quantity < 0) {
          throw Exception(
            'Stock Out requested quantity is greater than current stock (cannot be negative)',
          );
        }
        newStock = previousStock - quantity;
      } else if (type == 'ADJ') {
        if (quantity < 0) throw Exception('Adjusted stock cannot be negative');
        newStock = quantity;
      } else {
        throw Exception('Invalid transaction type');
      }

      final transactionModel = InventoryTransactionModel(
        transactionId: inventoryRef.id,
        businessId: businessId,
        productId: productId,
        productName: product.name,
        type: type,
        quantity: type == 'ADJ' ? (newStock - previousStock).abs() : quantity,
        previousStock: previousStock,
        newStock: newStock,
        reason: reason,
        createdBy: userId,
      );

      transaction.update(productRef, {
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(inventoryRef, transactionModel);
    });
  }

  Stream<List<InventoryTransactionModel>> getTransactionHistory(
    String productId,
  ) {
    return _inventoryRef
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
