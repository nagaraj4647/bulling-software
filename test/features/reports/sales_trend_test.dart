import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';
import 'package:billing_app/features/reports/data/reports_service.dart';

import 'no_composite_index_queries_test.dart' show invoiceMap;

/// Tests for the real-data sales trend used by the Reports and Dashboard
/// charts (previously hardcoded mocked spots).
void main() {
  const businessId = 'test-biz';
  late FakeFirebaseFirestore firestore;
  late ReportsService reportsService;

  Future<void> seed(List<Map<String, dynamic>> docs) async {
    for (final doc in docs) {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('invoices')
          .add(doc);
    }
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    reportsService = ReportsService(businessId, firestore: firestore);
  });

  group('bucketDailyTotals', () {
    test('buckets per calendar day and zero-fills gaps', () {
      final points = ReportsService.bucketDailyTotals(
        [
          (at: DateTime(2026, 10, 1, 9), total: 100.0),
          (at: DateTime(2026, 10, 1, 18), total: 50.0),
          (at: DateTime(2026, 10, 3, 12), total: 70.0),
        ],
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 4),
      );
      expect(points.length, 3);
      expect(points[0].total, 150.0);
      expect(points[1].total, 0.0);
      expect(points[2].total, 70.0);
      expect(points[0].day, DateTime(2026, 10, 1));
      expect(points[2].day, DateTime(2026, 10, 3));
    });

    test('excludes entries outside [start, end)', () {
      final points = ReportsService.bucketDailyTotals(
        [
          (at: DateTime(2026, 9, 30, 23), total: 10.0),
          (at: DateTime(2026, 10, 2), total: 20.0),
          (at: DateTime(2026, 10, 3), total: 30.0),
        ],
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 3),
      );
      expect(points.length, 2);
      expect(points.map((p) => p.total).toList(), [0.0, 20.0]);
    });

    test('rounds a non-midnight end up to cover its day', () {
      final points = ReportsService.bucketDailyTotals(
        [(at: DateTime(2026, 10, 2, 10), total: 5.0)],
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2, 15, 30),
      );
      expect(points.length, 2);
      expect(points[1].total, 5.0);
    });

    test('empty or inverted range yields no points', () {
      expect(
        ReportsService.bucketDailyTotals(
          [(at: DateTime(2026, 10, 1), total: 5.0)],
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 1),
        ),
        isEmpty,
      );
      expect(
        ReportsService.bucketDailyTotals(
          const [],
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 1),
        ),
        isEmpty,
      );
    });
  });

  group('getDailySalesTrend', () {
    final start = DateTime(2026, 10, 17);
    final end = DateTime(2026, 10, 24);

    test('confirmed only, per-day totals, zero-filled', () async {
      await seed([
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 18, 10), 120.0, 1),
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 18, 15), 30.0, 2),
        invoiceMap(businessId, InvoiceStatus.draft, DateTime(2026, 10, 18, 16), 999.0, 3),
        invoiceMap(businessId, InvoiceStatus.cancelled, DateTime(2026, 10, 20, 9), 500.0, 4),
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 22, 12), 245.0, 5),
      ]);
      final points = await reportsService.getDailySalesTrend(start, end);
      expect(points.length, 7);
      expect(points[0].day, start);
      expect(points[1].total, 150.0); // Oct 18, drafts excluded
      expect(points[2].total, 0.0); // Oct 19 zero-filled
      expect(points[3].total, 0.0); // Oct 20 cancelled excluded
      expect(points[5].total, 245.0); // Oct 22
      expect(points[6].day, DateTime(2026, 10, 23));
    });

    test('no invoices returns zero-filled days, not an error', () async {
      final points = await reportsService.getDailySalesTrend(start, end);
      expect(points.length, 7);
      expect(points.every((p) => p.total == 0.0), isTrue);
    });
  });

  group('getSalesSummary dailyTotals', () {
    test('summary carries the same buckets as the trend query', () async {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 11, 1);
      await seed([
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 5, 11), 200.0, 1),
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 5, 12), 45.0, 2),
        invoiceMap(businessId, InvoiceStatus.draft, DateTime(2026, 10, 6, 9), 1000.0, 3),
        invoiceMap(businessId, InvoiceStatus.confirmed, DateTime(2026, 10, 31, 23, 59), 1170.0, 4),
      ]);
      final summary = await reportsService.getSalesSummary(start, end);
      expect(summary.invoiceCount, 3);
      expect(summary.totalSales, 1415.0);
      expect(summary.dailyTotals.length, 31);
      expect(summary.dailyTotals[4].total, 245.0); // Oct 5
      expect(summary.dailyTotals[30].total, 1170.0); // Oct 31
      final bucketSum = summary.dailyTotals.fold<double>(
        0,
        (s, p) => s + p.total,
      );
      expect(bucketSum, summary.totalSales);
    });

    test('boundary: invoice at range end excluded, at start included', () async {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 8);
      await seed([
        invoiceMap(businessId, InvoiceStatus.confirmed, start, 10.0, 1),
        invoiceMap(businessId, InvoiceStatus.confirmed, end, 20.0, 2),
      ]);
      final summary = await reportsService.getSalesSummary(start, end);
      expect(summary.invoiceCount, 1);
      expect(summary.dailyTotals.length, 7);
      expect(summary.dailyTotals.first.total, 10.0);
    });
  });
}
