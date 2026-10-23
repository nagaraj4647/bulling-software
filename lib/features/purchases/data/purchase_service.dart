import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase_model.dart';
import '../../billing/data/billing_calculator.dart';
import '../../inventory/models/inventory_transaction_model.dart';
import '../../suppliers/models/supplier_model.dart';

class PurchaseService {
  final FirebaseFirestore _firestore;
  final String businessId;
  final String userId;

  PurchaseService({
    required this.businessId,
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<PurchaseModel> get _purchasesRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('purchases')
        .withConverter<PurchaseModel>(
          fromFirestore: PurchaseModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  DocumentReference get _counterRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('metadata')
        .doc('counters');
  }

  DocumentReference _productRef(String productId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .doc(productId);
  }

  DocumentReference _supplierRef(String supplierId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('suppliers')
        .doc(supplierId);
  }

  CollectionReference _inventoryRef() {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryTransactions');
  }

  String _formatPurchaseNumber(int number) {
    return 'PUR-${number.toString().padLeft(6, '0')}';
  }

  /// Save a new draft or update an existing draft.
  Future<String> saveDraft(PurchaseModel purchase) async {
    if (purchase.purchaseId != null && purchase.purchaseId!.isNotEmpty) {
      await _purchasesRef.doc(purchase.purchaseId).set(purchase);
      return purchase.purchaseId!;
    } else {
      final docRef = _purchasesRef.doc();
      // Set purchaseId in the document to match the doc path (required by security rules)
      final purchaseWithId = purchase.copyWith(purchaseId: docRef.id);
      await docRef.set(purchaseWithId);
      return docRef.id;
    }
  }

  /// Confirm a draft purchase with authoritative snapshot rebuilding.
  /// All reads before all writes.
  Future<void> confirmPurchase(PurchaseModel draftPurchase) async {
    if (draftPurchase.purchaseId == null || draftPurchase.purchaseId!.isEmpty) {
      throw Exception('Purchase must be saved as draft before confirming');
    }

    final purchaseRef = _purchasesRef.doc(draftPurchase.purchaseId);

    // Read business document to get businessState
    final businessDoc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .get();
    final businessState = businessDoc.data()?['businessState'] as String?;

    await _firestore.runTransaction((transaction) async {
      // ── READS ──────────────────────────────────────────
      // 1. Read purchase draft inside transaction (authoritative live document)
      final purchaseDoc = await transaction.get(purchaseRef);
      if (!purchaseDoc.exists || purchaseDoc.data() == null) {
        throw Exception('Purchase draft not found');
      }
      final liveDraft = purchaseDoc.data()!;

      // Verify status is draft
      if (liveDraft.status != PurchaseStatus.draft) {
        throw Exception(
          'Only draft purchases can be confirmed. Current status: ${liveDraft.status.name}',
        );
      }
      if (liveDraft.supplierSnapshot == null) {
        throw Exception('Supplier is required');
      }
      if (liveDraft.items.isEmpty) {
        throw Exception('At least one item is required');
      }

      final supplierId = liveDraft.supplierSnapshot!['supplierId'] as String;

      // 2. Read counters
      final counterSnapshot = await transaction.get(_counterRef);

      // 3. Read supplier (authoritative)
      final supplierDoc = await transaction.get(_supplierRef(supplierId));
      if (!supplierDoc.exists) throw Exception('Supplier not found');
      final supplierData = supplierDoc.data() as Map<String, dynamic>;
      if (supplierData['isActive'] != true)
        throw Exception('Supplier is inactive');

      // 4. Read all products (authoritative)
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in liveDraft.items) {
        final prodDoc = await transaction.get(_productRef(item.productId));
        if (!prodDoc.exists)
          throw Exception('Product ${item.productNameSnapshot} not found');
        final prodData = prodDoc.data() as Map<String, dynamic>;
        if (prodData['isActive'] != true)
          throw Exception('Product ${item.productNameSnapshot} is inactive');
        productDocs[item.productId] = prodDoc;
      }

      // ── VALIDATE ───────────────────────────────────────
      for (final item in liveDraft.items) {
        if (item.quantity <= 0)
          throw Exception(
            'Quantity must be greater than 0 for ${item.productNameSnapshot}',
          );
        if (item.unitPrice < 0)
          throw Exception(
            'Unit price cannot be negative for ${item.productNameSnapshot}',
          );
      }

      // ── COMPUTE ────────────────────────────────────────
      // 5. Generate purchase number
      int lastPurchaseNumber = 0;
      if (counterSnapshot.exists) {
        lastPurchaseNumber =
            (counterSnapshot.data()
                    as Map<String, dynamic>)['lastPurchaseNumber']
                as int? ??
            0;
      }
      lastPurchaseNumber++;
      final purchaseNumber = _formatPurchaseNumber(lastPurchaseNumber);

      // 6. Rebuild authoritative supplier snapshot
      final authoritativeSupplierSnapshot = SupplierSnapshot(
        supplierId: supplierDoc.id,
        supplierCode: supplierData['supplierCode'] as String? ?? '',
        name: supplierData['name'] as String? ?? '',
        phone: supplierData['phone'] as String?,
        address: supplierData['address'] as String?,
        city: supplierData['city'] as String?,
        state: supplierData['state'] as String?,
        gstNumber: supplierData['gstNumber'] as String?,
      ).toMap();

      final supplierState = supplierData['state'] as String?;

      // 7. Rebuild authoritative items with recalculated amounts
      final List<PurchaseItemModel> confirmedItems = [];
      double totalSubtotal = 0;
      double totalDiscount = 0;
      double totalTaxable = 0;
      double totalCgst = 0;
      double totalSgst = 0;
      double totalIgst = 0;
      double totalGrand = 0;

      for (final draftItem in liveDraft.items) {
        final prodData =
            productDocs[draftItem.productId]!.data() as Map<String, dynamic>;
        final authName =
            prodData['name'] as String? ?? draftItem.productNameSnapshot;
        final authSku = prodData['sku'] as String?;
        final authGstRate = (prodData['gstRate'] as num?)?.toDouble() ?? 0.0;

        // Validate GST state requirements
        if (authGstRate > 0) {
          if (businessState == null || businessState.trim().isEmpty) {
            throw Exception('Business state is required for GST calculation');
          }
          if (supplierState == null || supplierState.trim().isEmpty) {
            throw Exception('Supplier state is required for GST calculation');
          }
        }

        // Use user-entered values for quantity, unitPrice, discount
        final itemSubtotal = BillingCalculator.calculateItemSubtotal(
          draftItem.quantity,
          draftItem.unitPrice,
        );
        final itemTaxableValue = BillingCalculator.calculateItemTaxableValue(
          itemSubtotal,
          draftItem.discount,
        );
        final totalGstAmount = BillingCalculator.calculateGstAmount(
          itemTaxableValue,
          authGstRate,
        );

        double cgst = 0, sgst = 0, igst = 0;
        if (authGstRate > 0) {
          final breakdown = BillingCalculator.determineGstSplit(
            businessState: businessState,
            customerState: supplierState, // reusing the same logic for supplier
            gstRate: authGstRate,
            totalGstAmount: totalGstAmount,
          );
          cgst = breakdown.cgst;
          sgst = breakdown.sgst;
          igst = breakdown.igst;
        }

        final itemTotal = BillingCalculator.calculateItemTotal(
          itemTaxableValue,
          totalGstAmount,
        );

        confirmedItems.add(
          PurchaseItemModel(
            productId: draftItem.productId,
            productNameSnapshot: authName,
            skuSnapshot: authSku,
            quantity: draftItem.quantity,
            unitPrice: draftItem.unitPrice,
            discount: draftItem.discount,
            taxableValue: itemTaxableValue,
            gstRate: authGstRate,
            cgstAmount: cgst,
            sgstAmount: sgst,
            igstAmount: igst,
            totalAmount: itemTotal,
          ),
        );

        totalSubtotal += itemSubtotal;
        totalDiscount += draftItem.discount;
        totalTaxable += itemTaxableValue;
        totalCgst += cgst;
        totalSgst += sgst;
        totalIgst += igst;
        totalGrand += itemTotal;
      }

      // Round totals
      totalSubtotal = BillingCalculator.round2(totalSubtotal);
      totalDiscount = BillingCalculator.round2(totalDiscount);
      totalTaxable = BillingCalculator.round2(totalTaxable);
      totalCgst = BillingCalculator.round2(totalCgst);
      totalSgst = BillingCalculator.round2(totalSgst);
      totalIgst = BillingCalculator.round2(totalIgst);
      totalGrand = BillingCalculator.round2(totalGrand);

      // 8. Recompute payment (strict validation, no clamping)
      final paidAmount = liveDraft.payment.paidAmount;
      if (paidAmount < 0) throw Exception('Paid amount cannot be negative');
      if (paidAmount > totalGrand)
        throw Exception(
          'Paid amount (₹${paidAmount.toStringAsFixed(2)}) cannot exceed grand total (₹${totalGrand.toStringAsFixed(2)})',
        );

      final balanceAmount = BillingCalculator.round2(totalGrand - paidAmount);
      final paymentStatus = paidAmount == totalGrand
          ? 'Paid'
          : paidAmount == 0
          ? 'Unpaid'
          : 'Partially Paid';

      final confirmedPayment = PurchasePayment(
        status: paymentStatus,
        paidAmount: paidAmount,
        balanceAmount: balanceAmount,
        paymentMethod: liveDraft.payment.paymentMethod,
      );

      // ── WRITES (all after reads) ───────────────────────
      // 9. Increase product stock + create inventory transactions
      for (final item in confirmedItems) {
        final prodDoc = productDocs[item.productId]!;
        final prodData = prodDoc.data() as Map<String, dynamic>;
        final currentStock = (prodData['stockQuantity'] as num).toDouble();
        final newStock = currentStock + item.quantity;

        transaction.update(prodDoc.reference, {
          'stockQuantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final invTxRef = _inventoryRef().doc();
        final invTx = InventoryTransactionModel(
          businessId: businessId,
          productId: item.productId,
          productName: item.productNameSnapshot,
          type: 'PURCHASE',
          quantity: item.quantity,
          previousStock: currentStock,
          newStock: newStock,
          reason: 'Purchase - $purchaseNumber',
          referenceId: purchaseRef.id,
          createdBy: userId,
        );
        transaction.set(invTxRef, invTx.toFirestore());
      }

      // 10. Update supplier outstandingBalance
      if (balanceAmount != 0) {
        final openingBalance =
            (supplierData['openingBalance'] as num?)?.toDouble() ?? 0.0;
        final currentOutstanding = supplierData['outstandingBalance'] != null
            ? (supplierData['outstandingBalance'] as num).toDouble()
            : openingBalance;
        final newOutstanding = currentOutstanding + balanceAmount;

        transaction.update(supplierDoc.reference, {
          'outstandingBalance': newOutstanding,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 11. Update counter (merge: true — never touches lastInvoiceNumber or lastSupplierNumber)
      transaction.set(_counterRef, {
        'lastPurchaseNumber': lastPurchaseNumber,
      }, SetOptions(merge: true));

      // 12. Update purchase document with confirmed data
      final confirmedPurchase = PurchaseModel(
        purchaseId: liveDraft.purchaseId,
        businessId: businessId,
        purchaseNumber: purchaseNumber,
        purchaseDate: liveDraft.purchaseDate,
        supplierSnapshot: authoritativeSupplierSnapshot,
        items: confirmedItems,
        subtotal: totalSubtotal,
        discountAmount: totalDiscount,
        taxableAmount: totalTaxable,
        cgstTotal: totalCgst,
        sgstTotal: totalSgst,
        igstTotal: totalIgst,
        grandTotal: totalGrand,
        payment: confirmedPayment,
        settledAmount: 0.0,
        status: PurchaseStatus.confirmed,
        notes: liveDraft.notes,
        createdAt: liveDraft.createdAt,
      );

      transaction.set(purchaseRef, confirmedPurchase);
    });
  }

  /// Cancel a confirmed purchase. All reads before all writes.
  Future<void> cancelPurchase(String purchaseId) async {
    await _firestore.runTransaction((transaction) async {
      // ── READS ──────────────────────────────────────────
      // 1. Read purchase
      final purchaseRef = _purchasesRef.doc(purchaseId);
      final purchaseDoc = await transaction.get(purchaseRef);
      if (!purchaseDoc.exists) throw Exception('Purchase not found');
      final purchase = purchaseDoc.data()!;

      // 2. Verify status and settledAmount
      if (purchase.status != PurchaseStatus.confirmed) {
        throw Exception('Only confirmed purchases can be cancelled');
      }
      if (purchase.settledAmount > 0) {
        throw Exception(
          'Cannot cancel this purchase. ₹${purchase.settledAmount.toStringAsFixed(2)} has already been paid to the supplier. Reverse the supplier payment first.',
        );
      }

      // 3. Read all product documents
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in purchase.items) {
        final prodDoc = await transaction.get(_productRef(item.productId));
        productDocs[item.productId] = prodDoc;
      }

      // 4. Read supplier
      final supplierId = purchase.supplierSnapshot!['supplierId'] as String;
      final supplierDoc = await transaction.get(_supplierRef(supplierId));

      // ── VALIDATE ───────────────────────────────────────
      // 5. Validate stock reversal won't go negative
      for (final item in purchase.items) {
        final prodDoc = productDocs[item.productId];
        if (prodDoc == null || !prodDoc.exists) {
          throw Exception(
            'Product ${item.productNameSnapshot} not found. Cannot cancel.',
          );
        }
        final prodData = prodDoc.data() as Map<String, dynamic>;
        final currentStock = (prodData['stockQuantity'] as num).toDouble();
        final newStock = currentStock - item.quantity;
        if (newStock < 0) {
          throw Exception(
            'Cannot cancel — insufficient stock for ${item.productNameSnapshot}. Current: $currentStock, required to reverse: ${item.quantity}',
          );
        }
      }

      // ── WRITES (all after reads) ───────────────────────
      // 6. Decrease product stock + create CANCELLED_PURCHASE inventory transactions
      for (final item in purchase.items) {
        final prodDoc = productDocs[item.productId]!;
        final prodData = prodDoc.data() as Map<String, dynamic>;
        final currentStock = (prodData['stockQuantity'] as num).toDouble();
        final newStock = currentStock - item.quantity;

        transaction.update(prodDoc.reference, {
          'stockQuantity': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final invTxRef = _inventoryRef().doc();
        final invTx = InventoryTransactionModel(
          businessId: businessId,
          productId: item.productId,
          productName: item.productNameSnapshot,
          type: 'CANCELLED_PURCHASE',
          quantity: item.quantity,
          previousStock: currentStock,
          newStock: newStock,
          reason: 'Cancelled Purchase - ${purchase.purchaseNumber}',
          referenceId: purchaseId,
          createdBy: userId,
        );
        transaction.set(invTxRef, invTx.toFirestore());
      }

      // 7. Reverse supplier outstandingBalance
      if (purchase.payment.balanceAmount != 0 && supplierDoc.exists) {
        final supplierData = supplierDoc.data() as Map<String, dynamic>;
        final openingBalance =
            (supplierData['openingBalance'] as num?)?.toDouble() ?? 0.0;
        final currentOutstanding = supplierData['outstandingBalance'] != null
            ? (supplierData['outstandingBalance'] as num).toDouble()
            : openingBalance;
        final newOutstanding =
            currentOutstanding - purchase.payment.balanceAmount;

        transaction.update(supplierDoc.reference, {
          'outstandingBalance': newOutstanding,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 8. Update purchase status to cancelled
      transaction.update(purchaseRef, {
        'status': PurchaseStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Paginated purchases with optional status filter.
  Future<Map<String, dynamic>> getPurchasesPaginated({
    int limit = 20,
    dynamic startAfter,
    PurchaseStatus? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<PurchaseModel> query = _purchasesRef;

    // Status is filtered client-side below: combining a status equality
    // with the createdAt range/order would require a composite index.
    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(endDate));
    }

    final baseQuery = query.orderBy('createdAt', descending: true);

    // Status is filtered client-side, so keep fetching raw pages until
    // `limit` matching docs are collected or the range is exhausted.
    final List<QueryDocumentSnapshot<PurchaseModel>> filtered = [];
    DocumentSnapshot<PurchaseModel>? cursor =
        startAfter as DocumentSnapshot<PurchaseModel>?;
    var hasMore = true;

    while (filtered.length < limit) {
      var pageQuery = baseQuery;
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }
      final snapshot = await pageQuery.limit(limit + 1).get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }
      final rawHasMore = snapshot.docs.length > limit;
      final pageDocs = rawHasMore
          ? snapshot.docs.sublist(0, limit)
          : snapshot.docs;
      cursor = pageDocs.last;
      if (statusFilter == null) {
        filtered.addAll(pageDocs);
      } else {
        filtered.addAll(
          pageDocs.where((d) => d.data().status == statusFilter),
        );
      }
      if (!rawHasMore) {
        hasMore = false;
        break;
      }
    }

    return {
      'purchases': filtered.map((d) => d.data()).toList(),
      'lastDocument': cursor,
      'hasMore': hasMore,
    };
  }

  /// Today's confirmed purchase total for dashboard.
  Future<double> getTodayConfirmedPurchases() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      final snapshot = await _purchasesRef
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.status == PurchaseStatus.confirmed) {
          total += data.grandTotal;
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getting today confirmed purchases: $e');
      return 0.0;
    }
  }

  Future<PurchaseModel?> getPurchaseById(String purchaseId) async {
    final doc = await _purchasesRef.doc(purchaseId).get();
    return doc.data();
  }
}
