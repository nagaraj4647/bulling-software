import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/features/auth/providers/auth_provider.dart';
import 'package:billing_app/features/business/providers/business_provider.dart';
import 'package:billing_app/features/business/models/business_model.dart';
import 'package:billing_app/features/products/providers/product_provider.dart';
import 'package:billing_app/features/products/models/product_model.dart';
import 'package:billing_app/features/customers/providers/customer_provider.dart';
import 'package:billing_app/features/customers/models/customer_model.dart';
import 'package:billing_app/features/suppliers/providers/supplier_provider.dart';
import 'package:billing_app/features/suppliers/models/supplier_model.dart';
import 'package:billing_app/features/billing/providers/billing_provider.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';
import 'package:billing_app/features/inventory/providers/inventory_provider.dart';
import 'package:billing_app/features/inventory/models/inventory_transaction_model.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid';
  @override
  String? get email => 'test@example.com';
  @override
  String? get displayName => 'Test User';
}

final testBusiness = BusinessModel(
  businessId: 'test_biz_1',
  ownerId: 'test_uid',
  businessName: 'Test Business',
  businessType: 'Retail',
  ownerName: 'Test Owner',
  phone: '1234567890',
  email: 'biz@example.com',
  address: '123 Test St',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final testProductA = ProductModel(
  productId: 'prod_1',
  businessId: 'test_biz_1',
  name: 'Test Product A',
  purchasePrice: 50.0,
  sellingPrice: 100.0,
  stockQuantity: 10,
  lowStockThreshold: 5,
  gstRate: 0.0,
  isActive: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final testProductB = ProductModel(
  productId: 'prod_2',
  businessId: 'test_biz_1',
  name: 'Test Product B',
  purchasePrice: 100.0,
  sellingPrice: 200.0,
  stockQuantity: 5,
  lowStockThreshold: 2,
  gstRate: 0.0,
  isActive: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final testCustomer = CustomerModel(
  customerId: 'cust_1',
  businessId: 'test_biz_1',
  name: 'Test Customer',
  phone: '9876543210',
  email: 'cust@example.com',
  outstandingBalance: 0,
  isActive: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final testSupplier = SupplierModel(
  supplierId: 'supp_1',
  businessId: 'test_biz_1',
  name: 'Test Supplier',
  supplierCode: 'SUP001',
  phone: '5555555555',
  email: 'supp@example.com',
  openingBalance: 0,
  outstandingBalance: 0,
  searchKeywords: ['test'],
  isActive: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final mockProviders = [
  authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
  currentBusinessProvider.overrideWith((ref) => Future.value(testBusiness)),

  // Products
  productsProvider.overrideWith((ref) async* {
    yield mockProductsList;
    yield* mockProductsController.stream;
  }),
  lowStockProductsProvider.overrideWith((ref) => Stream.value([])),

  // Customers
  customersProvider.overrideWith((ref) => Stream.value([testCustomer])),
  paginatedCustomersProvider.overrideWith(
    () => MockPaginatedCustomersNotifier(),
  ),

  // Suppliers
  paginatedSuppliersProvider.overrideWith(
    () => MockPaginatedSuppliersNotifier(),
  ),

  // Billing
  paginatedInvoicesProvider.overrideWith(MockPaginatedInvoicesNotifier.new),
  billingControllerProvider.overrideWith(MockBillingController.new),
  recentInvoicesProvider.overrideWith((ref) => Stream.value([])),
  todaySalesProvider.overrideWith((ref) => Future.value(0.0)),

  // Inventory
  inventoryControllerProvider.overrideWith(MockInventoryController.new),
  inventoryTransactionsProvider.overrideWith(
    (ref, productId) => Stream.value(mockInventoryTransactions),
  ),
];

final mockProductsController = StreamController<List<ProductModel>>.broadcast();
List<ProductModel> mockProductsList = [testProductA, testProductB];
List<InventoryTransactionModel> mockInventoryTransactions = [];

class MockPaginatedCustomersNotifier extends PaginatedCustomersNotifier {
  @override
  PaginatedCustomersState build() {
    return PaginatedCustomersState(
      customers: [testCustomer],
      isLoading: false,
      hasMore: false,
    );
  }

  @override
  Future<void> loadFirstPage() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
}

class MockPaginatedSuppliersNotifier extends PaginatedSuppliersNotifier {
  @override
  PaginatedSuppliersState build() {
    return PaginatedSuppliersState(
      suppliers: [testSupplier],
      isLoading: false,
      hasMore: false,
    );
  }
}

// ─── Billing Mocks ─────────────────────────────────────────────────────────

class MockPaginatedInvoicesNotifier extends PaginatedInvoicesNotifier {
  final List<InvoiceModel> _invoices = [];

  @override
  PaginatedInvoicesState build() {
    return PaginatedInvoicesState(
      invoices: _invoices,
      isLoading: false,
      hasMore: false,
    );
  }

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}

  void addMockInvoice(InvoiceModel invoice) {
    _invoices.insert(0, invoice);
    state = state.copyWith(invoices: List.from(_invoices));
  }
}

class MockBillingController extends BillingController {
  @override
  FutureOr<void> build() {}

  @override
  Future<void> saveDraft(InvoiceModel invoice) async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 100));
    final draft = invoice.copyWith(
      invoiceId: 'draft_1',
      status: InvoiceStatus.draft,
    );
    ref
        .read(paginatedInvoicesProvider.notifier)
        .cast<MockPaginatedInvoicesNotifier>()
        .addMockInvoice(draft);
    state = const AsyncData(null);
  }

  @override
  Future<void> confirmInvoice(InvoiceModel invoice) async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 100));
    final confirmed = invoice.copyWith(
      invoiceId: 'inv_1',
      invoiceNumber: 'INV-000001',
      status: InvoiceStatus.confirmed,
    );
    ref
        .read(paginatedInvoicesProvider.notifier)
        .cast<MockPaginatedInvoicesNotifier>()
        .addMockInvoice(confirmed);
    state = const AsyncData(null);
  }
}

