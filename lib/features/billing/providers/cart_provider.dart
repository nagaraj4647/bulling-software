import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/models/product_model.dart';
import '../../customers/models/customer_model.dart';
import '../models/invoice_model.dart';
import '../data/billing_calculator.dart';
import '../../business/providers/business_provider.dart';

class CartItem {
  final ProductModel product;
  final double quantity;
  final double discount;

  CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0.0,
  });

  CartItem copyWith({
    ProductModel? product,
    double? quantity,
    double? discount,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
    );
  }
}

class CartState {
  final CustomerModel? customer;
  final List<CartItem> items;
  final double globalDiscount;
  final double paidAmount;
  final String paymentMethod;
  final bool isGstInclusive;

  CartState({
    this.customer,
    this.items = const [],
    this.globalDiscount = 0.0,
    this.paidAmount = 0.0,
    this.paymentMethod = 'Cash',
    this.isGstInclusive = false,
  });

  CartState copyWith({
    CustomerModel? customer,
    List<CartItem>? items,
    double? globalDiscount,
    double? paidAmount,
    String? paymentMethod,
    bool? isGstInclusive,
  }) {
    return CartState(
      customer: customer ?? this.customer,
      items: items ?? this.items,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isGstInclusive: isGstInclusive ?? this.isGstInclusive,
    );
  }

