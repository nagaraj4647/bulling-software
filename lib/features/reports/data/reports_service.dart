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

  Future<SalesReportSummary> getSalesSummary(
    DateTime start,
    DateTime end,
  ) async {
    final query = _invoicesRef
        .where('status', isEqualTo: InvoiceStatus.confirmed.name)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end));

    final aggregateQuery = query.aggregate(
      sum('grandTotal'),
      sum('cgstTotal'),
      sum('sgstTotal'),
      sum('igstTotal'),
      sum('discountAmount'),
      count(),
    );

    final snapshot = await aggregateQuery.get();

    final taxTotal =
        (snapshot.getSum('cgstTotal') ?? 0.0) +
        (snapshot.getSum('sgstTotal') ?? 0.0) +
        (snapshot.getSum('igstTotal') ?? 0.0);

    return SalesReportSummary(
      totalSales: snapshot.getSum('grandTotal') ?? 0.0,
      invoiceCount: snapshot.count ?? 0,
      taxTotal: taxTotal,
      discountTotal: snapshot.getSum('discountAmount') ?? 0.0,
    );
  }

  Future<PurchaseReportSummary> getPurchaseSummary(
    DateTime start,
    DateTime end,
  ) async {
    final query = _purchasesRef
        .where('status', isEqualTo: PurchaseStatus.confirmed.name)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end));

    final aggregateQuery = query.aggregate(
      sum('grandTotal'),
      sum('cgstTotal'),
      sum('sgstTotal'),
      sum('igstTotal'),
      sum('discountAmount'),
      count(),
    );

    final snapshot = await aggregateQuery.get();

    final taxTotal =
        (snapshot.getSum('cgstTotal') ?? 0.0) +
        (snapshot.getSum('sgstTotal') ?? 0.0) +
        (snapshot.getSum('igstTotal') ?? 0.0);

    return PurchaseReportSummary(
      totalPurchases: snapshot.getSum('grandTotal') ?? 0.0,
      purchaseCount: snapshot.count ?? 0,
      taxTotal: taxTotal,
      discountTotal: snapshot.getSum('discountAmount') ?? 0.0,
    );
  }

  Future<ExpenseReportSummary> getExpenseSummary(
    DateTime start,
    DateTime end,
  ) async {
    final querySnapshot = await _expensesRef
        .where('status', isEqualTo: ExpenseStatus.confirmed.name)
        .where('expenseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('expenseDate', isLessThan: Timestamp.fromDate(end))
        .get();

    double total = 0.0;
    final Map<String, double> categoryTotals = {};

    for (var doc in querySnapshot.docs) {
      final expense = doc.data();
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
