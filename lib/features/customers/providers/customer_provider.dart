import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../data/customer_service.dart';
import '../models/customer_model.dart';

final customerServiceProvider = Provider<CustomerService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;
  return CustomerService(business.businessId!);
});

// ──────────────────────────────────────────────────────────────────────────────
// Paginated Customers State
// ──────────────────────────────────────────────────────────────────────────────

class PaginatedCustomersState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  const PaginatedCustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  PaginatedCustomersState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    String? error,
    bool clearLastDocument = false,
  }) {
    return PaginatedCustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: clearLastDocument
          ? null
          : (lastDocument ?? this.lastDocument),
      error: error,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Paginated Customers Notifier
// ──────────────────────────────────────────────────────────────────────────────

class PaginatedCustomersNotifier extends Notifier<PaginatedCustomersState> {
  static const int _pageSize = 20;

  @override
  PaginatedCustomersState build() {
    // Auto-load first page when the notifier is built
    Future.microtask(() => loadFirstPage());
    return const PaginatedCustomersState(isLoading: true);
  }

  bool? get _activeFilter {
    final filter = ref.read(customerFilterProvider);
    switch (filter) {
      case CustomerFilter.active:
        return true;
      case CustomerFilter.inactive:
        return false;
      case CustomerFilter.all:
        return null;
    }
  }

  Future<void> loadFirstPage() async {
    final service = ref.read(customerServiceProvider);
    if (service == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Customer service not available',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await service.getCustomersPaginated(
        limit: _pageSize,
        isActive: _activeFilter,
      );

      state = PaginatedCustomersState(
        customers: result['customers'] as List<CustomerModel>,
        isLoading: false,
        hasMore: result['hasMore'] as bool,
        lastDocument: result['lastDocument'] as DocumentSnapshot?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    final service = ref.read(customerServiceProvider);
    if (service == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final result = await service.getCustomersPaginated(
        limit: _pageSize,
        startAfter: state.lastDocument,
        isActive: _activeFilter,
      );

      final newCustomers = result['customers'] as List<CustomerModel>;

      state = state.copyWith(
        customers: [...state.customers, ...newCustomers],
        isLoading: false,
        hasMore: result['hasMore'] as bool,
        lastDocument: result['lastDocument'] as DocumentSnapshot?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Resets pagination and reloads from the first page.
  Future<void> refresh() async {
    state = const PaginatedCustomersState(isLoading: true);
    await loadFirstPage();
  }
}

final paginatedCustomersProvider =
    NotifierProvider<PaginatedCustomersNotifier, PaginatedCustomersState>(
      PaginatedCustomersNotifier.new,
    );

// ──────────────────────────────────────────────────────────────────────────────
// Legacy stream provider — kept for backward compatibility
// Used by: dashboard_home_view.dart, new_invoice_screen.dart customer picker,
//          customer_form_screen.dart (edit mode loading),
//          customer_details_screen.dart
// ──────────────────────────────────────────────────────────────────────────────

final customersProvider = StreamProvider<List<CustomerModel>>((ref) {
  final service = ref.watch(customerServiceProvider);
  if (service == null) return const Stream.empty();
  return service.getCustomers();
});

// ──────────────────────────────────────────────────────────────────────────────
// Customer Controller (create/update/deactivate)
// ──────────────────────────────────────────────────────────────────────────────

class CustomerController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createCustomer(CustomerModel customer) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerServiceProvider);
      if (service == null) throw Exception('Customer service not available');
      await service.createCustomer(customer);
      // Refresh paginated list after creation
      ref.read(paginatedCustomersProvider.notifier).refresh();
    });
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerServiceProvider);
      if (service == null) throw Exception('Customer service not available');
      await service.updateCustomerProfile(customer);
      // Refresh paginated list after update
      ref.read(paginatedCustomersProvider.notifier).refresh();
    });
  }

  Future<void> deactivateCustomer(String customerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerServiceProvider);
      if (service == null) throw Exception('Customer service not available');
      await service.deactivateCustomer(customerId);
      // Refresh paginated list after deactivation
      ref.read(paginatedCustomersProvider.notifier).refresh();
    });
  }
}

final customerControllerProvider =
    AsyncNotifierProvider<CustomerController, void>(CustomerController.new);

// ──────────────────────────────────────────────────────────────────────────────
// Filters & Search
// ──────────────────────────────────────────────────────────────────────────────

enum CustomerFilter { all, active, inactive }

class CustomerFilterNotifier extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() => CustomerFilter.all;
  void setFilter(CustomerFilter filter) {
    state = filter;
    // Re-fetch from Firestore with the new filter
    ref.read(paginatedCustomersProvider.notifier).refresh();
  }
}

final customerFilterProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilter>(
      CustomerFilterNotifier.new,
    );

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final customerSearchQueryProvider =
    NotifierProvider<CustomerSearchQueryNotifier, String>(
      CustomerSearchQueryNotifier.new,
    );

// ──────────────────────────────────────────────────────────────────────────────
// Client-side filtered view of paginated customers (for CustomersScreen)
// ──────────────────────────────────────────────────────────────────────────────

final paginatedFilteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final paginatedState = ref.watch(paginatedCustomersProvider);
  final query = ref.watch(customerSearchQueryProvider).toLowerCase();

  if (query.isEmpty) return paginatedState.customers;

  return paginatedState.customers.where((c) {
    return c.name.toLowerCase().contains(query) ||
        (c.phone?.toLowerCase().contains(query) ?? false) ||
        (c.email?.toLowerCase().contains(query) ?? false);
  }).toList();
});

// ──────────────────────────────────────────────────────────────────────────────
// Legacy filtered provider — kept for billing module CustomerPickerSheet
// Uses the stream-based customersProvider for full list access.
// ──────────────────────────────────────────────────────────────────────────────

final filteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersProvider).value ?? [];
  final filter = ref.watch(customerFilterProvider);
  final query = ref.watch(customerSearchQueryProvider).toLowerCase();

  return customers.where((c) {
    // Text search
    final matchesQuery =
        query.isEmpty ||
        c.name.toLowerCase().contains(query) ||
        (c.phone?.toLowerCase().contains(query) ?? false) ||
        (c.email?.toLowerCase().contains(query) ?? false);

    if (!matchesQuery) return false;

    // Status filter
    switch (filter) {
      case CustomerFilter.all:
        return true;
      case CustomerFilter.active:
        return c.isActive;
      case CustomerFilter.inactive:
        return !c.isActive;
    }
  }).toList();
});
