// Preview harness for UI screenshots. NOT for production.
// Run: flutter build web -t lib/main_preview.dart
// Screens: ?screen=counter | ?screen=invoices | ?screen=details
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/auth/providers/auth_provider.dart';
import 'package:billing_app/features/billing/presentation/new_invoice_screen.dart';
import 'package:billing_app/features/billing/presentation/billing_screen.dart';
import 'package:billing_app/features/billing/presentation/invoice_details_screen.dart';
import 'package:billing_app/features/billing/providers/billing_provider.dart';
import 'package:billing_app/features/billing/providers/cart_provider.dart';
import 'package:billing_app/features/billing/models/invoice_model.dart';
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
  gstNumber: '33ABCDE1234F1Z5',
  upiId: 'manistores@upi',
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
    productId: 'p2',
    businessId: 'biz1',
    name: 'Aavin Milk 500ml',
    category: 'Dairy',
    unit: 'pkt',
    purchasePrice: 24,
    sellingPrice: 28,
    stockQuantity: 40,
    lowStockThreshold: 12,
    gstRate: 0,
  ),
  ProductModel(
    productId: 'p3',
    businessId: 'biz1',
    name: 'Sunrise Coffee Powder 200g',
    category: 'Beverages',
    unit: 'pcs',
    purchasePrice: 95,
    sellingPrice: 115,
    stockQuantity: 22,
    lowStockThreshold: 6,
    gstRate: 5,
  ),
  ProductModel(
    productId: 'p4',
    businessId: 'biz1',
    name: 'Aashirvaad Atta 5kg',
    category: 'Staples',
    unit: 'bag',
    purchasePrice: 210,
    sellingPrice: 245,
    stockQuantity: 15,
    lowStockThreshold: 4,
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
  ProductModel(
    productId: 'p6',
    businessId: 'biz1',
    name: 'Colgate MaxFresh 150g',
    category: 'Personal Care',
    unit: 'pcs',
    purchasePrice: 78,
    sellingPrice: 95,
    stockQuantity: 25,
    lowStockThreshold: 6,
    gstRate: 18,
  ),
  ProductModel(
    productId: 'p7',
    businessId: 'biz1',
    name: 'Tata Salt 1kg',
    category: 'Staples',
    unit: 'pkt',
    purchasePrice: 24,
    sellingPrice: 28,
    stockQuantity: 60,
    lowStockThreshold: 15,
    gstRate: 5,
  ),
  ProductModel(
    productId: 'p8',
    businessId: 'biz1',
    name: 'Maggi Noodles 70g',
    category: 'Snacks',
    unit: 'pcs',
    purchasePrice: 12,
    sellingPrice: 14,
    stockQuantity: 96,
    lowStockThreshold: 24,
    gstRate: 5,
  ),
  ProductModel(
    productId: 'p9',
    businessId: 'biz1',
    name: 'Surf Excel Easy Wash 1kg',
    category: 'Home Care',
    unit: 'pkt',
    purchasePrice: 110,
    sellingPrice: 132,
    stockQuantity: 18,
    lowStockThreshold: 5,
    gstRate: 18,
  ),
  ProductModel(
    productId: 'p10',
    businessId: 'biz1',
    name: 'Britannia Marie Gold 250g',
    category: 'Snacks',
    unit: 'pcs',
    purchasePrice: 30,
    sellingPrice: 35,
    stockQuantity: 48,
    lowStockThreshold: 12,
    gstRate: 5,
  ),
  ProductModel(
    productId: 'p11',
    businessId: 'biz1',
    name: 'Amul Butter 100g',
    category: 'Dairy',
    unit: 'pcs',
    purchasePrice: 52,
    sellingPrice: 60,
    stockQuantity: 20,
    lowStockThreshold: 6,
    gstRate: 12,
  ),
  ProductModel(
    productId: 'p12',
    businessId: 'biz1',
    name: 'India Gate Basmati Rice 1kg',
    category: 'Staples',
    unit: 'pkt',
    purchasePrice: 118,
    sellingPrice: 145,
    stockQuantity: 26,
    lowStockThreshold: 8,
    gstRate: 5,
  ),
];

final _customers = <CustomerModel>[
  CustomerModel(
    customerId: 'c1',
    businessId: 'biz1',
    name: 'Kumar Textiles',
    phone: '9840012345',
    city: 'Madurai',
    state: 'Tamil Nadu',
  ),
  CustomerModel(
    customerId: 'c2',
    businessId: 'biz1',
    name: 'Selvi Traders',
    phone: '9840067890',
    city: 'Madurai',
    state: 'Tamil Nadu',
  ),
];

InvoiceItemModel _item(
  String pid,
  String name,
  double qty,
  double price,
  double gstRate,
) {
  final taxable = qty * price;
  final half = taxable * gstRate / 200;
  final gst = taxable * gstRate / 100;
  return InvoiceItemModel(
    productId: pid,
    productNameSnapshot: name,
    quantity: qty,
    unitPrice: price,
    discount: 0,
    taxableValue: taxable,
    gstRate: gstRate,
    cgstAmount: half,
    sgstAmount: half,
    igstAmount: 0,
    totalAmount: taxable + gst,
  );
}

