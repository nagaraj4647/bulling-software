import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invoice_model.dart';
import '../../inventory/models/inventory_transaction_model.dart';
import 'billing_calculator.dart';

class BillingService {
  final FirebaseFirestore _firestore;
  final String businessId;
  final String userId;

  BillingService({
    required this.businessId,
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<InvoiceModel> get _invoicesRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('invoices')
        .withConverter<InvoiceModel>(
          fromFirestore: InvoiceModel.fromFirestore,
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

  DocumentReference _customerRef(String customerId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers')
        .doc(customerId);
  }

  CollectionReference _inventoryRef() {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventoryTransactions');
  }

  String _formatInvoiceNumber(int number) {
    return 'INV-${number.toString().padLeft(6, '0')}';
  }

  /// Saves or updates a draft invoice.
  Future<String> saveDraft(InvoiceModel invoice) async {
    final draftInvoice = invoice.copyWith(
      invoiceNumber: '',
      status: InvoiceStatus.draft,
    );
    if (draftInvoice.invoiceId != null && draftInvoice.invoiceId!.isNotEmpty) {
      await _invoicesRef.doc(draftInvoice.invoiceId).set(draftInvoice);
      return draftInvoice.invoiceId!;
    } else {
      final docRef = await _invoicesRef.add(draftInvoice);
      return docRef.id;
    }
  }

  /// Confirms an invoice atomically with strict all-reads-before-writes ordering.
  Future<void> confirmInvoice(InvoiceModel invoice) async {
    // 1. Ensure the draft exists in Firestore first
    String invoiceId = invoice.invoiceId ?? '';
    if (invoiceId.isEmpty) {
      final draftInvoice = invoice.copyWith(
        invoiceNumber: '',
        status: InvoiceStatus.draft,
      );
      final docRef = await _invoicesRef.add(draftInvoice);
      invoiceId = docRef.id;
    }

    final invoiceRef = _invoicesRef.doc(invoiceId);

    // Read business state for GST split
    final businessDoc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .get();
    final businessState = businessDoc.data()?['businessState'] as String?;

    await _firestore.runTransaction((transaction) async {
      // ── READS (All reads must happen before any writes) ──────
      // 1. Re-read live invoice draft document inside transaction
      final invoiceDoc = await transaction.get(invoiceRef);
      if (!invoiceDoc.exists || invoiceDoc.data() == null) {
        throw Exception('Invoice draft not found');
      }
      final liveDraft = invoiceDoc.data()!;

      // 2. Verify live invoice status is draft
      if (liveDraft.status != InvoiceStatus.draft) {
        throw Exception(
          'Only draft invoices can be confirmed. Current status: ${liveDraft.status.name}',
        );
      }
      if (liveDraft.items.isEmpty) {
        throw Exception('At least one item is required to confirm invoice');
      }

      // 3. Read counter
      final counterSnapshot = await transaction.get(_counterRef);

      // 4. Read Customer (if present)
      DocumentSnapshot? customerDoc;
      Map<String, dynamic>? customerData;
      if (liveDraft.customerSnapshot != null) {
        final custRef = _customerRef(liveDraft.customerSnapshot!.customerId);
        customerDoc = await transaction.get(custRef);
        if (!customerDoc.exists) {
          throw Exception('Customer not found');
        }
        customerData = customerDoc.data() as Map<String, dynamic>;
        if (customerData['isActive'] != true) {
          throw Exception('Customer is inactive');
        }
      }

      // 5. Read all referenced products
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in liveDraft.items) {
        final prodDoc = await transaction.get(_productRef(item.productId));
        if (!prodDoc.exists) {
          throw Exception('Product ${item.productNameSnapshot} not found');
        }
        final prodData = prodDoc.data() as Map<String, dynamic>;
        if (prodData['isActive'] != true) {
          throw Exception('Product ${item.productNameSnapshot} is inactive');
        }
        productDocs[item.productId] = prodDoc;
      }

      // ── VALIDATE ─────────────────────────────────────────────
      for (final item in liveDraft.items) {
        if (item.quantity <= 0) {
          throw Exception(
            'Quantity must be greater than 0 for ${item.productNameSnapshot}',
          );
        }
        if (item.unitPrice < 0) {
          throw Exception(
            'Unit price cannot be negative for ${item.productNameSnapshot}',
          );
        }
        if (item.discount < 0) {
          throw Exception(
            'Discount cannot be negative for ${item.productNameSnapshot}',
          );
        }
        final prodDoc = productDocs[item.productId]!;
        final prodData = prodDoc.data() as Map<String, dynamic>;
        final currentStock = (prodData['stockQuantity'] as num).toDouble();
        if (currentStock < item.quantity) {
          throw Exception(
            'Insufficient stock for ${item.productNameSnapshot}. Available: $currentStock, requested: ${item.quantity}',
          );
        }
      }

      // ── COMPUTE ──────────────────────────────────────────────
      // Generate invoice number
      int lastInvoiceNumber = 0;
      if (counterSnapshot.exists && counterSnapshot.data() != null) {
        final counterData = counterSnapshot.data() as Map<String, dynamic>;
        lastInvoiceNumber = counterData['lastInvoiceNumber'] as int? ?? 0;
      }
      lastInvoiceNumber++;
      final generatedInvoiceNumber = _formatInvoiceNumber(lastInvoiceNumber);

      // Rebuild customer snapshot from authoritative customer doc
      CustomerSnapshot? authoritativeCustomerSnapshot;
      String? customerState;
      if (customerDoc != null && customerData != null) {
        customerState = customerData['state'] as String?;
        authoritativeCustomerSnapshot = CustomerSnapshot(
          customerId: customerDoc.id,
          name:
              customerData['name'] as String? ??
              liveDraft.customerSnapshot?.name ??
              '',
          phone: customerData['phone'] as String?,
          address: customerData['address'] as String?,
          city: customerData['city'] as String?,
          state: customerState,
          gstNumber: customerData['gstNumber'] as String?,
        );
      }

      // Rebuild items with live product data & recalculated amounts
      final List<InvoiceItemModel> confirmedItems = [];
      double totalSubtotal = 0;
      double totalDiscount = 0;
      double totalTaxable = 0;
      double totalCgst = 0;
      double totalSgst = 0;
      double totalIgst = 0;

      for (final draftItem in liveDraft.items) {
        final prodData =
            productDocs[draftItem.productId]!.data() as Map<String, dynamic>;
        final authName =
            prodData['name'] as String? ?? draftItem.productNameSnapshot;
        final authSku = prodData['sku'] as String?;
        final authGstRate = (prodData['gstRate'] as num?)?.toDouble() ?? 0.0;

        if (authGstRate > 0) {
          if (businessState == null || businessState.trim().isEmpty) {
            throw Exception('Business state is required for GST calculation');
          }
          if (customerState == null || customerState.trim().isEmpty) {
            throw Exception('Customer state is required for GST calculation');
          }
        }

        final itemSubtotal = BillingCalculator.calculateItemSubtotal(
          draftItem.quantity,
          draftItem.unitPrice,
        );
        final itemDiscount = draftItem.discount;
        final itemTaxable = BillingCalculator.calculateItemTaxableValue(
          itemSubtotal,
          itemDiscount,
        );
        final itemGstAmount = BillingCalculator.calculateGstAmount(
          itemTaxable,
          authGstRate,
        );

        final taxBreakdown = BillingCalculator.determineGstSplit(
          businessState: businessState,
          customerState: customerState,
          gstRate: authGstRate,
          totalGstAmount: itemGstAmount,
        );

        final itemTotal = BillingCalculator.calculateItemTotal(
          itemTaxable,
          itemGstAmount,
        );

        confirmedItems.add(
          InvoiceItemModel(
            productId: draftItem.productId,
            productNameSnapshot: authName,
            skuSnapshot: authSku,
            quantity: draftItem.quantity,
            unitPrice: draftItem.unitPrice,
            discount: itemDiscount,
            taxableValue: itemTaxable,
            gstRate: authGstRate,
            cgstAmount: taxBreakdown.cgst,
            sgstAmount: taxBreakdown.sgst,
            igstAmount: taxBreakdown.igst,
            totalAmount: itemTotal,
          ),
        );

        totalSubtotal += itemSubtotal;
        totalDiscount += itemDiscount;
        totalTaxable += itemTaxable;
        totalCgst += taxBreakdown.cgst;
        totalSgst += taxBreakdown.sgst;
        totalIgst += taxBreakdown.igst;
      }

      totalSubtotal = BillingCalculator.round2(totalSubtotal);
      totalDiscount = BillingCalculator.round2(totalDiscount);
      totalTaxable = BillingCalculator.round2(totalTaxable);
      totalCgst = BillingCalculator.round2(totalCgst);
      totalSgst = BillingCalculator.round2(totalSgst);
      totalIgst = BillingCalculator.round2(totalIgst);
      final totalGrand = BillingCalculator.round2(
        totalTaxable + totalCgst + totalSgst + totalIgst,
      );

      // Payment validation (strict, no silent clamping)
      final paidAmount = liveDraft.payment.paidAmount;
      if (paidAmount < 0) {
        throw Exception('Paid amount cannot be negative');
      }
      if (paidAmount > totalGrand) {
        throw Exception(
          'Paid amount (₹${paidAmount.toStringAsFixed(2)}) cannot exceed grand total (₹${totalGrand.toStringAsFixed(2)})',
        );
      }

      final balanceAmount = BillingCalculator.round2(totalGrand - paidAmount);
      final paymentStatus = paidAmount == totalGrand
          ? 'Paid'
          : paidAmount == 0
          ? 'Unpaid'
          : 'Partially Paid';

      final confirmedPayment = InvoicePayment(
        status: paymentStatus,
        paidAmount: paidAmount,
        balanceAmount: balanceAmount,
        paymentMethod: liveDraft.payment.paymentMethod,
      );

      // ── WRITES (All writes happen strictly after all reads) ───
      // 1. Deduct stock & create SALE inventory transactions
      for (final item in confirmedItems) {
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
          type: 'SALE',
          quantity: item.quantity,
          previousStock: currentStock,
          newStock: newStock,
          reason: 'Sale - $generatedInvoiceNumber',
          referenceId: invoiceRef.id,
          createdBy: userId,
        );
        transaction.set(invTxRef, invTx.toFirestore());
      }

      // 2. Update Customer Outstanding Balance
      if (customerDoc != null && customerData != null && balanceAmount != 0) {
        final openingBalance =
            (customerData['openingBalance'] as num?)?.toDouble() ?? 0.0;
        final currentOutstanding = customerData['outstandingBalance'] != null
            ? (customerData['outstandingBalance'] as num).toDouble()
            : openingBalance;
        final newOutstandingBalance = BillingCalculator.round2(
          currentOutstanding + balanceAmount,
        );

        transaction.update(customerDoc.reference, {
          'outstandingBalance': newOutstandingBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Increment Counter (merge: true — never touches lastSupplierNumber or lastPurchaseNumber)
      transaction.set(_counterRef, {
        'lastInvoiceNumber': lastInvoiceNumber,
      }, SetOptions(merge: true));

      // 4. Update Confirmed Invoice
      final confirmedInvoice = InvoiceModel(
        invoiceId: liveDraft.invoiceId ?? invoiceRef.id,
        businessId: businessId,
        invoiceNumber: generatedInvoiceNumber,
        issueDate: liveDraft.issueDate,
        customerSnapshot:
            authoritativeCustomerSnapshot ?? liveDraft.customerSnapshot,
        items: confirmedItems,
        subtotal: totalSubtotal,
        discountAmount: totalDiscount,
        taxableAmount: totalTaxable,
        cgstTotal: totalCgst,
        sgstTotal: totalSgst,
        igstTotal: totalIgst,
        grandTotal: totalGrand,
        payment: confirmedPayment,
        status: InvoiceStatus.confirmed,
        notes: liveDraft.notes,
        createdAt: liveDraft.createdAt,
      );

      transaction.set(invoiceRef, confirmedInvoice);
    });
  }

  /// Cancels a confirmed invoice atomically with strict all-reads-before-writes ordering.
  Future<void> cancelInvoice(String invoiceId) async {
    await _firestore.runTransaction((transaction) async {
      final invoiceRef = _invoicesRef.doc(invoiceId);

      // ── READS (All reads must happen before any writes) ──────
      // 1. Read invoice
      final invoiceDoc = await transaction.get(invoiceRef);
      if (!invoiceDoc.exists || invoiceDoc.data() == null) {
        throw Exception('Invoice not found');
      }
      final invoiceData = invoiceDoc.data()!;

      // 2. Verify status is confirmed (prevents double cancellation)
      if (invoiceData.status != InvoiceStatus.confirmed) {
        throw Exception(
          'Only confirmed invoices can be cancelled. Current status: ${invoiceData.status.name}',
        );
      }

      // 3. Read all referenced products
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in invoiceData.items) {
        final prodDoc = await transaction.get(_productRef(item.productId));
        productDocs[item.productId] = prodDoc;
      }

      // 4. Read customer document (if present)
      DocumentSnapshot? customerDoc;
      if (invoiceData.customerSnapshot != null) {
        final custRef = _customerRef(invoiceData.customerSnapshot!.customerId);
        customerDoc = await transaction.get(custRef);
      }

      // ── VALIDATE ─────────────────────────────────────────────
      for (final item in invoiceData.items) {
        final prodDoc = productDocs[item.productId];
        if (prodDoc == null || !prodDoc.exists) {
          throw Exception(
            'Product ${item.productNameSnapshot} not found. Cannot cancel invoice.',
          );
        }
        final prodData = prodDoc.data() as Map<String, dynamic>;
        final currentStock = (prodData['stockQuantity'] as num).toDouble();
        final newStock = currentStock + item.quantity;
        if (newStock < 0) {
          throw Exception(
            'Cannot cancel — invalid stock calculation for ${item.productNameSnapshot}',
          );
        }
      }

      // ── WRITES (All writes happen strictly after all reads) ───
      // 5. Restore product stock & write CANCELLED_SALE inventory transactions
      for (final item in invoiceData.items) {
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
          type: 'CANCELLED_SALE',
          quantity: item.quantity,
          previousStock: currentStock,
          newStock: newStock,
          reason: 'Cancelled Sale - ${invoiceData.invoiceNumber}',
          referenceId: invoiceId,
          createdBy: userId,
        );
        transaction.set(invTxRef, invTx.toFirestore());
      }

      // 6. Reverse customer outstanding balance using STORED invoice balance
      if (customerDoc != null &&
          customerDoc.exists &&
          invoiceData.payment.balanceAmount != 0) {
        final custData = customerDoc.data() as Map<String, dynamic>;
        final openingBalance =
            (custData['openingBalance'] as num?)?.toDouble() ?? 0.0;
        final currentOutstanding = custData['outstandingBalance'] != null
            ? (custData['outstandingBalance'] as num).toDouble()
            : openingBalance;
        final newOutstandingBalance = BillingCalculator.round2(
          currentOutstanding - invoiceData.payment.balanceAmount,
        );

        transaction.update(customerDoc.reference, {
          'outstandingBalance': newOutstandingBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 7. Update invoice status to cancelled
      transaction.update(invoiceRef, {
        'status': InvoiceStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Paginated invoices with optional status filter.
  Future<Map<String, dynamic>> getInvoicesPaginated({
    int limit = 20,
    dynamic startAfter,
    InvoiceStatus? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<InvoiceModel> query = _invoicesRef;

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
    // Otherwise a raw page full of excluded docs would look like "no data"
    // even when matching invoices exist further back.
    final List<QueryDocumentSnapshot<InvoiceModel>> filtered = [];
    DocumentSnapshot<InvoiceModel>? cursor =
        startAfter as DocumentSnapshot<InvoiceModel>?;
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
      'invoices': filtered.map((d) => d.data()).toList(),
      'lastDocument': cursor,
      'hasMore': hasMore,
    };
  }

  /// Recent confirmed invoices for dashboard.
  Stream<List<InvoiceModel>> getRecentInvoicesStream({int limit = 5}) {
    // Over-fetch and filter client-side: a status equality combined with
    // the createdAt ordering would require a composite index.
    return _invoicesRef
        .orderBy('createdAt', descending: true)
        .limit(limit * 4)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data())
              .where((invoice) => invoice.status == InvoiceStatus.confirmed)
              .take(limit)
              .toList(),
        );
  }

  /// Today's confirmed sales total for dashboard.
  Future<double> getTodayConfirmedSales() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      final snapshot = await _invoicesRef
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.status == InvoiceStatus.confirmed) {
          total += data.grandTotal;
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getting today confirmed sales: $e');
      return 0.0;
    }
  }

  Future<InvoiceModel?> getInvoiceById(String invoiceId) async {
    final doc = await _invoicesRef.doc(invoiceId).get();
    return doc.data();
  }
}
