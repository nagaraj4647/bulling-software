import 'package:cloud_firestore/cloud_firestore.dart';

import '../../billing/models/invoice_model.dart';
import '../../purchases/models/purchase_model.dart';
import '../../expenses/models/expense_model.dart';
import '../models/report_models.dart';

class ReportsService {
  final FirebaseFirestore _firestore;
  final String businessId;

  ReportsService(this.businessId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invoicesRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('invoices');
  CollectionReference<Map<String, dynamic>> get _purchasesRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('purchases');
  CollectionReference<ExpenseModel> get _expensesRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('expenses')
      .withConverter<ExpenseModel>(
        fromFirestore: ExpenseModel.fromFirestore,
        toFirestore: (model, _) => model.toFirestore(),
      );

  /// Buckets (timestamp, total) entries into one total per local calendar
  /// day over [start, end). `end` is exclusive; a non-midnight `end` is
  /// rounded up to cover its day. Days with no entries are zero-filled so
  /// charts render gaps honestly. Local dates are used throughout (the app
  /// targets IST, which has no DST).
  static List<DailySalesPoint> bucketDailyTotals(
    Iterable<({DateTime at, double total})> entries,
    DateTime start,
    DateTime end,
  ) {
    final firstDay = DateTime(start.year, start.month, start.day);
    var lastExclusive = DateTime(end.year, end.month, end.day);
    if (end != lastExclusive) {
      lastExclusive = lastExclusive.add(const Duration(days: 1));
    }
    final dayCount = lastExclusive.difference(firstDay).inDays;
    if (dayCount <= 0) return const [];
    final totals = List<double>.filled(dayCount, 0.0);
    for (final e in entries) {
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      final index = day.difference(firstDay).inDays;
      if (index >= 0 && index < dayCount) totals[index] += e.total;
    }
    return List.generate(
      dayCount,
      (i) => DailySalesPoint(
        day: firstDay.add(Duration(days: i)),
        total: totals[i],
      ),
    );
  }

  /// Per-day confirmed sales over [start, end) for trend charts. Same
  /// index-free single-field date query as the summaries: only `createdAt`
  /// range is filtered server-side, status is filtered client-side.
  Future<List<DailySalesPoint>> getDailySalesTrend(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _invoicesRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final entries = <({DateTime at, double total})>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] != InvoiceStatus.confirmed.name) continue;
      final ts = data['createdAt'];
      if (ts is! Timestamp) continue;
      entries.add((
        at: ts.toDate(),
        total: (data['grandTotal'] as num?)?.toDouble() ?? 0.0,
      ));
    }
    return bucketDailyTotals(entries, start, end);
  }

  Future<SalesReportSummary> getSalesSummary(
    DateTime start,
    DateTime end,
  ) async {
    // Single-field range query only: adding a status equality here would
    // require a composite index, so status is filtered client-side.
    final snapshot = await _invoicesRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    double totalSales = 0.0;
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;
    double discount = 0.0;
    int count = 0;

    final dailyEntries = <({DateTime at, double total})>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] != InvoiceStatus.confirmed.name) continue;
      count++;
      final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
      totalSales += grandTotal;
      cgst += (data['cgstTotal'] as num?)?.toDouble() ?? 0.0;
      sgst += (data['sgstTotal'] as num?)?.toDouble() ?? 0.0;
      igst += (data['igstTotal'] as num?)?.toDouble() ?? 0.0;
      discount += (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final ts = data['createdAt'];
      if (ts is Timestamp) dailyEntries.add((at: ts.toDate(), total: grandTotal));
    }

    return SalesReportSummary(
      totalSales: totalSales,
      invoiceCount: count,
      taxTotal: cgst + sgst + igst,
      discountTotal: discount,
      dailyTotals: bucketDailyTotals(dailyEntries, start, end),
    );
  }

  Future<PurchaseReportSummary> getPurchaseSummary(
    DateTime start,
    DateTime end,
  ) async {
    // Single-field range query only: adding a status equality here would
    // require a composite index, so status is filtered client-side.
    final snapshot = await _purchasesRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    double totalPurchases = 0.0;
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;
    double discount = 0.0;
    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] != PurchaseStatus.confirmed.name) continue;
      count++;
      totalPurchases += (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
      cgst += (data['cgstTotal'] as num?)?.toDouble() ?? 0.0;
      sgst += (data['sgstTotal'] as num?)?.toDouble() ?? 0.0;
      igst += (data['igstTotal'] as num?)?.toDouble() ?? 0.0;
      discount += (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
    }

    return PurchaseReportSummary(
      totalPurchases: totalPurchases,
      purchaseCount: count,
      taxTotal: cgst + sgst + igst,
      discountTotal: discount,
    );
  }

  Future<ExpenseReportSummary> getExpenseSummary(
    DateTime start,
    DateTime end,
  ) async {
    // Single-field range query only: adding a status equality here would
    // require a composite index, so status is filtered client-side.
    final querySnapshot = await _expensesRef
        .where('expenseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('expenseDate', isLessThan: Timestamp.fromDate(end))
        .get();

    double total = 0.0;
    final Map<String, double> categoryTotals = {};

    for (var doc in querySnapshot.docs) {
      final expense = doc.data();
      if (expense.status != ExpenseStatus.confirmed) continue;
      total += expense.amount;
      final catName = expense.category.name;
      categoryTotals[catName] =
          (categoryTotals[catName] ?? 0.0) + expense.amount;
    }

    return ExpenseReportSummary(
      totalExpenses: total,
      categoryTotals: categoryTotals,
    );
  }

  Future<ProfitReportSummary> getProfitSummary(
    DateTime start,
    DateTime end,
  ) async {
    final sales = await getSalesSummary(start, end);
    final purchases = await getPurchaseSummary(start, end);
    final expenses = await getExpenseSummary(start, end);

    return ProfitReportSummary(
      totalSales: sales.totalSales,
      totalPurchases: purchases.totalPurchases,
      totalExpenses: expenses.totalExpenses,
    );
  }
}
