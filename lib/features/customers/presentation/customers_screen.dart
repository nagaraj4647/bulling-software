import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../providers/customer_provider.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedCustomersProvider);
    final customers = ref.watch(paginatedFilteredCustomersProvider);
    final currentFilter = ref.watch(customerFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Add Customer'),
            onPressed: () => context.go('/customers/add'),
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
                hintText: 'Search by name, phone, or email...',
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
              onChanged: (value) => ref
                  .read(customerSearchQueryProvider.notifier)
                  .setQuery(value),
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
              children: CustomerFilter.values.map((filter) {
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
                            .read(customerFilterProvider.notifier)
                            .setFilter(filter);
                      }
                    },
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                  ),
                ).animate().fade().slideX(
                  begin: 0.1,
                  delay: (CustomerFilter.values.indexOf(filter) * 50).ms,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: paginatedState.isLoading && paginatedState.customers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SkeletonList(itemCount: 8),
                  )
                : paginatedState.error != null &&
                      paginatedState.customers.isEmpty
                ? AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'Failed to load customers',
                    subtitle: paginatedState.error.toString(),
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.read(paginatedCustomersProvider.notifier).refresh(),
                  ).animate().fade().scale()
                : customers.isEmpty
                ? AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers yet',
                    subtitle: 'Add your first customer to start tracking sales',
                    actionLabel: 'Add Customer',
                    onAction: () => context.go('/customers/add'),
                  ).animate().fade().scale()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(paginatedCustomersProvider.notifier).refresh(),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo is ScrollEndNotification &&
                            scrollInfo.metrics.extentAfter < 200 &&
                            paginatedState.hasMore &&
                            !paginatedState.isLoading) {
                          ref
                              .read(paginatedCustomersProvider.notifier)
                              .loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount:
                            customers.length + (paginatedState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= customers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SkeletonLoader(
                                height: 80,
                                borderRadius: 16,
                              ),
                            );
                          }

                          final customer = customers[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Card(
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withAlpha(30),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: customer.isActive
                                      ? theme.colorScheme.primaryContainer
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  child: Text(
                                    customer.name.isNotEmpty
                                        ? customer.name[0].toUpperCase()
                                        : '?',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: customer.isActive
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customer.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              decoration: customer.isActive
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                              color: customer.isActive
                                                  ? null
                                                  : theme.colorScheme.outline,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!customer.isActive)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                  child: Text(
                                    '${customer.phone?.isNotEmpty == true ? customer.phone : 'No phone'} • ${customer.city?.isNotEmpty == true ? customer.city : 'No city'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${customer.outstandingBalance.toStringAsFixed(2)}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                customer.outstandingBalance > 0
                                                ? AppTheme.error
                                                : (customer.isActive
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .outline),
                                          ),
                                    ),
                                    if (customer.outstandingBalance > 0)
                                      const Text(
                                        'Outstanding',
                                        style: TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => context.go(
                                  '/customers/${customer.customerId}',
                                ),
                              ),
                            ),
                          ).animate().fade().slideX(
                            begin: 0.1,
                            delay: Duration(
                              milliseconds: (index * 30).clamp(0, 500),
                            ),
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
              onPressed: () => context.go('/customers/add'),
              tooltip: 'Add Customer',
              child: const Icon(Icons.person_add),
            ).animate().fade().scale(delay: 500.ms)
          : null,
    );
  }
}
