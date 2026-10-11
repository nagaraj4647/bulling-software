import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String? customerId;
  final String businessId;
  final String name;
  final String? phone;
  final String? alternatePhone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstNumber;
  final double openingBalance;
  final double outstandingBalance;
  final double creditLimit;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    this.customerId,
    required this.businessId,
    required this.name,
    this.phone,
    this.alternatePhone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    this.openingBalance = 0.0,
    this.outstandingBalance = 0.0,
    this.creditLimit = 0.0,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw Exception('Customer data not found');

    final openingBal = (data['openingBalance'] as num?)?.toDouble() ?? 0.0;

    return CustomerModel(
      customerId: snapshot.id,
      businessId: data['businessId'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      alternatePhone: data['alternatePhone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      pincode: data['pincode'] as String?,
      gstNumber: data['gstNumber'] as String?,
      openingBalance: openingBal,
      // Legacy compatibility: fallback to openingBalance if outstandingBalance is missing
      outstandingBalance:
          (data['outstandingBalance'] as num?)?.toDouble() ?? openingBal,
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Full document representation for Firestore create operations.
  /// Includes customerId so Firestore rules can validate customerId == document ID.
  Map<String, dynamic> toFirestore() {
    return {
      if (customerId != null && customerId!.isNotEmpty)
        'customerId': customerId,
      'businessId': businessId,
      'name': name,
      'phone': phone ?? '',
      'alternatePhone': alternatePhone ?? '',
      'email': email ?? '',
      'address': address ?? '',
      'city': city ?? '',
      'state': state ?? '',
      'pincode': pincode ?? '',
      'gstNumber': gstNumber ?? '',
      'openingBalance': openingBalance,
      'outstandingBalance': outstandingBalance,
      'creditLimit': creditLimit,
      'notes': notes ?? '',
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Profile-only update map. Excludes immutable fields (customerId, businessId,
  /// createdAt, openingBalance, outstandingBalance) so the client cannot
  /// accidentally or maliciously alter them during a normal edit.
  Map<String, dynamic> toProfileUpdateMap() {
    return {
      'name': name,
      'phone': phone ?? '',
      'alternatePhone': alternatePhone ?? '',
      'email': email ?? '',
      'address': address ?? '',
      'city': city ?? '',
      'state': state ?? '',
      'pincode': pincode ?? '',
      'gstNumber': gstNumber ?? '',
      'creditLimit': creditLimit,
      'notes': notes ?? '',
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CustomerModel copyWith({
    String? customerId,
    String? businessId,
    String? name,
    String? phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstNumber,
    double? openingBalance,
    double? outstandingBalance,
    double? creditLimit,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      customerId: customerId ?? this.customerId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstNumber: gstNumber ?? this.gstNumber,
      openingBalance: openingBalance ?? this.openingBalance,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
