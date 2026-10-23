import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _firestore;
  final String businessId;

  ExpenseService({required this.businessId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<ExpenseModel> get _expensesRef {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('expenses')
        .withConverter<ExpenseModel>(
          fromFirestore: ExpenseModel.fromFirestore,
          toFirestore: (model, _) => model.toFirestore(),
        );
  }

  /// Creates a draft expense.
  Future<String> saveDraftExpense(ExpenseModel expense) async {
    if (expense.amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }
    final docRef = _expensesRef.doc();
    final toSave = expense.copyWith(
      expenseId: docRef.id,
      status: ExpenseStatus.draft,
    );
    await docRef.set(toSave);
    return docRef.id;
  }

  /// Updates a draft expense.
  Future<void> updateDraftExpense(ExpenseModel expense) async {
    if (expense.expenseId == null) throw Exception('Expense ID required');
    if (expense.amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    // We only update if it is currently a draft, enforced by rules.
    await _expensesRef
        .doc(expense.expenseId)
        .set(expense, SetOptions(merge: true));
  }

  /// Confirms an expense. MUST use a transaction to verify it was a draft.
  Future<void> confirmExpense(String expenseId) async {
    final expenseRef = _expensesRef.doc(expenseId);

    await _firestore.runTransaction((transaction) async {
      // 1. Read expense
      final snapshot = await transaction.get(expenseRef);
      if (!snapshot.exists) {
        throw Exception('Expense not found');
      }

      final expense = snapshot.data()!;
      if (expense.status != ExpenseStatus.draft) {
        throw Exception('Only draft expenses can be confirmed');
      }
      if (expense.businessId != businessId) {
        throw Exception('Unauthorized');
      }

      // 2. Update status
      transaction.update(expenseRef, {
        'status': ExpenseStatus.confirmed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cancels a confirmed expense. MUST use a transaction to verify it was confirmed.
  Future<void> cancelExpense(String expenseId) async {
    final expenseRef = _expensesRef.doc(expenseId);

    await _firestore.runTransaction((transaction) async {
      // 1. Read expense
      final snapshot = await transaction.get(expenseRef);
      if (!snapshot.exists) {
        throw Exception('Expense not found');
      }

      final expense = snapshot.data()!;
      if (expense.status == ExpenseStatus.cancelled) {
        throw Exception('Expense is already cancelled');
      }
      if (expense.status != ExpenseStatus.confirmed &&
          expense.status != ExpenseStatus.draft) {
        throw Exception('Invalid expense status for cancellation');
      }
      if (expense.businessId != businessId) {
        throw Exception('Unauthorized');
      }

      // 2. Update status
      transaction.update(expenseRef, {
        'status': ExpenseStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cursor-based pagination for expenses.
  /// Ordered by expenseDate DESC.
  Future<Map<String, dynamic>> getExpensesPaginated({
    int limit = 20,
    dynamic startAfter,
    ExpenseStatus? statusFilter,
    ExpenseCategory? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<ExpenseModel> query = _expensesRef;

    // Status and category are filtered client-side below: combining them
    // with the expenseDate range/order would require a composite index.
    if (startDate != null) {
      query = query.where(
        'expenseDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'expenseDate',
        isLessThan: Timestamp.fromDate(endDate),
      );
    }

    final baseQuery = query.orderBy('expenseDate', descending: true);

    // Status/category are filtered client-side, so keep fetching raw pages
    // until `limit` matching docs are collected or the range is exhausted.
    final List<QueryDocumentSnapshot<ExpenseModel>> filtered = [];
    DocumentSnapshot<ExpenseModel>? cursor =
        startAfter as DocumentSnapshot<ExpenseModel>?;
    var hasMore = true;

    bool matches(ExpenseModel expense) {
      if (statusFilter != null && expense.status != statusFilter) {
        return false;
      }
      if (categoryFilter != null && expense.category != categoryFilter) {
        return false;
      }
      return true;
    }

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
      filtered.addAll(pageDocs.where((d) => matches(d.data())));
      if (!rawHasMore) {
        hasMore = false;
        break;
      }
    }

    return {
      'expenses': filtered.map((d) => d.data()).toList(),
      'lastDocument': cursor,
      'hasMore': hasMore,
    };
  }

  /// Dashboard calculation: Sum of confirmed expenses where expenseDate falls on today.
  Future<double> getTodayConfirmedExpenses() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      final querySnapshot = await _expensesRef
          .where(
            'expenseDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .where('expenseDate', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .get();

      double total = 0.0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.status == ExpenseStatus.confirmed) {
          total += data.amount;
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getting today confirmed expenses: $e');
      return 0.0;
    }
  }
}
