import 'package:cloud_firestore/cloud_firestore.dart';

class PaginatedReportState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final String? error;

  const PaginatedReportState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  PaginatedReportState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    String? error,
    bool clearError = false,
    bool clearLastDoc = false,
  }) {
    return PaginatedReportState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