  // Clear customer but keep other fields
  CartState clearCustomer() {
    return CartState(
      items: items,
      globalDiscount: globalDiscount,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      isGstInclusive: isGstInclusive,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    final business = ref.watch(currentBusinessProvider).value;
    return CartState(isGstInclusive: business?.isGstInclusive ?? false);
  }

  void setCustomer(CustomerModel customer) {
    state = state.copyWith(customer: customer);
  }

  void clearCustomer() {
    state = state.clearCustomer();
  }

  void setIsGstInclusive(bool value) {
    state = state.copyWith(isGstInclusive: value);
  }

  void addItem(ProductModel product, {double quantity = 1.0}) {
    if (state.items.length >= 100) return; // Hard limit

    final index = state.items.indexWhere(
      (i) => i.product.productId == product.productId,
    );
    if (index >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[index] = updated[index].copyWith(
        quantity: updated[index].quantity + quantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(product: product, quantity: quantity),
        ],
      );
    }
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final updated = state.items.map((item) {
      if (item.product.productId == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void updateItemDiscount(String productId, double discount) {
    final updated = state.items.map((item) {
      if (item.product.productId == productId) {
        return item.copyWith(discount: discount);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void setGlobalDiscount(double discount) {
    state = state.copyWith(globalDiscount: discount);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items
          .where((i) => i.product.productId != productId)
          .toList(),
    );
  }

  void setPayment(double paidAmount, String method) {
    state = state.copyWith(paidAmount: paidAmount, paymentMethod: method);
  }

  void clearCart() {
    final business = ref.read(currentBusinessProvider).value;
    state = CartState(isGstInclusive: business?.isGstInclusive ?? false);
  }

  InvoiceModel? generateInvoice(String businessId) {
    if (state.items.isEmpty) return null;

    final business = ref.read(currentBusinessProvider).value;
    if (business == null) return null;

    double subtotal = 0;
    double cgstTotal = 0;
    double sgstTotal = 0;
    double igstTotal = 0;
    double totalTaxableValue = 0;
    double totalDiscount = 0;

    final List<InvoiceItemModel> invoiceItems = [];

    // Distribute global discount proportionally if exists (simple proportional distribution based on subtotal)
    final totalItemsSubtotal = state.items.fold(
      0.0,
      (sum, item) => sum + (item.quantity * item.product.sellingPrice),
    );

    for (var cartItem in state.items) {
      final p = cartItem.product;
      final itemSubtotal = BillingCalculator.calculateItemSubtotal(
        cartItem.quantity,
        p.sellingPrice,
      );

      // Calculate distributed global discount for this item
      double proportionalGlobalDiscount = 0.0;
      if (state.globalDiscount > 0 && totalItemsSubtotal > 0) {
        proportionalGlobalDiscount =
            (itemSubtotal / totalItemsSubtotal) * state.globalDiscount;
      }

      final totalItemDiscount = cartItem.discount + proportionalGlobalDiscount;

      double taxableValue;
      double itemGstAmount;

      if (state.isGstInclusive) {
        final amountAfterDiscount = itemSubtotal - totalItemDiscount;
        taxableValue =
            BillingCalculator.calculateTaxableValueFromInclusiveTotal(
              amountAfterDiscount,
              p.gstRate,
            );
        itemGstAmount = BillingCalculator.round2(
          amountAfterDiscount - taxableValue,
        );
      } else {
        taxableValue = BillingCalculator.calculateItemTaxableValue(
          itemSubtotal,
          totalItemDiscount,
        );
        itemGstAmount = BillingCalculator.calculateGstAmount(
          taxableValue,
          p.gstRate,
        );
      }

      final taxBreakdown = BillingCalculator.determineGstSplit(
        businessState: business.businessState,
        customerState: state.customer?.state,
        gstRate: p.gstRate,
        totalGstAmount: itemGstAmount,
      );

      final totalAmount = BillingCalculator.calculateItemTotal(
        taxableValue,
        itemGstAmount,
      );

      subtotal += itemSubtotal;
      totalDiscount += totalItemDiscount;
      totalTaxableValue += taxableValue;
      cgstTotal += taxBreakdown.cgst;
      sgstTotal += taxBreakdown.sgst;
      igstTotal += taxBreakdown.igst;

      invoiceItems.add(
        InvoiceItemModel(
          productId: p.productId!,
          productNameSnapshot: p.name,
          skuSnapshot: p.sku,
          quantity: cartItem.quantity,
          unitPrice: p.sellingPrice,
          discount: totalItemDiscount,
          taxableValue: taxableValue,
          gstRate: p.gstRate,
          cgstAmount: taxBreakdown.cgst,
          sgstAmount: taxBreakdown.sgst,
          igstAmount: taxBreakdown.igst,
          totalAmount: totalAmount,
        ),
      );
    }

    final grandTotal = BillingCalculator.round2(
      totalTaxableValue + cgstTotal + sgstTotal + igstTotal,
    );

    // Payment Status Logic
    String paymentStatus = 'Unpaid';
    double actualPaid = state.paidAmount;
    if (actualPaid > grandTotal) actualPaid = grandTotal; // Cap at grand total

    if (actualPaid == 0) {
      paymentStatus = 'Unpaid';
    } else if (actualPaid > 0 && actualPaid < grandTotal) {
      paymentStatus = 'Partially Paid';
    } else if (actualPaid == grandTotal) {
      paymentStatus = 'Paid';
    }

    double balanceAmount = BillingCalculator.round2(grandTotal - actualPaid);
    String actualPaymentMethod = actualPaid == 0 ? 'None' : state.paymentMethod;

    return InvoiceModel(
      businessId: businessId,
      invoiceNumber: '', // Drafts have no number
      issueDate: DateTime.now(),
      customerSnapshot: state.customer != null
          ? CustomerSnapshot(
              customerId: state.customer!.customerId!,
              name: state.customer!.name,
              phone: state.customer!.phone,
              address: state.customer!.address,
              city: state.customer!.city,
              state: state.customer!.state,
              gstNumber: state.customer!.gstNumber,
            )
          : null,
      items: invoiceItems,
      subtotal: BillingCalculator.round2(subtotal),
      discountAmount: BillingCalculator.round2(totalDiscount),
      taxableAmount: BillingCalculator.round2(totalTaxableValue),
      cgstTotal: BillingCalculator.round2(cgstTotal),
      sgstTotal: BillingCalculator.round2(sgstTotal),
      igstTotal: BillingCalculator.round2(igstTotal),
      grandTotal: grandTotal,
      payment: InvoicePayment(
        status: paymentStatus,
        paidAmount: actualPaid,
        balanceAmount: balanceAmount,
        paymentMethod: actualPaymentMethod,
      ),
      status: InvoiceStatus.draft,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

final cartTotalsProvider = Provider<InvoiceModel?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;

  // Reading cart state causes this to rebuild when cart changes
  ref.watch(cartProvider);

  return ref.read(cartProvider.notifier).generateInvoice(business.businessId!);
});
