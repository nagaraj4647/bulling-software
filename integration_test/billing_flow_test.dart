import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Ignore Google Fonts network errors on the emulator
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

  testWidgets('Billing Flow Integration Test', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());

    // 1. Splash screen delays
    await Future.delayed(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // 2. We should be on Home Dashboard
    expect(find.text('Home').last, findsOneWidget);

    // 3. Open Billing
    await tester.tap(find.text('Billing').last);
    await tester.pumpAndSettle();

    // 4. Verify we are on Billing screen
    expect(find.text('Billing & Invoices'), findsOneWidget);

    // 5. Create new Invoice
    await tester.tap(find.widgetWithText(FilledButton, 'Create Invoice'));
    await tester.pumpAndSettle();

    // Verify New Invoice screen loaded
    expect(find.text('New Invoice'), findsWidgets);

    // 6. Select Customer
    // The Select Customer ListTile doesn't have an onTap, we must tap the search icon
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Customer'));
    await tester.pumpAndSettle();

    // 7. Add Product
    await tester.tap(find.widgetWithText(FilledButton, 'Add Item'));
    await tester.pumpAndSettle();

    // Tap the cart icon to add Test Product A
    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pumpAndSettle();

    // Close Product Picker
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Verify product was added
    expect(find.text('Test Product A'), findsOneWidget);

    // 8. Increase Quantity
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    // Verify subtotal (2 qty * 100 selling price = 200)
    // Actually selling price is 100 for testProductA in mock Providers.
    expect(
      find.text('₹200.00').last,
      findsWidgets,
    ); // Subtotal might be listed multiple times

    // 9. Payment method
    // Default is Cash, balance due should be 200 because Amount Paid is 0.
    // Tap Full Payment button
    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pumpAndSettle();

    // Balance Due should be 0
    expect(find.text('₹0.00').last, findsWidgets);

    // 10. Confirm Invoice
    await tester.tap(find.text('Confirm Invoice'));
    // Give some time for the mock Future.delayed(100ms)
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify success snackbar
    expect(find.text('Invoice confirmed successfully!'), findsOneWidget);

    // Should navigate back to Billing screen
    expect(find.text('Billing & Invoices'), findsOneWidget);

    // Verify the newly created invoice is in the list
    expect(find.text('INV-000001'), findsOneWidget);
    expect(find.text('Confirmed'), findsWidgets);
  });
}
