import 'package:cloud_firestore/cloud_firestore.dart';

enum InvoiceStatus { draft, confirmed, cancelled }

class InvoiceItemModel {
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

  InvoiceItemModel({
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

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
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

class InvoicePayment {
  final String status; // 'Unpaid', 'Partially Paid', 'Paid'
  final double paidAmount;
  final double balanceAmount;
  final String paymentMethod; // 'Cash', 'UPI', 'Card', 'Bank', 'None'

  InvoicePayment({
    required this.status,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentMethod,
  });

  factory InvoicePayment.fromMap(Map<String, dynamic> map) {
    return InvoicePayment(
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

class CustomerSnapshot {
  final String customerId;
  final String name;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? gstNumber;

  CustomerSnapshot({
    required this.customerId,
    required this.name,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.gstNumber,
  });

  factory CustomerSnapshot.fromMap(Map<String, dynamic> map) {
    return CustomerSnapshot(
      customerId: map['customerId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      gstNumber: map['gstNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (gstNumber != null) 'gstNumber': gstNumber,
    };
  }
}

class InvoiceModel {
  final String? invoiceId;
  final String businessId;
  final String invoiceNumber; // E.g., INV-000001 (Blank if Draft)
  final DateTime issueDate;
  final CustomerSnapshot?
  customerSnapshot; // Optional for cash walk-ins, but usually required
  final List<InvoiceItemModel> items;

  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double grandTotal;

  final InvoicePayment payment;
  final InvoiceStatus status;
  final String? notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    this.invoiceId,
    required this.businessId,
    required this.invoiceNumber,
    required this.issueDate,
    this.customerSnapshot,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.igstTotal,
    required this.grandTotal,
    required this.payment,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory InvoiceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw Exception('Invoice data not found');

    return InvoiceModel(
      invoiceId: snapshot.id,
      businessId: data['businessId'] as String,
      invoiceNumber: data['invoiceNumber'] as String? ?? '',
      issueDate: (data['issueDate'] as Timestamp).toDate(),
      customerSnapshot: data['customerSnapshot'] != null
          ? CustomerSnapshot.fromMap(
              data['customerSnapshot'] as Map<String, dynamic>,
            )
          : null,
      items: (data['items'] as List<dynamic>)
          .map((item) => InvoiceItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      subtotal: (data['subtotal'] as num).toDouble(),
      discountAmount: (data['discountAmount'] as num).toDouble(),
      taxableAmount: (data['taxableAmount'] as num).toDouble(),
      cgstTotal: (data['cgstTotal'] as num).toDouble(),
      sgstTotal: (data['sgstTotal'] as num).toDouble(),
      igstTotal: (data['igstTotal'] as num).toDouble(),
      grandTotal: (data['grandTotal'] as num).toDouble(),
      payment: InvoicePayment.fromMap(data['payment'] as Map<String, dynamic>),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (invoiceId != null && invoiceId!.isNotEmpty) 'invoiceId': invoiceId,
      'businessId': businessId,
      'invoiceNumber': invoiceNumber,
      'issueDate': Timestamp.fromDate(issueDate),
      if (customerSnapshot != null)
        'customerSnapshot': customerSnapshot!.toMap(),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'cgstTotal': cgstTotal,
      'sgstTotal': sgstTotal,
      'igstTotal': igstTotal,
      'grandTotal': grandTotal,
      'payment': payment.toMap(),
      'status': status.name,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  InvoiceModel copyWith({
    String? invoiceId,
    String? businessId,
    String? invoiceNumber,
    DateTime? issueDate,
    CustomerSnapshot? customerSnapshot,
    List<InvoiceItemModel>? items,
    double? subtotal,
    double? discountAmount,
    double? taxableAmount,
    double? cgstTotal,
    double? sgstTotal,
    double? igstTotal,
    double? grandTotal,
    InvoicePayment? payment,
    InvoiceStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      invoiceId: invoiceId ?? this.invoiceId,
      businessId: businessId ?? this.businessId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      customerSnapshot: customerSnapshot ?? this.customerSnapshot,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstTotal: cgstTotal ?? this.cgstTotal,
      sgstTotal: sgstTotal ?? this.sgstTotal,
      igstTotal: igstTotal ?? this.igstTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      payment: payment ?? this.payment,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
