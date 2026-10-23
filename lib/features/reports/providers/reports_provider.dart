import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../data/reports_service.dart';
import '../models/report_models.dart';
import 'reports_pagination_state.dart';

import '../../billing/providers/billing_provider.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';

import '../../billing/models/invoice_model.dart';
import '../../purchases/models/purchase_model.dart';
import '../../expenses/models/expense_model.dart';
import '../../products/models/product_model.dart';
import '../../customers/models/customer_model.dart';
import '../../suppliers/models/supplier_model.dart';

enum ReportType { sales, purchase, expense, profit, stock, customer, supplier }

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.sales:
        return 'Sales';
      case ReportType.purchase:
        return 'Purchases';
      case ReportType.expense:
        return 'Expenses';
      case ReportType.profit:
        return 'Profit';
      case ReportType.stock:
        return 'Stock';
      case ReportType.customer:
        return 'Customers';
      case ReportType.supplier:
        return 'Suppliers';
    }
  }
}

final reportsServiceProvider = Provider<ReportsService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;
  return ReportsService(business.businessId!);
});

class ReportTypeNotifier extends Notifier<ReportType> {
  @override
  ReportType build() => ReportType.sales;

  void setType(ReportType type) {
    state = type;
  }
}

final reportTypeProvider = NotifierProvider<ReportTypeNotifier, ReportType>(
  ReportTypeNotifier.new,
);

class DateRangeState {
  final DateTime start;
  final DateTime end;

  DateRangeState(this.start, this.end);
}

class ReportDateRangeNotifier extends Notifier<DateRangeState> {
  @override
  DateRangeState build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return DateRangeState(start, end);
  }

  void setDateRange(DateRangeState range) {
    state = range;
  }
}

