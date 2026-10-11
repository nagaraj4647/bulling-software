import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(filteredProductsProvider);
    final isLoading = ref.watch(productsProvider).isLoading;
    final currentFilter = ref.watch(productFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            onPressed: () => context.go('/products/add'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
          ).animate().fade().scale(delay: 200.ms),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
              ),
              onChanged: (value) =>
                  ref.read(productSearchQueryProvider.notifier).setQuery(value),
            ).animate().fade().slideY(begin: -0.1),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: ProductFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter.name[0].toUpperCase() + filter.name.substring(1),
                    ),
                    selected: currentFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(productFilterProvider.notifier)
                            .setFilter(filter);
                      }
                    },
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                  ),
                ).animate().fade().slideX(
                  begin: 0.1,
                  delay: (ProductFilter.values.indexOf(filter) * 50).ms,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SkeletonList(itemCount: 8),
                  )
                : products.isEmpty
                ? AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    subtitle: 'Add products to build your inventory',
                    actionLabel: 'Add Product',
                    onAction: () => context.go('/products/add'),
                  ).animate().fade().scale()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        return _buildGridView(products, theme, context);
                      }
                      return _buildListView(products, theme, context);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width < 600
          ? FloatingActionButton(
              onPressed: () => context.go('/products/add'),
              child: const Icon(Icons.add),
            ).animate().fade().scale(delay: 500.ms)
          : null,
    );
  }

  Widget _buildGridView(
    List<ProductModel> products,
    ThemeData theme,
    BuildContext context,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(product: product).animate().fade().slideY(
          begin: 0.1,
          delay: Duration(milliseconds: (index * 30).clamp(0, 500)),
        );
      },
    );
  }

  Widget _buildListView(
    List<ProductModel> products,
    ThemeData theme,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _ProductCard(product: product, isList: true)
              .animate()
              .fade()
              .slideX(
                begin: 0.1,
                delay: Duration(milliseconds: (index * 30).clamp(0, 500)),
              ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isList;

  const _ProductCard({required this.product, this.isList = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLowStock = product.stockQuantity <= product.lowStockThreshold;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/edit/${product.productId}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isList
              ? Row(children: _buildContent(theme, isLowStock))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildContent(theme, isLowStock, isGrid: true),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    ThemeData theme,
    bool isLowStock, {
    bool isGrid = false,
  }) {
    final leading = CircleAvatar(
      radius: isGrid ? 24 : 20,
      backgroundColor: product.isActive
          ? (isLowStock
                ? AppTheme.error.withAlpha(20)
                : theme.colorScheme.primaryContainer)
          : theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2,
        color: product.isActive
            ? (isLowStock ? AppTheme.error : theme.colorScheme.primary)
            : theme.colorScheme.outline,
        size: isGrid ? 24 : 20,
      ),
    );

    final titleAndSku = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: product.isActive
                      ? null
                      : TextDecoration.lineThrough,
                  color: product.isActive ? null : theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!product.isActive)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          product.category ?? 'Uncategorized',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    final stockLabel = product.stockQuantity <= 0
        ? 'Out of Stock'
        : isLowStock
        ? 'Low Stock: ${product.stockQuantity} ${product.unit ?? ''}'
        : 'Stock: ${product.stockQuantity} ${product.unit ?? ''}';

    final stockAndPrice = Column(
      crossAxisAlignment: isGrid
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '₹${product.sellingPrice.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLowStock ? AppTheme.error : AppTheme.success,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              stockLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isLowStock ? AppTheme.error : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );

    if (isGrid) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: titleAndSku),
          ],
        ),
        const Spacer(),
        const Divider(height: 16),
        stockAndPrice,
      ];
    }

    return [
      leading,
      const SizedBox(width: 16),
      Expanded(child: titleAndSku),
      const SizedBox(width: 16),
      stockAndPrice,
    ];
  }
}