extension on PaginatedInvoicesNotifier {
  T cast<T>() => this as T;
}

// ─── Inventory Mocks ───────────────────────────────────────────────────────

class MockInventoryController extends InventoryController {
  @override
  FutureOr<void> build() {}

  @override
  Future<void> adjustStock({
    required String productId,
    required String type,
    required double quantity,
    required String reason,
  }) async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 100));

    // Simulate stock update on testProductA
    if (productId == 'prod_1') {
      final currentProductA = mockProductsList.firstWhere(
        (p) => p.productId == 'prod_1',
        orElse: () => testProductA,
      );
      double newStock = currentProductA.stockQuantity;

      if (type == 'IN') {
        newStock += quantity;
      } else if (type == 'OUT') {
        newStock -= quantity;
      } else if (type == 'ADJ') {
        newStock = quantity;
      }

      final updatedProduct = currentProductA.copyWith(stockQuantity: newStock);

      // Add transaction
      mockInventoryTransactions.insert(
        0,
        InventoryTransactionModel(
          transactionId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
          businessId: 'test_biz_1',
          productId: productId,
          productName: currentProductA.name,
          type: type,
          quantity: quantity,
          previousStock: currentProductA.stockQuantity,
          newStock: newStock,
          reason: reason,
          createdBy: 'test_user_1',
          createdAt: DateTime.now(),
        ),
      );

      // Update the global list and stream
      mockProductsList = mockProductsList
          .map((p) => p.productId == 'prod_1' ? updatedProduct : p)
          .toList();
      mockProductsController.add(mockProductsList);
    }

    state = const AsyncData(null);
  }
}

// ─── Auth-test-specific mock infrastructure ────────────────────────────────

/// A controllable auth notifier for integration tests.
/// Drives [_currentAuthStream] so GoRouter's refreshListenable is triggered.
///
/// NOTE: AsyncNotifier subclasses must have zero-arg constructors in Riverpod.
/// We use a static field to pass the StreamController before the notifier is built.
class MockAuthNotifier extends AuthNotifier {
  // Set via [createAuthTestProviders] before the ProviderScope is created.
  static late StreamController<User?> _currentAuthStream;

  @override
  FutureOr<void> build() {
    // No-op: initial state is data(null). The stream is already seeded by the test.
  }

  @override
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    // Simulate a brief async login without hitting Firebase.
    await Future.delayed(const Duration(milliseconds: 100));
    _currentAuthStream.add(FakeUser());
    state = const AsyncData(null);
  }

  @override
  Future<void> logout() async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 100));
    _currentAuthStream.add(null);
    state = const AsyncData(null);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 100));
    _currentAuthStream.add(FakeUser());
    state = const AsyncData(null);
  }
}

/// Build provider overrides for the auth flow test.
/// [authStream] is seeded with [null] (= logged out) before calling this.
List<dynamic> createAuthTestProviders(StreamController<User?> authStream) {
  // Set the static stream so MockAuthNotifier can reference it when built.
  MockAuthNotifier._currentAuthStream = authStream;

  return [
    // Auth state driven by our controllable StreamController (starts null = logged out)
    authStateProvider.overrideWith((ref) => authStream.stream),

    // Auth notifier uses MockAuthNotifier so no Firebase calls are made.
    // Zero-arg factory required by Riverpod AsyncNotifierProvider.
    authNotifierProvider.overrideWith(MockAuthNotifier.new),

    // Business: return null when logged out, testBusiness when logged in.
    currentBusinessProvider.overrideWith((ref) async {
      final user = await ref.watch(authStateProvider.future);
      if (user == null) return null;
      return testBusiness;
    }),

    // Products
    productsProvider.overrideWith(
      (ref) => Stream.value([testProductA, testProductB]),
    ),
    lowStockProductsProvider.overrideWith((ref) => Stream.value([])),

    // Customers
    customersProvider.overrideWith((ref) => Stream.value([testCustomer])),
    paginatedCustomersProvider.overrideWith(MockPaginatedCustomersNotifier.new),

    // Suppliers
    paginatedSuppliersProvider.overrideWith(MockPaginatedSuppliersNotifier.new),
  ];
}
