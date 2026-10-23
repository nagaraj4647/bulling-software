// Interaction checks for the billing counter UI overhaul:
// add/remove/quantity, payment recalculation, and the mobile
// "View Cart & Pay" sheet with reachable payment fields.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/auth/providers/auth_provider.dart';
import 'package:billing_app/features/billing/presentation/new_invoice_screen.dart';
import 'package:billing_app/features/billing/providers/billing_provider.dart';
import 'package:billing_app/features/billing/providers/cart_provider.dart';
import 'package:billing_app/features/business/models/business_model.dart';
import 'package:billing_app/features/business/providers/business_provider.dart';
import 'package:billing_app/features/customers/models/customer_model.dart';
import 'package:billing_app/features/customers/providers/customer_provider.dart';
import 'package:billing_app/features/products/models/product_model.dart';
import 'package:billing_app/features/products/providers/product_provider.dart';

final _business = BusinessModel(
  businessId: 'biz1',
  ownerId: 'u1',
  businessName: 'Mani Stores',
  businessType: 'Retail',
  ownerName: 'Nagarajan M',
  phone: '9876543210',
  email: 'mani@example.com',
  address: '12 Bazaar Street, Madurai',
  businessState: 'Tamil Nadu',
);

final _products = <ProductModel>[
  ProductModel(
    productId: 'p1',
    businessId: 'biz1',
    name: 'Parle-G Gold Biscuits 100g',
    category: 'Snacks',
    unit: 'pcs',
    purchasePrice: 8,
    sellingPrice: 10,
    stockQuantity: 144,
    lowStockThreshold: 24,
    gstRate: 5,
  ),
  ProductModel(
    productId: 'p5',
    businessId: 'biz1',
    name: 'Fortune Sunflower Oil 1L',
    category: 'Staples',
    unit: 'btl',
    purchasePrice: 120,
    sellingPrice: 138,
    stockQuantity: 30,
    lowStockThreshold: 8,
    gstRate: 5,
  ),
];

Widget _app() {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      currentBusinessProvider.overrideWith((ref) async => _business),
      productsProvider.overrideWith((ref) => Stream.value(_products)),
      customersProvider.overrideWith((ref) => Stream.value(const [])),
      billingServiceProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const NewInvoiceScreen()),
  );
}

void main() {
  testWidgets('desktop: add, quantity steppers, remove, payment recalc', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    final element = tester.element(find.byType(NewInvoiceScreen));
    final container = ProviderScope.containerOf(element);
    container
        .read(cartProvider.notifier)
        .setCustomer(
          CustomerModel(
            customerId: 'c1',
            businessId: 'biz1',
            name: 'Kumar Textiles',
            state: 'Tamil Nadu',
          ),
        );
    await tester.pump();

    // Add product p1 (₹10) by tapping its card.
    await tester.tap(find.text('Parle-G Gold Biscuits 100g'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).items.length, 1);
    expect(container.read(cartTotalsProvider)!.grandTotal, closeTo(10.5, 0.01));

    // Tap the same card again -> quantity 2 via addItem.
    await tester.tap(find.text('Parle-G Gold Biscuits 100g').first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).items.single.quantity, 2);
    expect(container.read(cartTotalsProvider)!.grandTotal, closeTo(21.0, 0.01));

    // Minus stepper in the cart row brings it back to 1.
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).items.single.quantity, 1);

    // Remove the line entirely via the close button.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).items, isEmpty);

    // Re-add p5 (₹138, GST 5%) and pay partially -> balance recalculates.
    await tester.tap(find.text('Fortune Sunflower Oil 1L'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      container.read(cartTotalsProvider)!.grandTotal,
      closeTo(144.9, 0.01),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Amount Paid (₹)'),
      '100',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).paidAmount, 100);
    expect(
      container.read(cartTotalsProvider)!.payment.balanceAmount,
      closeTo(44.9, 0.01),
    );

    // UPI chip switches the payment method.
    await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).paymentMethod, 'UPI');

    // Exact button fills the full amount -> balance zero.
    await tester.tap(find.widgetWithText(TextButton, 'Exact'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      container.read(cartTotalsProvider)!.payment.balanceAmount,
      closeTo(0, 0.01),
    );
  });

  testWidgets('mobile: View Cart & Pay sheet opens with payment fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    final el = tester.element(find.byType(NewInvoiceScreen));
    ProviderScope.containerOf(el)
        .read(cartProvider.notifier)
        .setCustomer(
          CustomerModel(
            customerId: 'c1',
            businessId: 'biz1',
            name: 'Kumar Textiles',
            state: 'Tamil Nadu',
          ),
        );
    await tester.pump();

    // Add one product so the bottom bar appears.
    await tester.tap(find.text('Parle-G Gold Biscuits 100g'));
    await tester.pumpAndSettle();

    // Open the cart sheet.
    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Cart Details'), findsOneWidget);

    // Pinned checkout button is visible without scrolling.
    expect(find.textContaining('Complete Checkout'), findsOneWidget);

    // Quantity steppers work inside the sheet too (the cart item sits at
    // the top of the sheet, so its stepper is tappable right away).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NewInvoiceScreen)),
    );
    final sheetAdd = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byIcon(Icons.add),
    );
    expect(sheetAdd, findsOneWidget);
    await tester.tap(sheetAdd);
    await tester.pump(const Duration(milliseconds: 700));
    expect(container.read(cartProvider).items.single.quantity, 2);

    // Scroll the sheet to reveal the payment field and chips, proving they
    // are reachable on a phone-size viewport.
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Amount Paid (₹)'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(TextField, 'Amount Paid (₹)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cash'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'UPI'), findsOneWidget);

    // Payment recalculation works inside the sheet too.
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount Paid (₹)'),
      '10',
    );
    await tester.pump(const Duration(milliseconds: 700));
    final el2 = tester.element(find.byType(NewInvoiceScreen));
    expect(ProviderScope.containerOf(el2).read(cartProvider).paidAmount, 10);
  });
}