final reportDateRangeProvider =
    NotifierProvider<ReportDateRangeNotifier, DateRangeState>(
      ReportDateRangeNotifier.new,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Summaries (Completely Independent of Pagination)
// ─────────────────────────────────────────────────────────────────────────────

final salesReportSummaryProvider = FutureProvider<SalesReportSummary>((
  ref,
) async {
  final service = ref.watch(reportsServiceProvider);
  if (service == null) return SalesReportSummary();
  final dateRange = ref.watch(reportDateRangeProvider);
  return service.getSalesSummary(dateRange.start, dateRange.end);
});

/// Trailing 7-day confirmed sales trend for the dashboard chart.
final dashboardWeeklySalesTrendProvider = FutureProvider<List<DailySalesPoint>>((
  ref,
) async {
  final service = ref.watch(reportsServiceProvider);
  if (service == null) return const <DailySalesPoint>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return service.getDailySalesTrend(
    today.subtract(const Duration(days: 6)),
    today.add(const Duration(days: 1)),
  );
});

final purchaseReportSummaryProvider = FutureProvider<PurchaseReportSummary>((
  ref,
) async {
  final service = ref.watch(reportsServiceProvider);
  if (service == null) return PurchaseReportSummary();
  final dateRange = ref.watch(reportDateRangeProvider);
  return service.getPurchaseSummary(dateRange.start, dateRange.end);
});

final expenseReportSummaryProvider = FutureProvider<ExpenseReportSummary>((
  ref,
) async {
  final service = ref.watch(reportsServiceProvider);
  if (service == null) return ExpenseReportSummary();
  final dateRange = ref.watch(reportDateRangeProvider);
  return service.getExpenseSummary(dateRange.start, dateRange.end);
});

final profitReportSummaryProvider = FutureProvider<ProfitReportSummary>((
  ref,
) async {
  final service = ref.watch(reportsServiceProvider);
  if (service == null) return ProfitReportSummary();
  final dateRange = ref.watch(reportDateRangeProvider);
  return service.getProfitSummary(dateRange.start, dateRange.end);
});

// ─────────────────────────────────────────────────────────────────────────────
// 1. Sales Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportSalesNotifier extends Notifier<PaginatedReportState<InvoiceModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<InvoiceModel> build() {
    ref.listen<DateRangeState>(reportDateRangeProvider, (previous, next) {
      if (previous?.start != next.start || previous?.end != next.end) {
        loadInitial();
      }
    });
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<InvoiceModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<InvoiceModel>(isLoading: true);
    try {
      final billingService = ref.read(billingServiceProvider);
      if (billingService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await billingService.getInvoicesPaginated(
        limit: pageSize,
        statusFilter: InvoiceStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      state = PaginatedReportState<InvoiceModel>(
        items: result['invoices'] as List<InvoiceModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final billingService = ref.read(billingServiceProvider);
      if (billingService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await billingService.getInvoicesPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
        statusFilter: InvoiceStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      final newItems = result['invoices'] as List<InvoiceModel>;
      final existingIds = state.items.map((i) => i.invoiceId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.invoiceId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportSalesProvider =
    NotifierProvider<ReportSalesNotifier, PaginatedReportState<InvoiceModel>>(
      ReportSalesNotifier.new,
    );

// ─────────────────────────────────────────────────────────────────────────────
// 2. Purchase Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportPurchasesNotifier
    extends Notifier<PaginatedReportState<PurchaseModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<PurchaseModel> build() {
    ref.listen<DateRangeState>(reportDateRangeProvider, (previous, next) {
      if (previous?.start != next.start || previous?.end != next.end) {
        loadInitial();
      }
    });
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<PurchaseModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<PurchaseModel>(isLoading: true);
    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      if (purchaseService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await purchaseService.getPurchasesPaginated(
        limit: pageSize,
        statusFilter: PurchaseStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      state = PaginatedReportState<PurchaseModel>(
        items: result['purchases'] as List<PurchaseModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      if (purchaseService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await purchaseService.getPurchasesPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
        statusFilter: PurchaseStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      final newItems = result['purchases'] as List<PurchaseModel>;
      final existingIds = state.items.map((i) => i.purchaseId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.purchaseId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportPurchasesProvider =
    NotifierProvider<
      ReportPurchasesNotifier,
      PaginatedReportState<PurchaseModel>
    >(ReportPurchasesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// 3. Expense Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportExpensesNotifier
    extends Notifier<PaginatedReportState<ExpenseModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<ExpenseModel> build() {
    ref.listen<DateRangeState>(reportDateRangeProvider, (previous, next) {
      if (previous?.start != next.start || previous?.end != next.end) {
        loadInitial();
      }
    });
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<ExpenseModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<ExpenseModel>(isLoading: true);
    try {
      final expenseService = ref.read(expenseServiceProvider);
      if (expenseService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await expenseService.getExpensesPaginated(
        limit: pageSize,
        statusFilter: ExpenseStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      state = PaginatedReportState<ExpenseModel>(
        items: result['expenses'] as List<ExpenseModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final expenseService = ref.read(expenseServiceProvider);
      if (expenseService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final dateRange = ref.read(reportDateRangeProvider);
      final result = await expenseService.getExpensesPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
        statusFilter: ExpenseStatus.confirmed,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      final newItems = result['expenses'] as List<ExpenseModel>;
      final existingIds = state.items.map((i) => i.expenseId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.expenseId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportExpensesProvider =
    NotifierProvider<
      ReportExpensesNotifier,
      PaginatedReportState<ExpenseModel>
    >(ReportExpensesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// 4. Product / Stock Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportProductsNotifier
    extends Notifier<PaginatedReportState<ProductModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<ProductModel> build() {
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<ProductModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<ProductModel>(isLoading: true);
    try {
      final productService = ref.read(productServiceProvider);
      if (productService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final result = await productService.getProductsPaginated(limit: pageSize);
      state = PaginatedReportState<ProductModel>(
        items: result['products'] as List<ProductModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final productService = ref.read(productServiceProvider);
      if (productService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final result = await productService.getProductsPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
      );
      final newItems = result['products'] as List<ProductModel>;
      final existingIds = state.items.map((i) => i.productId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.productId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportProductsProvider =
    NotifierProvider<
      ReportProductsNotifier,
      PaginatedReportState<ProductModel>
    >(ReportProductsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// 5. Customer Outstanding Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportCustomersNotifier
    extends Notifier<PaginatedReportState<CustomerModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<CustomerModel> build() {
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<CustomerModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<CustomerModel>(isLoading: true);
    try {
      final customerService = ref.read(customerServiceProvider);
      if (customerService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final result = await customerService.getCustomersPaginated(
        limit: pageSize,
      );
      state = PaginatedReportState<CustomerModel>(
        items: result['customers'] as List<CustomerModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final customerService = ref.read(customerServiceProvider);
      if (customerService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final result = await customerService.getCustomersPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
      );
      final newItems = result['customers'] as List<CustomerModel>;
      final existingIds = state.items.map((i) => i.customerId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.customerId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportCustomersProvider =
    NotifierProvider<
      ReportCustomersNotifier,
      PaginatedReportState<CustomerModel>
    >(ReportCustomersNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// 6. Supplier Outstanding Report Detail Pagination Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ReportSuppliersNotifier
    extends Notifier<PaginatedReportState<SupplierModel>> {
  static const int pageSize = 20;

  @override
  PaginatedReportState<SupplierModel> build() {
    Future.microtask(() => loadInitial());
    return const PaginatedReportState<SupplierModel>(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedReportState<SupplierModel>(isLoading: true);
    try {
      final supplierService = ref.read(supplierServiceProvider);
      if (supplierService == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final result = await supplierService.getSuppliersPaginated(
        limit: pageSize,
      );
      state = PaginatedReportState<SupplierModel>(
        items: result['suppliers'] as List<SupplierModel>,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final supplierService = ref.read(supplierServiceProvider);
      if (supplierService == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final result = await supplierService.getSuppliersPaginated(
        limit: pageSize,
        startAfter: state.lastDoc,
      );
      final newItems = result['suppliers'] as List<SupplierModel>;
      final existingIds = state.items.map((i) => i.supplierId).toSet();
      final deduplicated = newItems
          .where((i) => !existingIds.contains(i.supplierId))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...deduplicated],
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
        hasMore: result['hasMore'] as bool,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final reportSuppliersProvider =
    NotifierProvider<
      ReportSuppliersNotifier,
      PaginatedReportState<SupplierModel>
    >(ReportSuppliersNotifier.new);