InvoiceModel _invoice(
  String id,
  String number,
  String customer,
  List<InvoiceItemModel> items,
  double paid,
  String method,
  InvoiceStatus status,
  int daysAgo,
) {
  final taxable = items.fold<double>(0, (s, i) => s + i.taxableValue);
  final cgst = items.fold<double>(0, (s, i) => s + i.cgstAmount);
  final sgst = items.fold<double>(0, (s, i) => s + i.sgstAmount);
  final total = items.fold<double>(0, (s, i) => s + i.totalAmount);
  return InvoiceModel(
    invoiceId: id,
    businessId: 'biz1',
    invoiceNumber: number,
    issueDate: DateTime.now().subtract(Duration(days: daysAgo)),
    customerSnapshot: CustomerSnapshot(
      customerId: 'c1',
      name: customer,
      phone: '9840012345',
      city: 'Madurai',
      state: 'Tamil Nadu',
    ),
    items: items,
    subtotal: taxable,
    discountAmount: 0,
    taxableAmount: taxable,
    cgstTotal: cgst,
    sgstTotal: sgst,
    igstTotal: 0,
    grandTotal: total,
    payment: InvoicePayment(
      status: paid >= total ? 'Paid' : (paid > 0 ? 'Partially Paid' : 'Unpaid'),
      paidAmount: paid,
      balanceAmount: total - paid,
      paymentMethod: method,
    ),
    status: status,
  );
}

final _invoices = <InvoiceModel>[
  _invoice(
    'inv1',
    'INV-1042',
    'Kumar Textiles',
    [
      _item('p4', 'Aashirvaad Atta 5kg', 2, 233.33, 5),
      _item('p5', 'Fortune Sunflower Oil 1L', 1, 131.43, 5),
      _item('p1', 'Parle-G Gold Biscuits 100g', 2, 9.52, 5),
    ],
    647.99,
    'UPI',
    InvoiceStatus.confirmed,
    0,
  ),
  _invoice(
    'inv2',
    'INV-1041',
    'Selvi Traders',
    [
      _item('p4', 'Aashirvaad Atta 5kg', 2, 233.33, 5),
      _item('p5', 'Fortune Sunflower Oil 1L', 1, 131.43, 5),
      _item('p12', 'India Gate Basmati Rice 1kg', 4, 138.10, 5),
      _item('p8', 'Maggi Noodles 70g', 3, 13.33, 5),
    ],
    500.00,
    'Cash',
    InvoiceStatus.confirmed,
    1,
  ),
  _invoice(
    'inv3',
    'INV-1040',
    'Walk-in Customer',
    [
      _item('p7', 'Tata Salt 1kg', 2, 26.67, 5),
      _item('p6', 'Colgate MaxFresh 150g', 1, 80.51, 18),
    ],
    151.01,
    'Cash',
    InvoiceStatus.confirmed,
    1,
  ),
  _invoice(
    'inv4',
    'INV-1039',
    'Kumar Textiles',
    [
      _item('p3', 'Sunrise Coffee Powder 200g', 4, 109.52, 5),
      _item('p9', 'Surf Excel Easy Wash 1kg', 6, 111.86, 18),
      _item('p11', 'Amul Butter 100g', 5, 53.57, 12),
    ],
    0,
    'None',
    InvoiceStatus.draft,
    2,
  ),
  _invoice(
    'inv5',
    'INV-1038',
    'Selvi Traders',
    [
      _item('p4', 'Aashirvaad Atta 5kg', 1, 233.33, 5),
      _item('p5', 'Fortune Sunflower Oil 1L', 2, 131.43, 5),
      _item('p2', 'Aavin Milk 500ml', 5, 28.00, 0),
    ],
    661.00,
    'UPI',
    InvoiceStatus.confirmed,
    3,
  ),
];

class _PreviewInvoicesNotifier extends PaginatedInvoicesNotifier {
  @override
  PaginatedInvoicesState build() =>
      PaginatedInvoicesState(invoices: _invoices, hasMore: false);
}

void main() {
  final screen = Uri.base.queryParameters['screen'] ?? 'counter';
  runApp(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        currentBusinessProvider.overrideWith((ref) async => _business),
        productsProvider.overrideWith((ref) => Stream.value(_products)),
        customersProvider.overrideWith((ref) => Stream.value(_customers)),
        billingServiceProvider.overrideWith((ref) => null),
        paginatedInvoicesProvider.overrideWith(
          () => _PreviewInvoicesNotifier(),
        ),
      ],
      child: _PreviewApp(screen: screen),
    ),
  );
}

class _PreviewApp extends StatelessWidget {
  final String screen;
  const _PreviewApp({required this.screen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: switch (screen) {
        'invoices' => const BillingScreen(),
        'details' => const InvoiceDetailsScreen(invoiceId: 'inv2'),
        _ => const _SeededCounter(),
      },
    );
  }
}

class _SeededCounter extends ConsumerStatefulWidget {
  const _SeededCounter();
  @override
  ConsumerState<_SeededCounter> createState() => _SeededCounterState();
}

class _SeededCounterState extends ConsumerState<_SeededCounter> {
  bool _seeded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_seeded) return;
      _seeded = true;
      final cart = ref.read(cartProvider.notifier);
      cart.setCustomer(_customers.first);
      cart.addItem(_products[3], quantity: 2);
      cart.addItem(_products[4], quantity: 1);
      cart.addItem(_products[0], quantity: 3);
      cart.setPayment(500, 'Cash');
    });
  }

  @override
  Widget build(BuildContext context) => const NewInvoiceScreen();
}
