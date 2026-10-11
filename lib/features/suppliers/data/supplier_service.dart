import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_model.dart';

class SupplierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String businessId;

  SupplierService({required this.businessId});

  CollectionReference<SupplierModel> get _suppliersRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('suppliers')
      .withConverter<SupplierModel>(
        fromFirestore: (snapshot, _) => SupplierModel.fromFirestore(snapshot),
        toFirestore: (supplier, _) => supplier.toFirestore(),
      );

  Future<SupplierModel> createSupplier(SupplierModel supplier) async {
    final counterRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('metadata')
        .doc('counters');

    return await _firestore.runTransaction((transaction) async {
      // 1. Read counters
      final counterSnapshot = await transaction.get(counterRef);

      int lastSupplierNumber = 0;
      if (counterSnapshot.exists &&
          counterSnapshot.data()!.containsKey('lastSupplierNumber')) {
        lastSupplierNumber = counterSnapshot.get('lastSupplierNumber') as int;
      }

      // 2. Generate unique supplier code
      lastSupplierNumber += 1;
      final supplierCode =
          'SUP-${lastSupplierNumber.toString().padLeft(6, '0')}';

      // 3. Regenerate searchKeywords WITH the actual supplierCode
      final finalKeywords = generateSearchKeywords(
        supplier.name,
        supplier.phone ?? '',
        supplierCode,
      );

      // 4. Prepare supplier data
      final docRef = _suppliersRef.doc();
      final newSupplier = supplier.copyWith(
        supplierCode: supplierCode,
        searchKeywords: finalKeywords,
      );

      // 5. Create supplier
      transaction.set(docRef, newSupplier);

      // 6. Update ONLY lastSupplierNumber
      transaction.set(
        counterRef,
        {'lastSupplierNumber': lastSupplierNumber},
        SetOptions(
          merge: true,
        ), // Essential to prevent overwriting lastInvoiceNumber
      );

      return newSupplier;
    });
  }

  /// Generate lowercase word-level prefixes for searchable fields.
  /// Used at creation (inside the transaction) and can be reused for edits.
  static List<String> generateSearchKeywords(
    String name,
    String phone,
    String code,
  ) {
    final Set<String> keywords = {};

    void addPrefixes(String word) {
      final w = word.trim().toLowerCase();
      for (int i = 1; i <= w.length; i++) {
        keywords.add(w.substring(0, i));
      }
    }

    for (var word in name.split(RegExp(r'\s+'))) {
      addPrefixes(word);
    }
    if (phone.isNotEmpty) addPrefixes(phone);
    if (code.isNotEmpty) addPrefixes(code);

    return keywords.toList();
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    // Normal edit cannot update outstandingBalance or immutable fields.
    // The security rules enforce this, but we also ensure it client-side.
    await _suppliersRef.doc(supplier.supplierId).update({
      'name': supplier.name,
      'phone': supplier.phone,
      'email': supplier.email,
      'address': supplier.address,
      'city': supplier.city,
      'state': supplier.state,
      'pincode': supplier.pincode,
      'gstNumber': supplier.gstNumber,
      'searchKeywords': supplier.searchKeywords,
      'isActive': supplier.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      // We must explicitly write outstandingBalance so that if it was missing
      // in a legacy document, the fallback effective value is persisted properly.
      'outstandingBalance': supplier.outstandingBalance,
    });
  }

  Future<void> toggleSupplierStatus(String supplierId, bool isActive) async {
    await _suppliersRef.doc(supplierId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getSuppliersPaginated({
    DocumentSnapshot? startAfter,
    int limit = 20,
    bool? activeOnly,
    String? searchQuery,
  }) async {
    Query<SupplierModel> query = _suppliersRef;

    if (activeOnly != null) {
      query = query.where('isActive', isEqualTo: activeOnly);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: searchQuery.toLowerCase(),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.sublist(0, limit) : snapshot.docs;

    return {
      'suppliers': docs.map((doc) => doc.data()).toList(),
      'lastDocument': docs.isNotEmpty ? docs.last : null,
      'hasMore': hasMore,
    };
  }

  // Get raw DocumentSnapshot for pagination cursor
  Future<QuerySnapshot<SupplierModel>> getSuppliersSnapshotPaginated({
    DocumentSnapshot? startAfter,
    int limit = 20,
    bool? activeOnly,
    String? searchQuery,
  }) async {
    Query<SupplierModel> query = _suppliersRef;

    if (activeOnly != null) {
      query = query.where('isActive', isEqualTo: activeOnly);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: searchQuery.toLowerCase(),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    return await query.get();
  }
}
