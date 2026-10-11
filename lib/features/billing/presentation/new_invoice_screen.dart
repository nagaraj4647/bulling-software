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
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: _showCustomerPicker,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(width: 16),
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

          // Cart Items List
          Expanded(
            child: cartState.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartState.items.length,
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return _buildCartItemCard(item, theme)
                          .animate()
                          .fade()
                          .slideX(begin: 0.1, delay: (index * 50).ms);
                    },
                  ),
          ),

          // Checkout Section
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
                ),
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'GST Inclusive Prices',
                    style: theme.textTheme.titleSmall,
                  ),
                  value: _isGstInclusive,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() => _isGstInclusive = val);
                    ref.read(cartProvider.notifier).setIsGstInclusive(val);
                  },
                ),
                const SizedBox(height: 8),
                _buildAnimatedAmountRow('Subtotal', invoice.subtotal, theme),
                _buildAnimatedAmountRow(
                  'Taxable Amount',
                  invoice.taxableAmount,
                  theme,
                ),
                if (invoice.cgstTotal > 0)
                  _buildAnimatedAmountRow('CGST', invoice.cgstTotal, theme),
                if (invoice.sgstTotal > 0)
                  _buildAnimatedAmountRow('SGST', invoice.sgstTotal, theme),
                if (invoice.igstTotal > 0)
                  _buildAnimatedAmountRow('IGST', invoice.igstTotal, theme),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
                      tween: Tween<double>(begin: 0, end: invoice.grandTotal),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '₹${value.toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Payment controls
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _paymentController,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (₹)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.done_all),
                            tooltip: 'Full Payment',
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(labelText: 'Method'),
                        items: ['Cash', 'UPI', 'Card', 'Bank']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _paymentMethod = val);
                            ref
                                .read(cartProvider.notifier)
                                .setPayment(cartState.paidAmount, val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAnimatedAmountRow(
                  'Balance Due',
                  invoice.payment.balanceAmount,
                  theme,
                  color: invoice.payment.balanceAmount > 0
                      ? AppTheme.error
                      : AppTheme.success,
                  isBold: true,
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
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
                        isLoading ? 'Processing...' : 'Complete Checkout',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .animate(target: cartState.items.isNotEmpty ? 1 : 0)
                    .scaleXY(end: 1, begin: 0.95)
                    .fade(),
              ],
            ),
          ),
        ],
      ),
    );

    return isMobileSheet ? SafeArea(child: panel) : panel;
  }

  Widget _buildCartItemCard(CartItem item, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(30),
        ),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(
                128,
              ), // 0.5 opacity
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            alignment: Alignment.center,
            child: Text(
              item.product.name.substring(0, 1).toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.product.sellingPrice.toStringAsFixed(2)} / ${item.product.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${(item.quantity * item.product.sellingPrice).toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QuantityButton(
                    icon: Icons.remove,
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(
                          item.product.productId!,
                          item.quantity - 1,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${item.quantity}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add,
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(
                          item.product.productId!,
                          item.quantity + 1,
                        ),
                  ),
                ],
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

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
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
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(12), // Premium subtle shadow
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(30)),
      ),
      child: InkWell(
        onTap: isOutOfStock
            ? null
            : () {
                ref.read(cartProvider.notifier).addItem(product);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: theme.colorScheme.primaryContainer.withAlpha(
                  76,
                ), // ~0.3 alpha
                alignment: Alignment.center,
                child: Text(
                  product.name.substring(0, 1).toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.sellingPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? AppTheme.error.withAlpha(25)
                                : AppTheme.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOutOfStock ? 'Out' : '${product.stockQuantity}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isOutOfStock
                                  ? AppTheme.error
                                  : AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerPickerSheet extends ConsumerWidget {
  const CustomerPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(filteredCustomersProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Customer', style: theme.textTheme.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search customer...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref
                  .read(customerSearchQueryProvider.notifier)
                  .setQuery(value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                if (!customer.isActive) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shadowColor: Colors.black.withAlpha(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withAlpha(30),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        customer.name[0].toUpperCase(),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${customer.phone ?? ''} | Bal: ₹${customer.outstandingBalance.toStringAsFixed(2)}',
                    ),
                    onTap: () {
                      ref.read(cartProvider.notifier).setCustomer(customer);
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
