import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/billing/data/billing_service.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';
import 'package:billing_app/features/reports/data/reports_service.dart';

/// Regression tests for the composite-index removal: queries must only use
/// the single-field createdAt index and still return complete results.
Map<String, dynamic> invoiceMap(
  String businessId,
  InvoiceStatus status,
  DateTime createdAt,
  double total,
  int seq,
) {
  return {
    'businessId': businessId,
    'invoiceNumber': 'INV-$seq',
    'issueDate': Timestamp.fromDate(createdAt),
    'items': <dynamic>[],
    'subtotal': total,
    'discountAmount': 0.0,
    'taxableAmount': total,
    'cgstTotal': 0.0,
    'sgstTotal': 0.0,
    'igstTotal': 0.0,
    'grandTotal': total,
    'payment': {
      'status': 'Paid',
      'paidAmount': total,
      'balanceAmount': 0.0,
      'paymentMethod': 'Cash',
    },
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  };
}

void main() {
  const businessId = 'test-biz';
  late FakeFirebaseFirestore firestore;
  late BillingService billingService;
  late ReportsService reportsService;

  final rangeStart = DateTime(2026, 10, 1);
  final rangeEnd = DateTime(2026, 11, 1);

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
    billingService = BillingService(
      businessId: businessId,
      userId: 'u1',
      firestore: firestore,
    );
    reportsService = ReportsService(businessId, firestore: firestore);
  });

  group('getInvoicesPaginated client-side status filter', () {
    test(
      'a raw page full of excluded statuses does not hide later matches',
      () async {
        // 25 newest docs are drafts; 5 older docs are confirmed.
        // A naive single raw page (limit+1 = 21) contains only drafts.
        final docs = <Map<String, dynamic>>[];
        for (var i = 0; i < 25; i++) {
          docs.add(
            invoiceMap(
              businessId,
              InvoiceStatus.draft,
              DateTime(2026, 10, 20, 12, i),
              10,
              i,
            ),
          );
        }
        for (var i = 0; i < 5; i++) {
          docs.add(
            invoiceMap(
              businessId,
              InvoiceStatus.confirmed,
              DateTime(2026, 10, 5, 12, i),
              100,
              100 + i,
            ),
          );
        }
        await seed(docs);

        final result = await billingService.getInvoicesPaginated(
          limit: 20,
          statusFilter: InvoiceStatus.confirmed,
          startDate: rangeStart,
          endDate: rangeEnd,
        );

        final invoices = result['invoices'] as List<InvoiceModel>;
        expect(invoices.length, 5);
        expect(
          invoices.every((i) => i.status == InvoiceStatus.confirmed),
          isTrue,
        );
        expect(result['hasMore'], isFalse);
      },
    );

    test('pagination walks the full range without skipping or duplicating',
        () async {
      final docs = <Map<String, dynamic>>[];
      // 45 confirmed interleaved with 15 drafts, newest first by minute.
      for (var i = 0; i < 60; i++) {
        final status = i % 4 == 0 ? InvoiceStatus.draft : InvoiceStatus.confirmed;
        docs.add(
          invoiceMap(
            businessId,
            status,
            DateTime(2026, 10, 10, 10, i),
            (i + 1).toDouble(),
            i,
          ),
        );
      }
      await seed(docs);

      final seen = <String>{};
      dynamic cursor;
      var hasMore = true;
      var pages = 0;
      while (hasMore) {
        final result = await billingService.getInvoicesPaginated(
          limit: 20,
          startAfter: cursor,
          statusFilter: InvoiceStatus.confirmed,
          startDate: rangeStart,
          endDate: rangeEnd,
        );
        final invoices = result['invoices'] as List<InvoiceModel>;
        for (final inv in invoices) {
          expect(seen.add(inv.invoiceNumber), isTrue,
              reason: 'duplicate ${inv.invoiceNumber}');
        }
        cursor = result['lastDocument'];
        hasMore = result['hasMore'] as bool;
        pages++;
        expect(pages, lessThan(10), reason: 'pagination did not terminate');
      }
      expect(seen.length, 45);
    });

    test('date range bounds results', () async {
      await seed([
        invoiceMap(businessId, InvoiceStatus.confirmed,
            DateTime(2026, 9, 30, 23, 59), 100, 1),
        invoiceMap(businessId, InvoiceStatus.confirmed,
            DateTime(2026, 10, 15), 100, 2),
      ]);

      final result = await billingService.getInvoicesPaginated(
        limit: 20,
        statusFilter: InvoiceStatus.confirmed,
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      final invoices = result['invoices'] as List<InvoiceModel>;
      expect(invoices.length, 1);
      expect(invoices.single.invoiceNumber, 'INV-2');
    });
  });

  group('getSalesSummary client-side aggregation', () {
    test('sums only confirmed invoices inside the range', () async {
      await seed([
        invoiceMap(businessId, InvoiceStatus.confirmed,
            DateTime(2026, 10, 2), 100, 1),
        invoiceMap(businessId, InvoiceStatus.confirmed,
            DateTime(2026, 10, 3), 250, 2),
        invoiceMap(businessId, InvoiceStatus.draft,
            DateTime(2026, 10, 4), 999, 3),
        invoiceMap(businessId, InvoiceStatus.cancelled,
            DateTime(2026, 10, 5), 888, 4),
        // confirmed but outside the selected range
        invoiceMap(businessId, InvoiceStatus.confirmed,
            DateTime(2026, 11, 2), 5000, 5),
      ]);

      final summary = await reportsService.getSalesSummary(
        rangeStart,
        rangeEnd,
      );
      expect(summary.totalSales, 350.0);
      expect(summary.invoiceCount, 2);
    });
  });
}
