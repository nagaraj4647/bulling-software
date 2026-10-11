import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/data/billing_calculator.dart';

/// A single cart line item for building a purchase.
class PurchaseCartItem {
  final String productId;
  final String productName;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double gstRate;

  PurchaseCartItem({
    required this.productId,
    required this.productName,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    this.gstRate = 0.0,
  });

  PurchaseCartItem copyWith({
    double? quantity,
    double? unitPrice,
    double? discount,
    double? gstRate,
  }) {
    return PurchaseCartItem(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      gstRate: gstRate ?? this.gstRate,
    );
  }

  double get subtotal => BillingCalculator.round2(quantity * unitPrice);
  double get taxableValue => BillingCalculator.round2(subtotal - discount);
  double get gstAmount =>
      BillingCalculator.calculateGstAmount(taxableValue, gstRate);
  double get totalAmount =>
      BillingCalculator.calculateItemTotal(taxableValue, gstAmount);
}

/// Cart state holding supplier selection, items, and payment.
class PurchaseCartState {
  final String? supplierId;
  final String? supplierName;
  final Map<String, dynamic>? supplierSnapshot;
  final List<PurchaseCartItem> items;
  final double paidAmount;
  final String paymentMethod;
  final String? notes;

  PurchaseCartState({
    this.supplierId,
    this.supplierName,
    this.supplierSnapshot,
    this.items = const [],
    this.paidAmount = 0.0,
    this.paymentMethod = 'None',
    this.notes,
  });

  double get subtotal {
    double total = 0;
    for (final item in items) {
      total += item.subtotal;
    }
    return BillingCalculator.round2(total);
  }

  double get totalDiscount {
    double total = 0;
    for (final item in items) {
      total += item.discount;
    }
    return BillingCalculator.round2(total);
  }

  double get taxableAmount =>
      BillingCalculator.round2(subtotal - totalDiscount);

  double get totalGst {
    double total = 0;
    for (final item in items) {
      total += item.gstAmount;
    }
    return BillingCalculator.round2(total);
  }

  double get grandTotal {
    double total = 0;
    for (final item in items) {
      total += item.totalAmount;
    }
    return BillingCalculator.round2(total);
  }

  double get balanceAmount => BillingCalculator.round2(grandTotal - paidAmount);

  String get paymentStatus {
    if (paidAmount >= grandTotal && grandTotal > 0) return 'Paid';
    if (paidAmount <= 0) return 'Unpaid';
    return 'Partially Paid';
  }

  PurchaseCartState copyWith({
    String? supplierId,
    String? supplierName,
    Map<String, dynamic>? supplierSnapshot,
    List<PurchaseCartItem>? items,
    double? paidAmount,
    String? paymentMethod,
    String? notes,
  }) {
    return PurchaseCartState(
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierSnapshot: supplierSnapshot ?? this.supplierSnapshot,
      items: items ?? this.items,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
    );
  }
}

class PurchaseCartNotifier extends Notifier<PurchaseCartState> {
  @override
  PurchaseCartState build() => PurchaseCartState();

  void reset() {
    state = PurchaseCartState();
  }

  void setSupplier({
    required String supplierId,
    required String supplierName,
    required Map<String, dynamic> supplierSnapshot,
  }) {
    state = state.copyWith(
      supplierId: supplierId,
      supplierName: supplierName,
      supplierSnapshot: supplierSnapshot,
    );
  }

  /// Add product to cart. If productId already exists, merge (increment) quantity.
  void addItem(PurchaseCartItem item) {
    final existingIndex = state.items.indexWhere(
      (i) => i.productId == item.productId,
    );
    if (existingIndex >= 0) {
      // Merge: increment quantity
      final existing = state.items[existingIndex];
      final merged = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
      final updated = List<PurchaseCartItem>.from(state.items);
      updated[existingIndex] = merged;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void updateItem(int index, PurchaseCartItem updatedItem) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<PurchaseCartItem>.from(state.items);
    updated[index] = updatedItem;
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<PurchaseCartItem>.from(state.items);
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void setPaidAmount(double amount) {
    state = state.copyWith(paidAmount: amount);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }
}

final purchaseCartProvider =
    NotifierProvider<PurchaseCartNotifier, PurchaseCartState>(
      PurchaseCartNotifier.new,
    );
