import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryTransactionModel {
  final String? transactionId;
  final String businessId;
  final String productId;
  final String productName;
  final String type; // 'IN', 'OUT', 'ADJ', 'SALE', 'CANCELLED_SALE'
  final double quantity;
  final double previousStock;
  final double newStock;
  final String reason;
  final String? referenceId; // e.g., invoiceId
  final DateTime? createdAt;
  final String? createdBy;

  InventoryTransactionModel({
    this.transactionId,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    this.referenceId,
    this.createdAt,
    this.createdBy,
  });

  factory InventoryTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw Exception('Transaction data not found');

    return InventoryTransactionModel(
      transactionId: snapshot.id,
      businessId: data['businessId'] as String,
      productId: data['productId'] as String,
      productName: data['productName'] as String,
      type: data['type'] as String,
      quantity: (data['quantity'] as num).toDouble(),
      previousStock: (data['previousStock'] as num).toDouble(),
      newStock: (data['newStock'] as num).toDouble(),
      reason: data['reason'] as String,
      referenceId: data['referenceId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'productId': productId,
      'productName': productName,
      'type': type,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'reason': reason,
      if (referenceId != null) 'referenceId': referenceId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}
