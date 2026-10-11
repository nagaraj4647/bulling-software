import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard Flow Navigation Test', (WidgetTester tester) async {
    // 1. Launch the app
    await tester.pumpWidget(createTestApp());

    // Step 1: Wait for the initial Future.delayed(200ms) in SplashScreen
    await Future.delayed(const Duration(milliseconds: 300));
    // Pump the logo animation (800ms duration)
    await tester.pumpAndSettle();

    // Step 2: Wait for the Future.delayed(600ms) hold time in SplashScreen
    await Future.delayed(const Duration(milliseconds: 700));
    // Pump the fade out animation and the resulting GoRouter navigation
    await tester.pumpAndSettle();

    // The app should navigate to dashboard directly because we are mocked as logged in
    // and we have a mock business.

    // Verify we are on Home/Dashboard
    // Verify we are on Home/Dashboard
    expect(find.text('Home').last, findsOneWidget);
    expect(find.text('Test Business'), findsWidgets); // AppBar title

    // Open Billing
    await tester.tap(find.text('Billing').last);
    await tester.pumpAndSettle();

    // Open Products
    await tester.tap(find.text('Products').last);
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsWidgets);

    // Open Reports
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsWidgets);

    // Open More
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    // Verify More menu items
    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('Customers'), findsWidgets);
    expect(find.text('Suppliers'), findsWidgets);
    expect(find.text('Purchases'), findsWidgets);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Open a destination from More menu (e.g., Settings)
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
  });
}
