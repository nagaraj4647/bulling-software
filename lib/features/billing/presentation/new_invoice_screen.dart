import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/utils/error_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/cart_provider.dart';
import '../providers/billing_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../customers/models/customer_model.dart';
import '../models/invoice_model.dart';
import '../../business/providers/business_provider.dart';
import '../../products/models/product_model.dart';

class NewInvoiceScreen extends ConsumerStatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  ConsumerState<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends ConsumerState<NewInvoiceScreen> {
  final _paymentController = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _isGstInclusive = false;

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomerPickerSheet(),
    );
  }

  void _confirmInvoice(InvoiceModel invoice) async {
    final controller = ref.read(billingControllerProvider.notifier);

    // Validate state requirement if GST applies
    if (invoice.cgstTotal > 0 ||
        invoice.sgstTotal > 0 ||
        invoice.igstTotal > 0) {
      final business = ref.read(currentBusinessProvider).value;
      if (business?.businessState == null ||
          business!.businessState!.isEmpty ||
          invoice.customerSnapshot?.state == null ||
          invoice.customerSnapshot!.state!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GST Error: Both Business and Customer state must be provided for GST calculation.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      await controller.confirmInvoice(invoice);
      if (mounted) {
        final state = ref.read(billingControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${ErrorFormatter.format(state.error)}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ref.read(cartProvider.notifier).clearCart();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice confirmed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final invoice = ref.watch(cartTotalsProvider);
    final isLoading = ref.watch(billingControllerProvider).isLoading;

    _isGstInclusive = cartState.isGstInclusive;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Invoice'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Cart'),
            onPressed: () => ref.read(cartProvider.notifier).clearCart(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 900;

          if (isLargeScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Products Grid
                const Expanded(flex: 5, child: ProductSelectionSection()),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
                ),
                // Right side: Cart and Checkout
                Expanded(
                  flex: 4,
                  child: _buildCartAndCheckoutPanel(
                    cartState,
                    invoice,
                    isLoading,
                    theme,
                  ).animate().fade().slideX(begin: 0.05),
                ),
              ],
            );
          }

          // Mobile layout
          return Column(
            children: [
              const Expanded(flex: 1, child: ProductSelectionSection()),
              _buildMobileCheckoutBottomBar(
                cartState,
                invoice,
                isLoading,
                theme,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileCheckoutBottomBar(
    CartState cartState,
    InvoiceModel? invoice,
    bool isLoading,
    ThemeData theme,
  ) {
    if (invoice == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: AppTheme.premiumShadow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusL),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total (${cartState.items.length} items)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      '₹${invoice.grandTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showMobileCartBottomSheet(
                    cartState,
                    invoice,
                    isLoading,
                    theme,
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('View Cart & Pay'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: 1.0,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }

  void _showMobileCartBottomSheet(
    CartState cartState,
    InvoiceModel invoice,
    bool isLoading,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) => _buildCartAndCheckoutPanel(
        cartState,
        invoice,
        isLoading,
        theme,
        isMobileSheet: true,
      ),
    );
  }

  Widget _buildCartAndCheckoutPanel(
    CartState cartState,
    InvoiceModel? invoice,
    bool isLoading,
    ThemeData theme, {
    bool isMobileSheet = false,
  }) {
    if (invoice == null) return const SizedBox.shrink();

    Widget panel = Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          if (isMobileSheet)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cart Details', style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

          // Customer Selection
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              onTap: _showCustomerPicker,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withAlpha(40),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    50,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartState.customer?.name ?? 'Walk-in Customer',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            cartState.customer?.phone ??
                                'Tap to select customer',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Scrollable area: cart items + bill summary share the space, so
          // every item stays inspectable and editable at any panel height.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (cartState.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cart is empty',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < cartState.items.length;
                          index++
                        )
                          _buildCartItemCard(cartState.items[index], theme)
                              .animate()
                              .fade()
                              .slideX(begin: 0.1, delay: (index * 50).ms),
                      ],
                    ),
                  ),

                // Bill summary + payment
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      50,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withAlpha(40),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'GST Inclusive Prices',
                          style: theme.textTheme.titleSmall,
                        ),
                        value: _isGstInclusive,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (val) {
                          setState(() => _isGstInclusive = val);
                          ref
                              .read(cartProvider.notifier)
                              .setIsGstInclusive(val);
                        },
                      ),
                      const SizedBox(height: 4),
                      _buildAnimatedAmountRow(
                        'Subtotal',
                        invoice.subtotal,
                        theme,
                      ),
                      _buildAnimatedAmountRow(
                        'Taxable Amount',
                        invoice.taxableAmount,
                        theme,
                      ),
                      if (invoice.cgstTotal > 0)
                        _buildAnimatedAmountRow(
                          'CGST',
                          invoice.cgstTotal,
                          theme,
                        ),
                      if (invoice.sgstTotal > 0)
                        _buildAnimatedAmountRow(
                          'SGST',
                          invoice.sgstTotal,
                          theme,
                        ),
                      if (invoice.igstTotal > 0)
                        _buildAnimatedAmountRow(
                          'IGST',
                          invoice.igstTotal,
                          theme,
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grand Total',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: invoice.grandTotal,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Text(
                                '\u20B9${value.toStringAsFixed(2)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment controls
                      TextField(
                        controller: _paymentController,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (\u20B9)',
                          suffixIcon: TextButton(
                            onPressed: () {
                              _paymentController.text = invoice.grandTotal
                                  .toStringAsFixed(2);
                              ref
                                  .read(cartProvider.notifier)
                                  .setPayment(
                                    invoice.grandTotal,
                                    _paymentMethod,
                                  );
                            },
                            child: const Text('Exact'),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final amount = double.tryParse(val) ?? 0.0;
                          ref
                              .read(cartProvider.notifier)
                              .setPayment(amount, _paymentMethod);
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Cash', 'UPI', 'Card', 'Bank'].map((m) {
                          final selected = _paymentMethod == m;
                          return ChoiceChip(
                            label: Text(m),
                            selected: selected,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide.none,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _paymentMethod = m);
                                ref
                                    .read(cartProvider.notifier)
                                    .setPayment(cartState.paidAmount, m);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _buildAnimatedAmountRow(
                        'Balance Due',
                        invoice.payment.balanceAmount,
                        theme,
                        color: invoice.payment.balanceAmount > 0
                            ? AppTheme.error
                            : AppTheme.success,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pinned checkout button - always visible regardless of scroll.
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
                ),
              ),
              boxShadow: AppTheme.premiumShadow,
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child:
                  FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppTheme.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                        ),
                        onPressed: isLoading || cartState.items.isEmpty
                            ? null
                            : () => _confirmInvoice(invoice),
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 24),
                        label: Text(
                          isLoading
                              ? 'Processing...'
                              : 'Complete Checkout  \u2022  \u20B9${invoice.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                      .animate(target: cartState.items.isNotEmpty ? 1 : 0)
                      .scaleXY(end: 1, begin: 0.95)
                      .fade(),
            ),
          ),
        ],
      ),
    );

    return isMobileSheet ? SafeArea(child: panel) : panel;
  }

  Widget _buildCartItemCard(CartItem item, ThemeData theme) {
    final lineTotal = item.quantity * item.product.sellingPrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .removeItem(item.product.productId!),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '\u20B9${item.product.sellingPrice.toStringAsFixed(2)} / ${item.product.unit ?? 'unit'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              _QuantityButton(
                icon: Icons.remove,
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .updateQuantity(item.product.productId!, item.quantity - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  item.quantity == item.quantity.roundToDouble()
                      ? item.quantity.toStringAsFixed(0)
                      : item.quantity.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                filled: true,
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .updateQuantity(item.product.productId!, item.quantity + 1),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Text(
                  '\u20B9${lineTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAmountRow(
    String label,
    double amount,
    ThemeData theme, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? theme.colorScheme.outline,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                '₹${value.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ── Components ──────────────────────────────────────────────

class ProductSelectionSection extends ConsumerStatefulWidget {
  const ProductSelectionSection({super.key});

  @override
  ConsumerState<ProductSelectionSection> createState() =>
      _ProductSelectionSectionState();
}

class _ProductSelectionSectionState
    extends ConsumerState<ProductSelectionSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredProductsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products by name...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) =>
                ref.read(productSearchQueryProvider.notifier).setQuery(value),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    'No products found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    if (!product.isActive) return const SizedBox.shrink();
                    return _ProductGridItem(product: product)
                        .animate()
                        .fade()
                        .scale(
                          delay: ((index * 20) > 500 ? 500 : (index * 20)).ms,
                        );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductGridItem extends ConsumerWidget {
  final ProductModel product;

  const _ProductGridItem({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOutOfStock = product.stockQuantity <= 0;
    final isLowStock =
        !isOutOfStock && product.stockQuantity <= product.lowStockThreshold;
    final cartQty = ref
        .watch(cartProvider)
        .items
        .where((i) => i.product.productId == product.productId)
        .fold<double>(0, (sum, i) => sum + i.quantity);
    final inCart = cartQty > 0;

    final stockColor = isOutOfStock
        ? AppTheme.error
        : (isLowStock ? AppTheme.warning : AppTheme.success);
    final stockLabel = isOutOfStock
        ? 'Out of stock'
        : (isLowStock
              ? 'Low: ${product.stockQuantity.toStringAsFixed(0)}'
              : '${product.stockQuantity.toStringAsFixed(0)} left');

    return Opacity(
      opacity: isOutOfStock ? 0.55 : 1,
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          side: BorderSide(
            color: inCart
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withAlpha(60),
            width: inCart ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: isOutOfStock
              ? null
              : () => ref.read(cartProvider.notifier).addItem(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if ((product.category ?? '').isNotEmpty)
                      Expanded(
                        child: Text(
                          product.category!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stockColor.withAlpha(22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stockLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: stockColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    product.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '\u20B9${product.sellingPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (inCart)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              cartQty.toStringAsFixed(
                                cartQty == cartQty.roundToDouble() ? 0 : 1,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Icon(
                        Icons.add_circle,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerPickerSheet extends ConsumerWidget {
  const CustomerPickerSheet({super.key});

  void _openQuickAddDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuickAddCustomerDialog(
        initialName: initialName,
        onCustomerCreated: (newCustomer) {
          ref.read(cartProvider.notifier).setCustomer(newCustomer);
          if (context.mounted) {
            context.pop(); // Close the customer picker sheet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Customer "${newCustomer.name}" added & selected!',
                ),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(filteredCustomersProvider);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(customerSearchQueryProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            child: Row(
              children: [
                Text(
                  'Select Customer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openQuickAddDialog(
                    context,
                    ref,
                    initialName: searchQuery.isNotEmpty ? searchQuery : null,
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Customer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer name or phone...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => ref
                            .read(customerSearchQueryProvider.notifier)
                            .setQuery(''),
                      )
                    : null,
              ),
              onChanged: (value) => ref
                  .read(customerSearchQueryProvider.notifier)
                  .setQuery(value),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: customers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_search_rounded,
                              color: Color(0xFF2563EB),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isEmpty
                                ? 'No customers registered yet'
                                : 'No customer found for "$searchQuery"',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Quickly add basic details (Name, Phone, Address)',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => _openQuickAddDialog(
                              context,
                              ref,
                              initialName: searchQuery,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              searchQuery.isNotEmpty
                                  ? 'Add "$searchQuery" as Customer'
                                  : 'Add New Customer',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      if (!customer.isActive) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withAlpha(
                              40,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '${customer.phone ?? 'No phone'}${customer.address != null && customer.address!.isNotEmpty ? ' • ${customer.address}' : ''} | Bal: ₹${customer.outstandingBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: () {
                            ref
                                .read(cartProvider.notifier)
                                .setCustomer(customer);
                            context.pop();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Simple Quick Add Customer Modal asking only Name, Phone, and Address.
class _QuickAddCustomerDialog extends ConsumerStatefulWidget {
  final String? initialName;
  final ValueChanged<CustomerModel> onCustomerCreated;

  const _QuickAddCustomerDialog({
    this.initialName,
    required this.onCustomerCreated,
  });

  @override
  ConsumerState<_QuickAddCustomerDialog> createState() =>
      _QuickAddCustomerDialogState();
}

class _QuickAddCustomerDialogState
    extends ConsumerState<_QuickAddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final business = ref.read(currentBusinessProvider).value;
    if (business == null || business.businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active business selected')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(customerServiceProvider);
      if (service == null) throw Exception('Customer service unavailable');

      final newCustomer = CustomerModel(
        businessId: business.businessId!,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      final newId = await service.createCustomer(newCustomer);
      final createdCustomer = newCustomer.copyWith(customerId: newId);

      // Refresh customers state
      ref.invalidate(customersProvider);
      ref.read(paginatedCustomersProvider.notifier).refresh();

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        widget.onCustomerCreated(createdCustomer);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Add Customer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Add customer name, number & address',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Name Field (Required)
                Text(
                  'Customer Name *',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ramesh Kumar',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Field (Optional / Recommended)
                Text(
                  'Phone Number',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Address Field (Optional)
                Text(
                  'Address',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 12, North Street, Town',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save & Select',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
