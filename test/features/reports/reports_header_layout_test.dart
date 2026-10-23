import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing_app/features/reports/presentation/reports_screen.dart';
import 'package:billing_app/features/reports/providers/reports_provider.dart';

void main() {
  testWidgets('narrow screens place the date button below the report segments',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    // No overflow/clipping errors are thrown by the framework in tests.
    expect(tester.takeException(), isNull);

    final segments = find.byType(SegmentedButton<ReportType>);
    final dateButton = find.byType(OutlinedButton);
    expect(segments, findsOneWidget);
    expect(dateButton, findsOneWidget);

    // Date range button sits on its own row below the segments.
    final segmentsBottom = tester.getBottomLeft(segments).dy;
    final dateTop = tester.getTopLeft(dateButton).dy;
    expect(dateTop, greaterThanOrEqualTo(segmentsBottom));

    // The scroll container and the date button fit inside the 360-wide
    // viewport (the segments themselves scroll horizontally inside it).
    final scroller = find.ancestor(
      of: segments,
      matching: find.byType(SingleChildScrollView),
    );
    expect(tester.getRect(scroller).right, lessThanOrEqualTo(360));
    expect(tester.getRect(dateButton).right, lessThanOrEqualTo(360));

    await expectLater(
      find.byType(ReportsScreen),
      matchesGoldenFile('goldens/reports_header_narrow.png'),
    );
  });
}
