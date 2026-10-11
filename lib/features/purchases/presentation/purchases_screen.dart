import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../providers/purchase_provider.dart';
import '../models/purchase_model.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedPurchasesProvider);
    final currentFilter = ref.watch(purchaseFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Purchase'),
            onPressed: () => context.go('/purchases/new'),
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
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PurchaseFilter.values.map((filter) {
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
                              .read(purchaseFilterProvider.notifier)
                              .setFilter(filter);
                        }
                      },
                    ),
                  ).animate().fade().slideX(
                    begin: 0.1,
                    delay: Duration(
                      milliseconds: (PurchaseFilter.values.indexOf(filter) * 50)
                          .clamp(0, 300),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paginatedPurchasesProvider.notifier).refresh(),
              child:
                  paginatedState.isLoading && paginatedState.purchases.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SkeletonList(itemCount: 8),
                    )
                  : paginatedState.purchases.isEmpty
                  ? AppEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'No purchases found',
                      subtitle: 'Record your first purchase to track incoming inventory',
                      actionLabel: 'New Purchase',
                      onAction: () => context.go('/purchases/new'),
                    ).animate().fade().scale()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200) {
                          ref
                              .read(paginatedPurchasesProvider.notifier)
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
                            paginatedState.purchases.length +
                            (paginatedState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == paginatedState.purchases.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SkeletonLoader(
                                height: 80,
                                borderRadius: 16,
                              ),
                            );
                          }
                          final purchase = paginatedState.purchases[index];
                          return _PurchaseListTile(
                            purchase: purchase,
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
              onPressed: () => context.go('/purchases/new'),
              tooltip: 'New Purchase',
              child: const Icon(Icons.add),
            ).animate().fade().scale(delay: 500.ms)
          : null,
    );
  }
}

class _PurchaseListTile extends StatelessWidget {
  final PurchaseModel purchase;
  final int index;

  const _PurchaseListTile({required this.purchase, required this.index});

  Color _statusColor(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.draft:
        return AppTheme.warning;
      case PurchaseStatus.confirmed:
        return AppTheme.success;
      case PurchaseStatus.cancelled:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supplierName =
        purchase.supplierSnapshot?['name'] as String? ?? 'No Supplier';
    final dateStr = DateFormat('dd MMM yyyy').format(purchase.purchaseDate);
    final statusColor = _statusColor(purchase.status);

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
            backgroundColor: statusColor.withAlpha((255 * 0.1).toInt()),
            child: Icon(Icons.shopping_cart, color: statusColor),
          ),
          title: Text(
            purchase.purchaseNumber.isNotEmpty
                ? purchase.purchaseNumber
                : 'DRAFT',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: purchase.status == PurchaseStatus.cancelled
                  ? TextDecoration.lineThrough
                  : null,
              color: purchase.status == PurchaseStatus.cancelled
                  ? theme.colorScheme.outline
                  : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplierName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  dateStr,
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
                '₹${purchase.grandTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: purchase.status == PurchaseStatus.cancelled
                      ? theme.colorScheme.outline
                      : AppTheme.purchasesColor,
                  decoration: purchase.status == PurchaseStatus.cancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  purchase.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            if (purchase.purchaseId != null) {
              context.go('/purchases/${purchase.purchaseId}');
            }
          },
        ),
      ),
    ).animate().fade().slideX(
      begin: 0.1,
      delay: Duration(milliseconds: (index * 30).clamp(0, 300)),
    );
  }
}
