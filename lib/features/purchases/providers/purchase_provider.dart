import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/purchase_model.dart';
import '../data/purchase_service.dart';

final purchaseServiceProvider = Provider<PurchaseService?>((ref) {
  final currentBusiness = ref.watch(currentBusinessProvider).value;
  final user = ref.watch(authStateProvider).value;
  if (currentBusiness == null || user == null) return null;
  return PurchaseService(
    businessId: currentBusiness.businessId!,
    userId: user.uid,
  );
});

// Status filter
enum PurchaseFilter { all, draft, confirmed, cancelled }

class PurchaseFilterNotifier extends Notifier<PurchaseFilter> {
  @override
  PurchaseFilter build() => PurchaseFilter.all;

  void setFilter(PurchaseFilter filter) {
    state = filter;
  }
}

final purchaseFilterProvider =
    NotifierProvider<PurchaseFilterNotifier, PurchaseFilter>(
      PurchaseFilterNotifier.new,
    );

// Paginated state
class PaginatedPurchasesState {
  final List<PurchaseModel> purchases;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDoc;

  PaginatedPurchasesState({
    required this.purchases,
    required this.isLoading,
    required this.hasMore,
    this.error,
    this.lastDoc,
  });

  PaginatedPurchasesState copyWith({
    List<PurchaseModel>? purchases,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDoc,
  }) {
    return PaginatedPurchasesState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}

class PaginatedPurchasesNotifier extends Notifier<PaginatedPurchasesState> {
  static const int _limit = 20;

  @override
  PaginatedPurchasesState build() {
    ref.listen(purchaseFilterProvider, (_, _) => _initialLoad());
    Future.microtask(() => _initialLoad());
    return PaginatedPurchasesState(
      purchases: [],
      isLoading: true,
      hasMore: true,
    );
  }

  Future<void> _initialLoad() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      purchases: [],
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
      final service = ref.read(purchaseServiceProvider);
      if (service == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Service not available',
        );
        return;
      }

      final filter = ref.read(purchaseFilterProvider);
      PurchaseStatus? statusFilter;
      if (filter == PurchaseFilter.draft) statusFilter = PurchaseStatus.draft;
      if (filter == PurchaseFilter.confirmed)
        statusFilter = PurchaseStatus.confirmed;
      if (filter == PurchaseFilter.cancelled)
        statusFilter = PurchaseStatus.cancelled;

      final result = await service.getPurchasesPaginated(
        limit: _limit,
        startAfter: state.lastDoc,
        statusFilter: statusFilter,
      );

      final newPurchases = result['purchases'] as List<PurchaseModel>;
      final hasMore = result['hasMore'] as bool;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;

      state = state.copyWith(
        purchases: [...state.purchases, ...newPurchases],
        isLoading: false,
        hasMore: hasMore,
        lastDoc: lastDoc ?? state.lastDoc,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paginatedPurchasesProvider =
    NotifierProvider<PaginatedPurchasesNotifier, PaginatedPurchasesState>(
      PaginatedPurchasesNotifier.new,
    );

// Controller for CRUD operations
class PurchaseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String> saveDraft(PurchaseModel purchase) async {
    state = const AsyncLoading();
    String purchaseId = '';
    state = await AsyncValue.guard(() async {
      final service = ref.read(purchaseServiceProvider);
      if (service == null) throw Exception('Purchase service not available');
      purchaseId = await service.saveDraft(purchase);
      ref.read(paginatedPurchasesProvider.notifier).refresh();
    });
    return purchaseId;
  }

  Future<void> confirmPurchase(PurchaseModel draftPurchase) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(purchaseServiceProvider);
      if (service == null) throw Exception('Purchase service not available');
      await service.confirmPurchase(draftPurchase);
      ref.read(paginatedPurchasesProvider.notifier).refresh();
    });
  }

  Future<void> cancelPurchase(String purchaseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(purchaseServiceProvider);
      if (service == null) throw Exception('Purchase service not available');
      await service.cancelPurchase(purchaseId);
      ref.read(paginatedPurchasesProvider.notifier).refresh();
    });
  }
}

final purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, void>(PurchaseController.new);

// Today's purchases for dashboard
final todayPurchasesProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (service == null) return 0.0;
  return service.getTodayConfirmedPurchases();
});
