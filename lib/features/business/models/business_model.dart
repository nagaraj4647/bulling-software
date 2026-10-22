import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  final String? businessId;
  final String ownerId;
  final String businessName;
  final String businessType;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String? businessState;
  final String? gstNumber;
  final String? upiId;
  final bool isGstInclusive;
  final String? logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool sampleProductsSeeded;

  BusinessModel({
    this.businessId,
    required this.ownerId,
    required this.businessName,
    required this.businessType,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    this.businessState,
    this.gstNumber,
    this.upiId,
    this.isGstInclusive = false,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
    this.sampleProductsSeeded = false,
  });

  factory BusinessModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Business data not found');
    }

    return BusinessModel(
      businessId: snapshot.id,
      ownerId: data['ownerId'] as String,
      businessName: data['businessName'] as String,
      businessType: data['businessType'] as String,
      ownerName: data['ownerName'] as String,
      phone: data['phone'] as String,
      email: data['email'] as String,
      address: data['address'] as String,
      businessState: data['businessState'] as String?,
      gstNumber: data['gstNumber'] as String?,
      upiId: data['upiId'] as String?,
      isGstInclusive: data['isGstInclusive'] as bool? ?? false,
      logoUrl: data['logoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      sampleProductsSeeded: data['sampleProductsSeeded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'businessName': businessName,
      'businessType': businessType,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      if (businessState != null) 'businessState': businessState,
      if (gstNumber != null) 'gstNumber': gstNumber,
      'isGstInclusive': isGstInclusive,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'sampleProductsSeeded': sampleProductsSeeded,
    };
  }

  BusinessModel copyWith({
    String? businessId,
    String? ownerId,
    String? businessName,
    String? businessType,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    String? businessState,
    String? gstNumber,
    String? upiId,
    bool? isGstInclusive,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? sampleProductsSeeded,
  }) {
    return BusinessModel(
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      businessState: businessState ?? this.businessState,
      gstNumber: gstNumber ?? this.gstNumber,
      upiId: upiId ?? this.upiId,
      isGstInclusive: isGstInclusive ?? this.isGstInclusive,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sampleProductsSeeded: sampleProductsSeeded ?? this.sampleProductsSeeded,
    );
  }
}
