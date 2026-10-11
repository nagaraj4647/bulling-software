import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/reports/models/paginated_result.dart';
import 'package:billing_app/features/reports/providers/reports_pagination_state.dart';
import 'package:billing_app/features/reports/providers/reports_provider.dart';
import 'package:billing_app/features/reports/presentation/widgets/report_pagination_footer.dart';

void main() {
  group('PaginatedReportState Tests', () {
    test('default constructor initializes correctly', () {
      final state = PaginatedReportState<String>();
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.lastDoc, isNull);
      expect(state.error, isNull);
    });

    test(
      'copyWith updates fields correctly and preserves unchanged fields',
      () {
        final state = PaginatedReportState<String>(
          items: ['item1'],
          isLoading: true,
          isLoadingMore: false,
          hasMore: true,
          error: null,
        );

        final updated = state.copyWith(
          items: ['item1', 'item2'],
          isLoading: false,
          isLoadingMore: true,
          hasMore: false,
          error: 'Test error',
        );

        expect(updated.items, ['item1', 'item2']);
        expect(updated.isLoading, isFalse);
        expect(updated.isLoadingMore, isTrue);
        expect(updated.hasMore, isFalse);
        expect(updated.error, 'Test error');
      },
    );

    test('clearError and clearLastDoc work properly in copyWith', () {
      final state = PaginatedReportState<String>(
        items: ['item1'],
        error: 'Some error',
      );

      final cleared = state.copyWith(clearError: true, clearLastDoc: true);
      expect(cleared.error, isNull);
      expect(cleared.lastDoc, isNull);
    });
  });

  group('PaginatedResult Model Tests', () {
    test(
      'PaginatedResult stores items, lastDocument, and hasMore correctly',
      () {
        const result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          lastDocument: null,
          hasMore: false,
        );

        expect(result.items.length, 3);
        expect(result.lastDocument, isNull);
        expect(result.hasMore, isFalse);
      },
    );
  });

  group('Page Size Enforcement', () {
    test('all detailed report notifiers enforce pageSize = 20', () {
      expect(ReportSalesNotifier.pageSize, 20);
      expect(ReportPurchasesNotifier.pageSize, 20);
      expect(ReportExpensesNotifier.pageSize, 20);
      expect(ReportProductsNotifier.pageSize, 20);
      expect(ReportCustomersNotifier.pageSize, 20);
      expect(ReportSuppliersNotifier.pageSize, 20);
    });
  });

  group('ReportPaginationFooter Widget Tests', () {
    testWidgets(
      'shows Load More button when hasMore=true and isLoadingMore=false',
      (tester) async {
        bool loadMoreClicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReportPaginationFooter(
                hasMore: true,
                isLoadingMore: false,
                totalLoaded: 20,
                onLoadMore: () {
                  loadMoreClicked = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('Load More (20 records)'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('Load More (20 records)'));
        await tester.pump();

        expect(loadMoreClicked, isTrue);
      },
    );

    testWidgets(
      'shows CircularProgressIndicator when hasMore=true and isLoadingMore=true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReportPaginationFooter(
                hasMore: true,
                isLoadingMore: true,
                totalLoaded: 20,
                onLoadMore: () {},
              ),
            ),
          ),
        );

        expect(find.text('Load More (20 records)'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'shows total record count when hasMore=false and totalLoaded > 0',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReportPaginationFooter(
                hasMore: false,
                isLoadingMore: false,
                totalLoaded: 42,
                onLoadMore: () {},
              ),
            ),
          ),
        );

        expect(find.text('Showing all 42 records'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('shows nothing when hasMore=false and totalLoaded == 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportPaginationFooter(
              hasMore: false,
              isLoadingMore: false,
              totalLoaded: 0,
              onLoadMore: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Showing all'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('Date Range State Tests', () {
    test('DateRangeState initializes with start and end dates', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 2, 1);
      final range = DateRangeState(start, end);

      expect(range.start, start);
      expect(range.end, end);
    });
  });
}
