import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_formatter.dart';
import '../../business/providers/business_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../suppliers/models/supplier_model.dart';
import '../providers/purchase_provider.dart';
import '../providers/purchase_cart_provider.dart';
import '../models/purchase_model.dart';
import '../../../core/theme/app_theme.dart';

import 'package:flutter_animate/flutter_animate.dart';

class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  final _paidAmountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseCartProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectSupplier() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return const _SupplierPickerSheet();
      },
    );
  }

  void _addProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return const _PurchaseProductPickerSheet();
      },
    );
  }

  Future<void> _saveDraft() async {
    final cart = ref.read(purchaseCartProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (business == null) return;

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    final purchase = _buildPurchaseFromCart(cart, business.businessId!);
    try {
      await ref.read(purchaseControllerProvider.notifier).saveDraft(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmPurchase() async {
    final cart = ref.read(purchaseCartProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (business == null) return;

    if (cart.supplierId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a supplier')));
      return;
    }
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }
    if (cart.paidAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid amount cannot be negative')),
      );
      return;
    }
    if (cart.paidAmount > cart.grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid amount cannot exceed grand total')),
      );
      return;
    }

    // Check for duplicate productIds (should never happen with merge logic, but validate)
    final productIds = cart.items.map((i) => i.productId).toSet();
    if (productIds.length != cart.items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duplicate products in cart')),
      );
      return;
    }

    // First save as draft, then confirm
    final purchase = _buildPurchaseFromCart(cart, business.businessId!);
    try {
      final purchaseId = await ref
          .read(purchaseControllerProvider.notifier)
          .saveDraft(purchase);
      final savedPurchase = purchase.copyWith(purchaseId: purchaseId);
      await ref
          .read(purchaseControllerProvider.notifier)
          .confirmPurchase(savedPurchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(purchaseCartProvider.notifier).reset();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  PurchaseModel _buildPurchaseFromCart(
    PurchaseCartState cart,
    String businessId,
  ) {
    return PurchaseModel(
      businessId: businessId,
      purchaseNumber: '',
      purchaseDate: DateTime.now(),
      supplierSnapshot: cart.supplierSnapshot,
      items: cart.items
          .map(
            (item) => PurchaseItemModel(
              productId: item.productId,
              productNameSnapshot: item.productName,
              skuSnapshot: item.sku,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discount: item.discount,
              taxableValue: item.taxableValue,
              gstRate: item.gstRate,
              cgstAmount: 0,
              sgstAmount: 0,
              igstAmount: 0,
              totalAmount: item.totalAmount,
            ),
          )
          .toList(),
      subtotal: cart.subtotal,
      discountAmount: cart.totalDiscount,
      taxableAmount: cart.taxableAmount,
      cgstTotal: 0,
      sgstTotal: 0,
      igstTotal: 0,
      grandTotal: cart.grandTotal,
      payment: PurchasePayment(
        status: cart.paymentStatus,
        paidAmount: cart.paidAmount,
        balanceAmount: cart.balanceAmount,
        paymentMethod: cart.paymentMethod,
      ),
      settledAmount: 0.0,
      status: PurchaseStatus.draft,
      notes: cart.notes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(purchaseCartProvider);
    final isProcessing = ref.watch(purchaseControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase'),
        actions: [
          TextButton.icon(
            onPressed: isProcessing ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Draft'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Supplier selection
            Card(
              elevation: 2,
              shadowColor: Colors.black.withAlpha(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withAlpha(30),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  cart.supplierName ?? 'Select Supplier',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: cart.supplierId != null
                    ? Text('ID: ${cart.supplierId}')
                    : const Text('Tap to select'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectSupplier,
              ),
            ).animate().fade().slideY(begin: 0.1, delay: 0.ms),
            const SizedBox(height: 16),

            // Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${cart.items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (cart.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No items added',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ...cart.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _CartItemTile(
                  item: item,
                  index: index,
                  onUpdate: (updated) => ref
                      .read(purchaseCartProvider.notifier)
                      .updateItem(index, updated),
                  onRemove: () =>
                      ref.read(purchaseCartProvider.notifier).removeItem(index),
                );
              }),

            const SizedBox(height: 16),

            // Totals
            Card(
              elevation: 2,
              shadowColor: Colors.black.withAlpha(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withAlpha(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TotalRow('Subtotal', cart.subtotal),
                    _TotalRow('Discount', cart.totalDiscount),
                    _TotalRow('Taxable Amount', cart.taxableAmount),
                    _TotalRow('GST', cart.totalGst),
                    const Divider(height: 24),
                    _TotalRow('Grand Total', cart.grandTotal, bold: true),
                  ],
                ),
              ),
            ).animate().fade().slideY(begin: 0.1, delay: 50.ms),
            const SizedBox(height: 16),

            // Payment
            Card(
              elevation: 2,
              shadowColor: Colors.black.withAlpha(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withAlpha(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _paidAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Paid Amount',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (val) {
                        final amount = double.tryParse(val) ?? 0.0;
                        ref
                            .read(purchaseCartProvider.notifier)
                            .setPaidAmount(amount);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: cart.paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: ['None', 'Cash', 'UPI', 'Card', 'Bank']
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          ref
                              .read(purchaseCartProvider.notifier)
                              .setPaymentMethod(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withAlpha(76),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TotalRow(
                            'Balance (Payable)',
                            cart.balanceAmount,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${cart.paymentStatus}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade().slideY(begin: 0.1, delay: 100.ms),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (val) => ref
                  .read(purchaseCartProvider.notifier)
                  .setNotes(val.isEmpty ? null : val),
            ),
            const SizedBox(height: 24),

            // Confirm button
            FilledButton.icon(
              onPressed: isProcessing ? null : _confirmPurchase,
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(isProcessing ? 'Processing...' : 'Confirm Purchase'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: bold
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : null,
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final PurchaseCartItem item;
  final int index;
  final ValueChanged<PurchaseCartItem> onUpdate;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (item.sku != null)
              Text(
                'SKU: ${item.sku}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) {
                      final qty = double.tryParse(val);
                      if (qty != null && qty > 0)
                        onUpdate(item.copyWith(quantity: qty));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: '₹',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) {
                      final price = double.tryParse(val);
                      if (price != null && price >= 0)
                        onUpdate(item.copyWith(unitPrice: price));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.discount.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Disc.',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: '₹',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) {
                      final disc = double.tryParse(val) ?? 0.0;
                      onUpdate(item.copyWith(discount: disc));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GST: ${item.gstRate}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Total: ₹${item.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierPickerSheet extends ConsumerStatefulWidget {
  const _SupplierPickerSheet();

  @override
  ConsumerState<_SupplierPickerSheet> createState() =>
      _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends ConsumerState<_SupplierPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersState = ref.watch(paginatedSuppliersProvider);
    final allSuppliers = suppliersState.suppliers
        .where((s) => s.isActive)
        .toList();
    final filtered = _query.isEmpty
        ? allSuppliers
        : allSuppliers
              .where(
                (s) =>
                    s.name.toLowerCase().contains(_query) ||
                    s.supplierCode.toLowerCase().contains(_query) ||
                    (s.phone?.toLowerCase().contains(_query) ?? false),
              )
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Supplier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search suppliers...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _query = val.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: suppliersState.isLoading && allSuppliers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? const Center(child: Text('No active suppliers found'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.store)),
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.supplierCode}${s.phone != null ? " • ${s.phone}" : ""}',
                          ),
                          onTap: () {
                            ref
                                .read(purchaseCartProvider.notifier)
                                .setSupplier(
                                  supplierId: s.supplierId,
                                  supplierName: s.name,
                                  supplierSnapshot:
                                      SupplierSnapshot.fromSupplier(s).toMap(),
                                );
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PurchaseProductPickerSheet extends ConsumerStatefulWidget {
  const _PurchaseProductPickerSheet();

  @override
  ConsumerState<_PurchaseProductPickerSheet> createState() =>
      _PurchaseProductPickerSheetState();
}

class _PurchaseProductPickerSheetState
    extends ConsumerState<_PurchaseProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    final allProducts =
        productsState.value?.where((p) => p.isActive).toList() ?? [];
    final filtered = _query.isEmpty
        ? allProducts
        : allProducts
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_query) ||
                    (p.sku?.toLowerCase().contains(_query) ?? false) ||
                    (p.barcode?.toLowerCase().contains(_query) ?? false),
              )
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Product to Purchase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products by name or SKU...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _query = val.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: productsState.isLoading && allProducts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? const Center(child: Text('No active products found'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2),
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            'Current Stock: ${p.stockQuantity} | GST: ${p.gstRate}%',
                          ),
                          trailing: Text(
                            '₹${p.purchasePrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            ref
                                .read(purchaseCartProvider.notifier)
                                .addItem(
                                  PurchaseCartItem(
                                    productId: p.productId!,
                                    productName: p.name,
                                    sku: p.sku,
                                    quantity: 1,
                                    unitPrice: p.purchasePrice,
                                    gstRate: p.gstRate,
                                  ),
                                );
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
