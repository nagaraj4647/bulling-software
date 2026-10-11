import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_provider.dart';
import '../data/billing_service.dart';
import '../models/invoice_model.dart';

final billingServiceProvider = Provider<BillingService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  final user = ref.watch(authStateProvider).value;

  if (business == null || business.businessId == null || user == null) {
    return null;
  }

  return BillingService(businessId: business.businessId!, userId: user.uid);
});

class PaginatedInvoicesState {
  final List<InvoiceModel> invoices;
  final bool isLoading;
  final bool hasMore;
  final dynamic lastDocument;
  final String? error;

  PaginatedInvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  PaginatedInvoicesState copyWith({
    List<InvoiceModel>? invoices,
    bool? isLoading,
    bool? hasMore,
    dynamic lastDocument,
    String? error,
  }) {
    return PaginatedInvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      error: error ?? this.error,
    );
  }
}

class PaginatedInvoicesNotifier extends Notifier<PaginatedInvoicesState> {
  @override
  PaginatedInvoicesState build() {
    // Start initial load without awaiting here to not block UI immediately
    Future.microtask(() => loadInitial());
    return PaginatedInvoicesState();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = ref.read(billingServiceProvider);
      if (service == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final filterState = ref.read(invoiceFilterProvider);
      InvoiceStatus? statusFilter;
      if (filterState == InvoiceFilter.confirmed)
        statusFilter = InvoiceStatus.confirmed;
      if (filterState == InvoiceFilter.draft)
        statusFilter = InvoiceStatus.draft;
      if (filterState == InvoiceFilter.cancelled)
        statusFilter = InvoiceStatus.cancelled;

      final result = await service.getInvoicesPaginated(
        limit: 20,
        statusFilter: statusFilter,
      );
      state = state.copyWith(
        invoices: result['invoices'] as List<InvoiceModel>,
        lastDocument: result['lastDocument'],
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = ref.read(billingServiceProvider);
      if (service == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final filterState = ref.read(invoiceFilterProvider);
      InvoiceStatus? statusFilter;
      if (filterState == InvoiceFilter.confirmed)
        statusFilter = InvoiceStatus.confirmed;
      if (filterState == InvoiceFilter.draft)
        statusFilter = InvoiceStatus.draft;
      if (filterState == InvoiceFilter.cancelled)
        statusFilter = InvoiceStatus.cancelled;

      final result = await service.getInvoicesPaginated(
        limit: 20,
        startAfter: state.lastDocument,
        statusFilter: statusFilter,
      );

      state = state.copyWith(
        invoices: [
          ...state.invoices,
          ...(result['invoices'] as List<InvoiceModel>),
        ],
        lastDocument: result['lastDocument'],
        hasMore: result['hasMore'] as bool,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paginatedInvoicesProvider =
    NotifierProvider<PaginatedInvoicesNotifier, PaginatedInvoicesState>(
      PaginatedInvoicesNotifier.new,
    );

enum InvoiceFilter { all, confirmed, draft, cancelled }

class InvoiceFilterNotifier extends Notifier<InvoiceFilter> {
  @override
  InvoiceFilter build() => InvoiceFilter.all;

  void setFilter(InvoiceFilter filter) {
    state = filter;
    // Trigger a reload when filter changes
    ref.read(paginatedInvoicesProvider.notifier).loadInitial();
  }
}

final invoiceFilterProvider =
    NotifierProvider<InvoiceFilterNotifier, InvoiceFilter>(
      InvoiceFilterNotifier.new,
    );

class BillingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> saveDraft(InvoiceModel invoice) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(billingServiceProvider);
      if (service == null) throw Exception('Billing service not available');
      await service.saveDraft(invoice);
      ref.read(paginatedInvoicesProvider.notifier).loadInitial();
    });
  }

  Future<void> confirmInvoice(InvoiceModel invoice) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(billingServiceProvider);
      if (service == null) throw Exception('Billing service not available');
      await service.confirmInvoice(invoice);
      ref.read(paginatedInvoicesProvider.notifier).loadInitial();
      ref.invalidate(todaySalesProvider);
    });
  }

  Future<void> cancelInvoice(String invoiceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(billingServiceProvider);
      if (service == null) throw Exception('Billing service not available');
      await service.cancelInvoice(invoiceId);
      ref.read(paginatedInvoicesProvider.notifier).loadInitial();
      ref.invalidate(todaySalesProvider);
    });
  }
}

final billingControllerProvider =
    AsyncNotifierProvider<BillingController, void>(BillingController.new);

final todaySalesProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(billingServiceProvider);
  if (service == null) return 0.0;
  return service.getTodayConfirmedSales();
});

final recentInvoicesProvider = StreamProvider<List<InvoiceModel>>((ref) {
  final service = ref.watch(billingServiceProvider);
  if (service == null) return const Stream.empty();
  return service.getRecentInvoicesStream();
});
