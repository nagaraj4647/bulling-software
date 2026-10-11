import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseStatus { draft, confirmed, cancelled }

class PurchaseItemModel {
  final String productId;
  final String productNameSnapshot;
  final String? skuSnapshot;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxableValue;
  final double gstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;

  PurchaseItemModel({
    required this.productId,
    required this.productNameSnapshot,
    this.skuSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.taxableValue,
    required this.gstRate,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalAmount,
  });

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      productId: map['productId'] as String,
      productNameSnapshot: map['productNameSnapshot'] as String,
      skuSnapshot: map['skuSnapshot'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      taxableValue: (map['taxableValue'] as num).toDouble(),
      gstRate: (map['gstRate'] as num).toDouble(),
      cgstAmount: (map['cgstAmount'] as num).toDouble(),
      sgstAmount: (map['sgstAmount'] as num).toDouble(),
      igstAmount: (map['igstAmount'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productNameSnapshot': productNameSnapshot,
      if (skuSnapshot != null) 'skuSnapshot': skuSnapshot,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'taxableValue': taxableValue,
      'gstRate': gstRate,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'totalAmount': totalAmount,
    };
  }
}

class PurchasePayment {
  final String status; // 'Unpaid', 'Partially Paid', 'Paid'
  final double paidAmount;
  final double balanceAmount;
  final String paymentMethod; // 'Cash', 'UPI', 'Card', 'Bank', 'None'

  PurchasePayment({
    required this.status,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentMethod,
  });

  factory PurchasePayment.fromMap(Map<String, dynamic> map) {
    return PurchasePayment(
      status: map['status'] as String,
      paidAmount: (map['paidAmount'] as num).toDouble(),
      balanceAmount: (map['balanceAmount'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'paymentMethod': paymentMethod,
    };
  }
}

class PurchaseModel {
  final String? purchaseId;
  final String businessId;
  final String purchaseNumber; // PUR-000001 when confirmed, '' when draft
  final DateTime purchaseDate;
  final Map<String, dynamic>? supplierSnapshot;
  final List<PurchaseItemModel> items;

  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double grandTotal;

  final PurchasePayment payment;
  final double
  settledAmount; // How much of balanceAmount paid via Supplier Payments
  final PurchaseStatus status;
  final String? notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  PurchaseModel({
    this.purchaseId,
    required this.businessId,
    required this.purchaseNumber,
    required this.purchaseDate,
    this.supplierSnapshot,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.igstTotal,
    required this.grandTotal,
    required this.payment,
    this.settledAmount = 0.0,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory PurchaseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw Exception('Purchase data not found');

    return PurchaseModel(
      purchaseId: snapshot.id,
      businessId: data['businessId'] as String,
      purchaseNumber: data['purchaseNumber'] as String? ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      supplierSnapshot: data['supplierSnapshot'] as Map<String, dynamic>?,
      items: (data['items'] as List<dynamic>)
          .map(
            (item) => PurchaseItemModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
      subtotal: (data['subtotal'] as num).toDouble(),
      discountAmount: (data['discountAmount'] as num).toDouble(),
      taxableAmount: (data['taxableAmount'] as num).toDouble(),
      cgstTotal: (data['cgstTotal'] as num).toDouble(),
      sgstTotal: (data['sgstTotal'] as num).toDouble(),
      igstTotal: (data['igstTotal'] as num).toDouble(),
      grandTotal: (data['grandTotal'] as num).toDouble(),
      payment: PurchasePayment.fromMap(data['payment'] as Map<String, dynamic>),
      settledAmount: (data['settledAmount'] as num?)?.toDouble() ?? 0.0,
      status: PurchaseStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PurchaseStatus.draft,
      ),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'purchaseId': purchaseId ?? '',
      'businessId': businessId,
      'purchaseNumber': purchaseNumber,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      if (supplierSnapshot != null) 'supplierSnapshot': supplierSnapshot,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'cgstTotal': cgstTotal,
      'sgstTotal': sgstTotal,
      'igstTotal': igstTotal,
      'grandTotal': grandTotal,
      'payment': payment.toMap(),
      'settledAmount': settledAmount,
      'status': status.name,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PurchaseModel copyWith({
    String? purchaseId,
    String? purchaseNumber,
    DateTime? purchaseDate,
    Map<String, dynamic>? supplierSnapshot,
    List<PurchaseItemModel>? items,
    double? subtotal,
    double? discountAmount,
    double? taxableAmount,
    double? cgstTotal,
    double? sgstTotal,
    double? igstTotal,
    double? grandTotal,
    PurchasePayment? payment,
    double? settledAmount,
    PurchaseStatus? status,
    String? notes,
  }) {
    return PurchaseModel(
      purchaseId: purchaseId ?? this.purchaseId,
      businessId: businessId, // Immutable
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierSnapshot: supplierSnapshot ?? this.supplierSnapshot,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstTotal: cgstTotal ?? this.cgstTotal,
      sgstTotal: sgstTotal ?? this.sgstTotal,
      igstTotal: igstTotal ?? this.igstTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      payment: payment ?? this.payment,
      settledAmount: settledAmount ?? this.settledAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt, // Immutable
      updatedAt: updatedAt,
    );
  }
}
