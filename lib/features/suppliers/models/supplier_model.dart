import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierModel {
  final String supplierId;
  final String businessId;
  final String supplierCode;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstNumber;
  final List<String> searchKeywords;
  final double openingBalance;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    required this.supplierId,
    required this.businessId,
    required this.supplierCode,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    required this.searchKeywords,
    required this.openingBalance,
    required this.outstandingBalance,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Legacy compatibility: fallback to openingBalance, then 0.0
    final effectiveOutstandingBalance =
        (data['outstandingBalance'] as num?)?.toDouble() ??
        (data['openingBalance'] as num?)?.toDouble() ??
        0.0;

    return SupplierModel(
      supplierId: data['supplierId'] ?? doc.id,
      businessId: data['businessId'] ?? '',
      supplierCode: data['supplierCode'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      pincode: data['pincode'],
      gstNumber: data['gstNumber'],
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: effectiveOutstandingBalance,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'businessId': businessId,
      'supplierCode': supplierCode,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gstNumber': gstNumber,
      'searchKeywords': searchKeywords,
      'openingBalance': openingBalance,
      'outstandingBalance': outstandingBalance,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SupplierModel copyWith({
    String? supplierCode,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstNumber,
    List<String>? searchKeywords,
    double? outstandingBalance, // Future purchases can update this
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      supplierId: supplierId,
      businessId: businessId,
      supplierCode: supplierCode ?? this.supplierCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstNumber: gstNumber ?? this.gstNumber,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      openingBalance: openingBalance, // Immutable from copyWith
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt, // Immutable from copyWith
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// A helper model for embedding in Purchase records
class SupplierSnapshot {
  final String supplierId;
  final String supplierCode;
  final String name;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? gstNumber;

  SupplierSnapshot({
    required this.supplierId,
    required this.supplierCode,
    required this.name,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.gstNumber,
  });

  factory SupplierSnapshot.fromSupplier(SupplierModel supplier) {
    return SupplierSnapshot(
      supplierId: supplier.supplierId,
      supplierCode: supplier.supplierCode,
      name: supplier.name,
      phone: supplier.phone,
      address: supplier.address,
      city: supplier.city,
      state: supplier.state,
      gstNumber: supplier.gstNumber,
    );
  }

  factory SupplierSnapshot.fromMap(Map<String, dynamic> map) {
    return SupplierSnapshot(
      supplierId: map['supplierId'] ?? '',
      supplierCode: map['supplierCode'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      gstNumber: map['gstNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'supplierCode': supplierCode,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'gstNumber': gstNumber,
    };
  }
}
