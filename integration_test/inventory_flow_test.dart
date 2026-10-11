import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('google_fonts') ||
          details.exception.toString().contains('fonts.gstatic.com')) {
        return;
      }
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error.toString().contains('google_fonts') ||
          error.toString().contains('fonts.gstatic.com')) {
        return true;
      }
      return false;
    };
  });

  testWidgets('Inventory Flow Integration Test', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());

    // Wait for Splash
    await Future.delayed(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify Home
    expect(find.text('Home').last, findsOneWidget);

    // A. Open Inventory from More
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();

    // B. Verify Inventory screen loads
    expect(find.text('Total Products'), findsOneWidget);

    // C. Verify product information is displayed
    // testProductA has 10 stock in the mock.
    expect(find.text('Test Product A'), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);

    // D. Open the available stock adjustment/action UI
    // Tap the edit icon for Test Product A
    await tester.tap(find.byIcon(Icons.edit_note).first);
    await tester.pumpAndSettle();

    expect(find.text('Adjust Stock: Test Product A'), findsOneWidget);

    // E. Increase stock and verify quantity changes
    // Enter quantity 5 for Stock In (+)
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.enterText(find.byType(TextField).last, 'New stock arrived');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 200)); // wait for mock
    await tester.pumpAndSettle();

    expect(find.text('Stock adjusted successfully'), findsOneWidget);
    // New stock should be 10 + 5 = 15
    expect(find.text('15.0'), findsOneWidget);

    // F. Decrease stock
    await tester.tap(find.byIcon(Icons.edit_note).first);
    await tester.pumpAndSettle();

    // Change type to OUT
    await tester.tap(find.text('Stock In (+)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock Out (-)').last);
    await tester.pumpAndSettle();

    // Enter quantity 2
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.enterText(find.byType(TextField).last, 'Damaged');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // New stock should be 15 - 2 = 13
    expect(find.text('13.0'), findsOneWidget);

    // G. Attempt invalid/negative-stock operation
    await tester.tap(find.byIcon(Icons.edit_note).first);
    await tester.pumpAndSettle();

    // Change type to OUT
    await tester.tap(find.text('Stock In (+)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock Out (-)').last);
    await tester.pumpAndSettle();

    // Try to stock out 1000
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Cannot stock out more than current stock'),
      findsOneWidget,
    );

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // H. Verify inventory transaction/history information
    // Tap the product list tile
    await tester.tap(find.text('Test Product A'));
    await tester.pumpAndSettle();

    // Verify history sheet opens
    expect(find.text('History: Test Product A'), findsOneWidget);
    // Verify the reason 'Damaged' we entered in OUT is present
    expect(find.text('Damaged'), findsOneWidget);
    // Verify the quantity was -2
    expect(find.text('-2.0'), findsOneWidget);
  });
}
