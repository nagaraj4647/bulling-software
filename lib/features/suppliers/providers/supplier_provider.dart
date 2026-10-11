import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../models/supplier_model.dart';
import '../data/supplier_service.dart';

final supplierServiceProvider = Provider<SupplierService?>((ref) {
  final currentBusiness = ref.watch(currentBusinessProvider).value;
  if (currentBusiness == null) return null;
  return SupplierService(businessId: currentBusiness.businessId!);
});

class PaginatedSuppliersState {
  final List<SupplierModel> suppliers;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDoc;

  PaginatedSuppliersState({
    required this.suppliers,
    required this.isLoading,
    required this.hasMore,
    this.error,
    this.lastDoc,
  });

  PaginatedSuppliersState copyWith({
    List<SupplierModel>? suppliers,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDoc,
  }) {
    return PaginatedSuppliersState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}

enum SupplierFilter { all, active, inactive }

final supplierFilterProvider =
    NotifierProvider<SupplierFilterNotifier, SupplierFilter>(
      SupplierFilterNotifier.new,
    );

class SupplierFilterNotifier extends Notifier<SupplierFilter> {
  @override
  SupplierFilter build() => SupplierFilter.all;

  void setFilter(SupplierFilter filter) {
    state = filter;
  }
}

class SupplierSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final supplierSearchQueryProvider =
    NotifierProvider<SupplierSearchQueryNotifier, String>(
      SupplierSearchQueryNotifier.new,
    );

class PaginatedSuppliersNotifier extends Notifier<PaginatedSuppliersState> {
  static const int _limit = 20;

  @override
  PaginatedSuppliersState build() {
    // Listen to filter and search changes to reset and reload
    ref.listen(supplierFilterProvider, (_, _) => _initialLoad());
    ref.listen(supplierSearchQueryProvider, (_, _) => _initialLoad());

    // Initial load happens after build
    Future.microtask(() => _initialLoad());
    return PaginatedSuppliersState(
      suppliers: [],
      isLoading: true,
      hasMore: true,
    );
  }

  Future<void> _initialLoad() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      suppliers: [],
      lastDoc: null,
      hasMore: true,
    );
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    await _fetchPage();
  }

  Future<void> refresh() async {
    await _initialLoad();
  }

  Future<void> _fetchPage() async {
    try {
      final service = ref.read(supplierServiceProvider);
      if (service == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Service not available',
        );
        return;
      }

      final filter = ref.read(supplierFilterProvider);
      bool? activeOnly;
      if (filter == SupplierFilter.active) activeOnly = true;
      if (filter == SupplierFilter.inactive) activeOnly = false;

      final searchQuery = ref.read(supplierSearchQueryProvider);

      final snapshot = await service.getSuppliersSnapshotPaginated(
        limit: _limit,
        startAfter: state.lastDoc,
        activeOnly: activeOnly,
        searchQuery: searchQuery,
      );

      final newSuppliers = snapshot.docs.map((doc) => doc.data()).toList();
      final hasMore = newSuppliers.length == _limit;
      final lastDoc = snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : state.lastDoc;

      state = state.copyWith(
        suppliers: [...state.suppliers, ...newSuppliers],
        isLoading: false,
        hasMore: hasMore,
        lastDoc: lastDoc,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paginatedSuppliersProvider =
    NotifierProvider<PaginatedSuppliersNotifier, PaginatedSuppliersState>(
      PaginatedSuppliersNotifier.new,
    );

class SupplierController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createSupplier(SupplierModel supplier) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supplierServiceProvider);
      if (service == null) throw Exception('Supplier service not available');
      await service.createSupplier(supplier);
      ref.read(paginatedSuppliersProvider.notifier).refresh();
    });
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supplierServiceProvider);
      if (service == null) throw Exception('Supplier service not available');
      await service.updateSupplier(supplier);
      ref.read(paginatedSuppliersProvider.notifier).refresh();
    });
  }

  Future<void> toggleSupplierStatus(String supplierId, bool isActive) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supplierServiceProvider);
      if (service == null) throw Exception('Supplier service not available');
      await service.toggleSupplierStatus(supplierId, isActive);
      ref.read(paginatedSuppliersProvider.notifier).refresh();
    });
  }
}

final supplierControllerProvider =
    AsyncNotifierProvider<SupplierController, void>(SupplierController.new);

final supplierDetailsProvider = FutureProvider.family<SupplierModel?, String>((
  ref,
  supplierId,
) async {
  // Try to find it in the paginated list first to avoid extra reads
  final state = ref.watch(paginatedSuppliersProvider);
  final existing = state.suppliers
      .where((s) => s.supplierId == supplierId)
      .firstOrNull;
  if (existing != null) return existing;

  // Otherwise fallback to a direct fetch if we want, but for now we just return null
  // and handle it in the UI (or we could write a fetchSupplierById method in the service).
  // Given standard Firestore usage, we can just do a direct read:
  final service = ref.read(supplierServiceProvider);
  if (service == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('businesses')
      .doc(service.businessId)
      .collection('suppliers')
      .doc(supplierId)
      .get();
  if (doc.exists) {
    return SupplierModel.fromFirestore(doc);
  }
  return null;
});
