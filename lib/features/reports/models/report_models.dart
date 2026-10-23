/// One calendar day's confirmed sales total, used by the sales trend charts.
class DailySalesPoint {
  final DateTime day;
  final double total;

  const DailySalesPoint({required this.day, required this.total});
}

class SalesReportSummary {
  final double totalSales;
  final int invoiceCount;
  final double taxTotal;
  final double discountTotal;

  /// Confirmed sales bucketed per calendar day across the queried range.
  final List<DailySalesPoint> dailyTotals;

  SalesReportSummary({
    this.totalSales = 0.0,
    this.invoiceCount = 0,
    this.taxTotal = 0.0,
    this.discountTotal = 0.0,
    this.dailyTotals = const [],
  });
}

class PurchaseReportSummary {
  final double totalPurchases;
  final int purchaseCount;
  final double taxTotal;
  final double discountTotal;

  PurchaseReportSummary({
    this.totalPurchases = 0.0,
    this.purchaseCount = 0,
    this.taxTotal = 0.0,
    this.discountTotal = 0.0,
  });
}

class ExpenseReportSummary {
  final double totalExpenses;
  final Map<String, double> categoryTotals;

  ExpenseReportSummary({
    this.totalExpenses = 0.0,
    this.categoryTotals = const {},
  });
}

class ProfitReportSummary {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;

  double get netProfit => totalSales - totalPurchases - totalExpenses;

  ProfitReportSummary({
    this.totalSales = 0.0,
    this.totalPurchases = 0.0,
    this.totalExpenses = 0.0,
  });
}
