import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dart:async';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../providers/supplier_provider.dart';
import '../models/supplier_model.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supplierSearchQueryProvider.notifier).setQuery('');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(supplierSearchQueryProvider.notifier).setQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedSuppliersProvider);
    final currentFilter = ref.watch(supplierFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
            onPressed: () => context.go('/suppliers/add'),
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
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
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ).animate().fade().slideY(begin: -0.1),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SupplierFilter.values.map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        filter.name[0].toUpperCase() + filter.name.substring(1),
                      ),
                      selected: currentFilter == filter,
                      selectedColor: theme.colorScheme.primaryContainer,
                      checkmarkColor: theme.colorScheme.primary,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(supplierFilterProvider.notifier)
                              .setFilter(filter);
                        }
                      },
                    ),
                  ).animate().fade().slideX(
                    begin: 0.1,
                    delay: Duration(
                      milliseconds: (SupplierFilter.values.indexOf(filter) * 50)
                          .clamp(0, 500),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paginatedSuppliersProvider.notifier).refresh(),
              child:
                  paginatedState.isLoading && paginatedState.suppliers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SkeletonList(itemCount: 8),
                    )
                  : paginatedState.suppliers.isEmpty
                  ? AppEmptyState(
                      icon: Icons.store_outlined,
                      title: 'No suppliers found',
                      subtitle: 'Add a supplier to manage purchases',
                      actionLabel: 'Add Supplier',
                      onAction: () => context.go('/suppliers/add'),
                    ).animate().fade().scale()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200) {
                          ref
                              .read(paginatedSuppliersProvider.notifier)
                              .loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount:
                            paginatedState.suppliers.length +
                            (paginatedState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == paginatedState.suppliers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SkeletonLoader(
                                height: 80,
                                borderRadius: 16,
                              ),
                            );
                          }

                          final supplier = paginatedState.suppliers[index];
                          return SupplierListTile(
                            supplier: supplier,
                            index: index,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width < 600
          ? FloatingActionButton(
              onPressed: () => context.go('/suppliers/add'),
              tooltip: 'Add Supplier',
              child: const Icon(Icons.add),
            ).animate().fade().scale(delay: 500.ms)
          : null,
    );
  }
}

class SupplierListTile extends StatelessWidget {
  final SupplierModel supplier;
  final int index;

  const SupplierListTile({
    super.key,
    required this.supplier,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(30),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: supplier.isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.store,
              color: supplier.isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  supplier.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: supplier.isActive
                        ? null
                        : TextDecoration.lineThrough,
                    color: supplier.isActive ? null : theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!supplier.isActive)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Code: ${supplier.supplierCode}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (supplier.phone != null && supplier.phone!.isNotEmpty)
                  Text(
                    'Ph: ${supplier.phone}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Payable',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(
                '₹${supplier.outstandingBalance.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: supplier.outstandingBalance > 0
                      ? AppTheme.error
                      : (supplier.isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline),
                ),
              ),
            ],
          ),
          onTap: () => context.go('/suppliers/${supplier.supplierId}'),
        ),
      ),
    ).animate().fade().slideX(
      begin: 0.1,
      delay: Duration(milliseconds: (index * 30).clamp(0, 500)),
    );
  }
}
