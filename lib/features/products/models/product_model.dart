import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? productId;
  final String businessId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? category;
  final String? unit;
  final double purchasePrice;
  final double sellingPrice;
  final double stockQuantity;
  final double lowStockThreshold;
  final double gstRate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductModel({
    this.productId,
    required this.businessId,
    required this.name,
    this.sku,
    this.barcode,
    this.category,
    this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.gstRate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Product data not found');
    }

    return ProductModel(
      productId: snapshot.id,
      businessId: data['businessId'] as String,
      name: data['name'] as String,
      sku: data['sku'] as String?,
      barcode: data['barcode'] as String?,
      category: data['category'] as String?,
      unit: data['unit'] as String?,
      purchasePrice: (data['purchasePrice'] as num).toDouble(),
      sellingPrice: (data['sellingPrice'] as num).toDouble(),
      stockQuantity: (data['stockQuantity'] as num).toDouble(),
      lowStockThreshold: (data['lowStockThreshold'] as num).toDouble(),
      gstRate: (data['gstRate'] as num).toDouble(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'gstRate': gstRate,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProductModel copyWith({
    String? productId,
    String? businessId,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? stockQuantity,
    double? lowStockThreshold,
    double? gstRate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      gstRate: gstRate ?? this.gstRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
