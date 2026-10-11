import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../models/expense_model.dart';
import '../data/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;
  return ExpenseService(businessId: business.businessId!);
});

// Filters
class ExpenseFilterState {
  final ExpenseStatus? status;
  final ExpenseCategory? category;
  final DateTime? startDate;
  final DateTime? endDate;

  ExpenseFilterState({
    this.status,
    this.category,
    this.startDate,
    this.endDate,
  });

  ExpenseFilterState copyWith({
    ExpenseStatus? status,
    ExpenseCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearDates = false,
  }) {
    return ExpenseFilterState(
      status: clearStatus ? null : (status ?? this.status),
      category: clearCategory ? null : (category ?? this.category),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }
}

class ExpenseFilterNotifier extends Notifier<ExpenseFilterState> {
  @override
  ExpenseFilterState build() => ExpenseFilterState();

  void setStatus(ExpenseStatus? status) {
    state = state.copyWith(status: status, clearStatus: status == null);
    ref.read(paginatedExpensesProvider.notifier).refresh();
  }

  void setCategory(ExpenseCategory? category) {
    state = state.copyWith(category: category, clearCategory: category == null);
    ref.read(paginatedExpensesProvider.notifier).refresh();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      clearDates: start == null && end == null,
    );
    ref.read(paginatedExpensesProvider.notifier).refresh();
  }
}

final expenseFilterProvider =
    NotifierProvider<ExpenseFilterNotifier, ExpenseFilterState>(
      ExpenseFilterNotifier.new,
    );

// Paginated State
class PaginatedExpensesState {
  final List<ExpenseModel> expenses;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final String? error;

  PaginatedExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  PaginatedExpensesState copyWith({
    List<ExpenseModel>? expenses,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    String? error,
    bool clearLastDoc = false,
  }) {
    return PaginatedExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
      error: error, // overwrite error explicitly
    );
  }
}

class PaginatedExpensesNotifier extends Notifier<PaginatedExpensesState> {
  static const int _limit = 20;

  @override
  PaginatedExpensesState build() {
    Future.microtask(() => _initialLoad());
    return PaginatedExpensesState(isLoading: true);
  }

  Future<void> _initialLoad() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      expenses: [],
      clearLastDoc: true,
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
      final service = ref.read(expenseServiceProvider);
      if (service == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Service not available',
        );
        return;
      }

      final filters = ref.read(expenseFilterProvider);

      final result = await service.getExpensesPaginated(
        limit: _limit,
        startAfter: state.lastDoc,
        statusFilter: filters.status,
        categoryFilter: filters.category,
        startDate: filters.startDate,
        endDate: filters.endDate,
      );

      final newExpenses = result['expenses'] as List<ExpenseModel>;

      state = state.copyWith(
        expenses: [...state.expenses, ...newExpenses],
        isLoading: false,
        hasMore: result['hasMore'] as bool,
        lastDoc: result['lastDocument'] as DocumentSnapshot?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paginatedExpensesProvider =
    NotifierProvider<PaginatedExpensesNotifier, PaginatedExpensesState>(
      PaginatedExpensesNotifier.new,
    );

// Controller
class ExpenseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String> saveDraft(ExpenseModel expense) async {
    state = const AsyncLoading();
    String id = '';
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      if (service == null) throw Exception('Expense service not available');
      id = await service.saveDraftExpense(expense);
      ref.read(paginatedExpensesProvider.notifier).refresh();
    });
    return id;
  }

  Future<void> updateDraft(ExpenseModel expense) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      if (service == null) throw Exception('Expense service not available');
      await service.updateDraftExpense(expense);
      ref.read(paginatedExpensesProvider.notifier).refresh();
    });
  }

  Future<void> confirmExpense(String expenseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      if (service == null) throw Exception('Expense service not available');
      await service.confirmExpense(expenseId);
      ref.read(paginatedExpensesProvider.notifier).refresh();
      ref.invalidate(todayExpensesProvider);
    });
  }

  Future<void> cancelExpense(String expenseId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      if (service == null) throw Exception('Expense service not available');
      await service.cancelExpense(expenseId);
      ref.read(paginatedExpensesProvider.notifier).refresh();
      ref.invalidate(todayExpensesProvider);
    });
  }
}

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, void>(ExpenseController.new);

// Today's Expenses Provider
final todayExpensesProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(expenseServiceProvider);
  if (service == null) return 0.0;
  return service.getTodayConfirmedExpenses();
});
