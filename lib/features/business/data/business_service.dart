import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_model.dart';

class BusinessService {
  final FirebaseFirestore _firestore;

  BusinessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<BusinessModel> get _businessesRef {
    return _firestore
        .collection('businesses')
        .withConverter<BusinessModel>(
          fromFirestore: BusinessModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  Future<String> createBusiness(BusinessModel business) async {
    final docRef = await _businessesRef.add(business);
    return docRef.id;
  }

  Future<BusinessModel?> getBusinessForOwner(String ownerId) async {
    final querySnapshot = await _businessesRef
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return querySnapshot.docs.first.data();
  }

  Future<void> updateBusiness(BusinessModel business) async {
    if (business.businessId == null) {
      throw Exception('Cannot update business without an ID');
    }
    await _firestore.collection('businesses').doc(business.businessId).update({
      'businessName': business.businessName,
      'businessType': business.businessType,
      'ownerName': business.ownerName,
      'phone': business.phone,
      'email': business.email,
      'address': business.address,
      'businessState': business.businessState,
      'gstNumber': business.gstNumber,
      'isGstInclusive': business.isGstInclusive,
      if (business.logoUrl != null) 'logoUrl': business.logoUrl,
      'sampleProductsSeeded': business.sampleProductsSeeded,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
