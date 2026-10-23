// Preview harness for UI screenshots. NOT for production.
// Run: flutter build web -t lib/main_preview.dart
// Screens: ?screen=counter | ?screen=invoices | ?screen=details
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/billing/presentation/new_invoice_screen.dart';
import 'features/billing/presentation/billing_screen.dart';
import 'features/billing/presentation/invoice_details_screen.dart';
import 'features/billing/providers/billing_provider.dart';
import 'features/billing/providers/cart_provider.dart';
import 'features/billing/models/invoice_model.dart';
import 'features/business/models/business_model.dart';
import 'features/business/providers/business_provider.dart';
import 'features/customers/models/customer_model.dart';
import 'features/customers/providers/customer_provider.dart';
import 'features/products/models/product_model.dart';
import 'features/products/providers/product_provider.dart';

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

InvoiceModel _invoice(
  String id,
  String number,
  String customer,
  double total,
  double paid,
  String method,
  InvoiceStatus status,
  int daysAgo,
) {
  final paid2 = paid;
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
    items: [
      InvoiceItemModel(
        productId: 'p4',
        productNameSnapshot: 'Aashirvaad Atta 5kg',
        quantity: 2,
        unitPrice: 245,
        discount: 0,
        taxableValue: 466.67,
        gstRate: 5,
        cgstAmount: 11.67,
        sgstAmount: 11.67,
        igstAmount: 0,
        totalAmount: 490,
      ),
      InvoiceItemModel(
        productId: 'p5',
        productNameSnapshot: 'Fortune Sunflower Oil 1L',
        quantity: 1,
        unitPrice: 138,
        discount: 0,
        taxableValue: 131.43,
        gstRate: 5,
        cgstAmount: 3.29,
        sgstAmount: 3.29,
        igstAmount: 0,
        totalAmount: 138,
      ),
    ],
    subtotal: total - (total * 5 / 105),
    discountAmount: 0,
    taxableAmount: total * 100 / 105,
    cgstTotal: total * 5 / 210,
    sgstTotal: total * 5 / 210,
    igstTotal: 0,
    grandTotal: total,
    payment: InvoicePayment(
      status: paid2 >= total
          ? 'Paid'
          : (paid2 > 0 ? 'Partially Paid' : 'Unpaid'),
      paidAmount: paid2,
      balanceAmount: total - paid2,
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
    628.00,
    628.00,
    'UPI',
    InvoiceStatus.confirmed,
    0,
  ),
  _invoice(
    'inv2',
    'INV-1041',
    'Selvi Traders',
    1250.00,
    500.00,
    'Cash',
    InvoiceStatus.confirmed,
    1,
  ),
  _invoice(
    'inv3',
    'INV-1040',
    'Walk-in Customer',
    212.00,
    212.00,
    'Cash',
    InvoiceStatus.confirmed,
    1,
  ),
  _invoice(
    'inv4',
    'INV-1039',
    'Kumar Textiles',
    2145.50,
    0,
    'None',
    InvoiceStatus.draft,
    2,
  ),
  _invoice(
    'inv5',
    'INV-1038',
    'Selvi Traders',
    876.25,
    876.25,
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
