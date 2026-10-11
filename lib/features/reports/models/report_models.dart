class SalesReportSummary {
  final double totalSales;
  final int invoiceCount;
  final double taxTotal;
  final double discountTotal;

  SalesReportSummary({
    this.totalSales = 0.0,
    this.invoiceCount = 0,
    this.taxTotal = 0.0,
    this.discountTotal = 0.0,
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
