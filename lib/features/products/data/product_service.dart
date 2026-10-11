import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import '../../inventory/models/inventory_transaction_model.dart';

class ProductService {
  final FirebaseFirestore _firestore;
  final String businessId;

  ProductService(this.businessId, {FirebaseFirestore? firestore})
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

  Future<String> createProduct(
    ProductModel product, {
    double openingStock = 0,
  }) async {
    // If there is opening stock, we do it atomically via transaction
    if (openingStock > 0) {
      final newProductRef = _productsRef.doc();
      final inventoryRef = _inventoryRef.doc();

      final productWithStock = product.copyWith(
        productId: newProductRef.id,
        stockQuantity: openingStock,
      );

      final transactionModel = InventoryTransactionModel(
        transactionId: inventoryRef.id,
        businessId: businessId,
        productId: newProductRef.id,
        productName: product.name,
        type: 'IN',
        quantity: openingStock,
        previousStock: 0,
        newStock: openingStock,
        reason: 'Opening Stock',
      );

      await _firestore.runTransaction((transaction) async {
        transaction.set(newProductRef, productWithStock);
        transaction.set(inventoryRef, transactionModel);
      });

      return newProductRef.id;
    } else {
      // Normal creation
      final docRef = await _productsRef.add(product.copyWith(stockQuantity: 0));
      return docRef.id;
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    if (product.productId == null) {
      throw Exception('Cannot update product without an ID');
    }
    // We explicitly DO NOT update stockQuantity via this method to prevent bypass of inventory transactions.
    // So we'll remove it from the map.
    final data = product.toFirestore();
    data.remove('stockQuantity');

    await _productsRef.doc(product.productId).update(data);
  }

  Future<void> deactivateProduct(String productId) async {
    await _productsRef.doc(productId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ProductModel>> getProducts() {
    return _productsRef
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Dashboard: Lowest stock products sample
  Stream<List<ProductModel>> getLowestStockProductsStream({int limit = 20}) {
    return _productsRef
        .where('isActive', isEqualTo: true)
        .orderBy('stockQuantity', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<ProductModel?> getProductById(String productId) async {
    final doc = await _productsRef.doc(productId).get();
    return doc.data();
  }

  /// Paginated products ordered by name.
  /// Fetches limit + 1 internally to accurately determine hasMore.
  Future<Map<String, dynamic>> getProductsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool? isActive,
  }) async {
    Query<ProductModel> query = _productsRef;

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    query = query.orderBy('name');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.sublist(0, limit) : snapshot.docs;

    return {
      'products': docs.map((d) => d.data()).toList(),
      'lastDocument': docs.isNotEmpty ? docs.last : null,
      'hasMore': hasMore,
    };
  }

  Future<int> seedSampleProducts() async {
    final querySnapshot = await _productsRef.get();
    final existingSkus = querySnapshot.docs
        .map((doc) => doc.data().sku)
        .where((sku) => sku != null)
        .toSet();

    final sampleProducts = [
      {
        'name': 'Rice - 1 kg',
        'sku': 'GRO-001',
        'category': 'Groceries',
        'sp': 60.0,
        'pp': 50.0,
        'stock': 100.0,
        'min': 20.0,
        'unit': 'kg',
      },
      {
        'name': 'Sugar - 1 kg',
        'sku': 'GRO-002',
        'category': 'Groceries',
        'sp': 45.0,
        'pp': 40.0,
        'stock': 50.0,
        'min': 10.0,
        'unit': 'kg',
      },
      {
        'name': 'Wheat Flour - 1 kg',
        'sku': 'GRO-003',
        'category': 'Groceries',
        'sp': 40.0,
        'pp': 32.0,
        'stock': 80.0,
        'min': 20.0,
        'unit': 'kg',
      },
      {
        'name': 'Cooking Oil - 1 L',
        'sku': 'GRO-004',
        'category': 'Groceries',
        'sp': 130.0,
        'pp': 110.0,
        'stock': 60.0,
        'min': 15.0,
        'unit': 'L',
      },
      {
        'name': 'Salt - 1 kg',
        'sku': 'GRO-005',
        'category': 'Groceries',
        'sp': 25.0,
        'pp': 20.0,
        'stock': 120.0,
        'min': 20.0,
        'unit': 'kg',
      },
      {
        'name': 'Tea Powder - 250 g',
        'sku': 'BEV-001',
        'category': 'Beverages',
        'sp': 120.0,
        'pp': 95.0,
        'stock': 30.0,
        'min': 10.0,
        'unit': 'g',
      },
      {
        'name': 'Coffee Powder - 100 g',
        'sku': 'BEV-002',
        'category': 'Beverages',
        'sp': 90.0,
        'pp': 75.0,
        'stock': 8.0,
        'min': 15.0,
        'unit': 'g',
      }, // Low stock (1/3)
      {
        'name': 'Milk - 1 L',
        'sku': 'BEV-003',
        'category': 'Beverages',
        'sp': 65.0,
        'pp': 55.0,
        'stock': 20.0,
        'min': 5.0,
        'unit': 'L',
      },
      {
        'name': 'Biscuits - 1 Packet',
        'sku': 'SNA-001',
        'category': 'Snacks',
        'sp': 30.0,
        'pp': 25.0,
        'stock': 150.0,
        'min': 30.0,
        'unit': 'pkt',
      },
      {
        'name': 'Bread - 1 Packet',
        'sku': 'SNA-002',
        'category': 'Snacks',
        'sp': 40.0,
        'pp': 32.0,
        'stock': 0.0,
        'min': 10.0,
        'unit': 'pkt',
      }, // Zero stock
      {
        'name': 'Soap - 1 Piece',
        'sku': 'PER-001',
        'category': 'Personal Care',
        'sp': 35.0,
        'pp': 28.0,
        'stock': 100.0,
        'min': 20.0,
        'unit': 'pcs',
      },
      {
        'name': 'Shampoo - 1 Bottle',
        'sku': 'PER-002',
        'category': 'Personal Care',
        'sp': 150.0,
        'pp': 120.0,
        'stock': 40.0,
        'min': 10.0,
        'unit': 'pcs',
      },
      {
        'name': 'Toothpaste - 1 Tube',
        'sku': 'PER-003',
        'category': 'Personal Care',
        'sp': 85.0,
        'pp': 70.0,
        'stock': 5.0,
        'min': 15.0,
        'unit': 'pcs',
      }, // Low stock (2/3)
      {
        'name': 'Toothbrush - 1 Piece',
        'sku': 'PER-004',
        'category': 'Personal Care',
        'sp': 20.0,
        'pp': 15.0,
        'stock': 80.0,
        'min': 20.0,
        'unit': 'pcs',
      },
      {
        'name': 'Washing Powder - 1 kg',
        'sku': 'HOU-001',
        'category': 'Household',
        'sp': 110.0,
        'pp': 90.0,
        'stock': 45.0,
        'min': 15.0,
        'unit': 'kg',
      },
      {
        'name': 'Dish Wash - 500 ml',
        'sku': 'HOU-002',
        'category': 'Household',
        'sp': 65.0,
        'pp': 55.0,
        'stock': 4.0,
        'min': 10.0,
        'unit': 'pcs',
      }, // Low stock (3/3)
      {
        'name': 'Water Bottle - 1 L',
        'sku': 'BEV-004',
        'category': 'Beverages',
        'sp': 20.0,
        'pp': 15.0,
        'stock': 200.0,
        'min': 50.0,
        'unit': 'pcs',
      },
      {
        'name': 'Soft Drink - 750 ml',
        'sku': 'BEV-005',
        'category': 'Beverages',
        'sp': 45.0,
        'pp': 38.0,
        'stock': 60.0,
        'min': 15.0,
        'unit': 'pcs',
      },
      {
        'name': 'Notebook - 1 Piece',
        'sku': 'STA-001',
        'category': 'Stationery',
        'sp': 50.0,
        'pp': 35.0,
        'stock': 120.0,
        'min': 30.0,
        'unit': 'pcs',
      },
      {
        'name': 'Pen - 1 Piece',
        'sku': 'STA-002',
        'category': 'Stationery',
        'sp': 10.0,
        'pp': 7.0,
        'stock': 300.0,
        'min': 50.0,
        'unit': 'pcs',
      },
    ];

    final batch = _firestore.batch();

    int addedCount = 0;

    for (final pData in sampleProducts) {
      final sku = pData['sku'] as String;
      if (existingSkus.contains(sku)) continue;

      final newProductRef = _productsRef.doc();

      final openingStock = pData['stock'] as double;
      final product = ProductModel(
        productId: newProductRef.id,
        businessId: businessId,
        name: pData['name'] as String,
        sku: sku,
        category: pData['category'] as String,
        sellingPrice: pData['sp'] as double,
        purchasePrice: pData['pp'] as double,
        stockQuantity: openingStock,
        lowStockThreshold: pData['min'] as double,
        unit: pData['unit'] as String,
        isActive: true,
        gstRate: 0.0,
      );

      batch.set(newProductRef, product);

      if (openingStock > 0) {
        final inventoryRef = _inventoryRef.doc();
        final transactionModel = InventoryTransactionModel(
          transactionId: inventoryRef.id,
          businessId: businessId,
          productId: newProductRef.id,
          productName: product.name,
          type: 'IN',
          quantity: openingStock,
          previousStock: 0,
          newStock: openingStock,
          reason: 'Opening Stock',
        );
        batch.set(inventoryRef, transactionModel);
      }
      addedCount++;
    }

    if (addedCount > 0) {
      await batch.commit();
    }

    return addedCount;
  }
}
