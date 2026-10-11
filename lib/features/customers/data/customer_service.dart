import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_model.dart';

class CustomerService {
  final FirebaseFirestore _firestore;
  final String businessId;

  CustomerService(this.businessId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<CustomerModel> get _customersRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers')
        .withConverter<CustomerModel>(
          fromFirestore: CustomerModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  /// Raw collection reference (without converter) for paginated queries
  /// that need to return DocumentSnapshot for cursor tracking.
  CollectionReference<Map<String, dynamic>> get _customersRawRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers');
  }

  /// Creates a customer with server-assigned document ID.
  /// Sets customerId = doc ID and outstandingBalance = openingBalance
  /// so that Firestore rules can validate both constraints.
  Future<String> createCustomer(CustomerModel customer) async {
    final docRef = _customersRawRef.doc();
    final toCreate = customer.copyWith(
      customerId: docRef.id,
      businessId: businessId,
      outstandingBalance: customer.openingBalance,
      isActive: true,
    );
    await docRef.set(toCreate.toFirestore());
    return docRef.id;
  }

  /// Updates only editable profile fields. Immutable fields (customerId,
  /// businessId, createdAt, openingBalance, outstandingBalance) are preserved
  /// by using toProfileUpdateMap() which excludes them.
  ///
  /// Firestore rules enforce that these immutable fields remain unchanged,
  /// so even if a client were modified, the write would be rejected.
  Future<void> updateCustomerProfile(CustomerModel customer) async {
    if (customer.customerId == null) {
      throw Exception('Cannot update customer without an ID');
    }
    await _customersRawRef
        .doc(customer.customerId)
        .update(customer.toProfileUpdateMap());
  }

  /// Deactivates a customer (soft delete). Only changes isActive + updatedAt.
  Future<void> deactivateCustomer(String customerId) async {
    await _customersRawRef.doc(customerId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Paginated customer listing ordered by name.
  /// Returns a map with 'customers', 'lastDocument', and 'hasMore'.
  ///
  /// Supports optional active/inactive filter via [isActive].
  /// Search is handled client-side on the paginated results.
  Future<Map<String, dynamic>> getCustomersPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool? isActive,
  }) async {
    Query<CustomerModel> query = _customersRef.orderBy('name');

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.sublist(0, limit) : snapshot.docs;

    return {
      'customers': docs.map((d) => d.data()).toList(),
      'lastDocument': docs.isNotEmpty ? docs.last : null,
      'hasMore': hasMore,
    };
  }

  /// Streams all customers ordered by name.
  /// Kept for backward compatibility with dashboard and invoice picker.
  Stream<List<CustomerModel>> getCustomers() {
    return _customersRef
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Returns active customers only. Used by invoice customer picker.
  Future<List<CustomerModel>> getActiveCustomers() async {
    final querySnapshot = await _customersRef
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Fetches a single customer by ID.
  Future<CustomerModel?> getCustomerById(String customerId) async {
    final doc = await _customersRef.doc(customerId).get();
    return doc.data();
  }
}
