import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../providers/billing_provider.dart';
import '../models/invoice_model.dart';
import '../../../../core/theme/app_theme.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedInvoicesProvider);
    final currentFilter = ref.watch(invoiceFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Future: implement search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter pills
          Container(
            color: theme.colorScheme.surface,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: InvoiceFilter.values.map((filter) {
                  final isSelected = currentFilter == filter;
                  final label =
                      filter.name[0].toUpperCase() + filter.name.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => ref
                          .read(invoiceFilterProvider.notifier)
                          .setFilter(filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: paginatedState.isLoading && paginatedState.invoices.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : paginatedState.invoices.isEmpty
                ? AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices found',
                    subtitle: 'Create a new invoice to start billing',
                    actionLabel: 'Create Invoice',
                    onAction: () => context.go('/billing/new'),
                  ).animate().fade().scale(curve: Curves.easeOutBack)
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                        ref.read(paginatedInvoicesProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount:
                          paginatedState.invoices.length +
                          (paginatedState.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == paginatedState.invoices.length) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final invoice = paginatedState.invoices[index];
                        final isConfirmed =
                            invoice.status == InvoiceStatus.confirmed;
                        final isCancelled =
                            invoice.status == InvoiceStatus.cancelled;

                        Color statusColor = AppTheme.draft;
                        if (isConfirmed) statusColor = AppTheme.confirmed;
                        if (isCancelled) statusColor = AppTheme.cancelled;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              Card(
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.05),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                      onTap: () => context.go(
                                        '/billing/${invoice.invoiceId}',
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                isConfirmed
                                                    ? Icons.check_circle_outline
                                                    : (isCancelled
                                                          ? Icons
                                                                .cancel_outlined
                                                          : Icons.edit_note),
                                                color: statusColor,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          invoice
                                                                  .customerSnapshot
                                                                  ?.name ??
                                                              'Walk-in Customer',
                                                          style: theme
                                                              .textTheme
                                                              .titleMedium,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        '\u20B9${invoice.grandTotal.toStringAsFixed(2)}',
                                                        style: theme
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'Draft'} \u2022 ${DateFormat('dd MMM yyyy').format(invoice.issueDate)}',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .outline,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              decoration:
                                                                  isCancelled
                                                                  ? TextDecoration
                                                                        .lineThrough
                                                                  : null,
                                                            ),
                                                      ),
                                                      const Spacer(),
                                                      _PaymentBadge(
                                                        invoice: invoice,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fade(
                                    duration: 300.ms,
                                    delay:
                                        ((index * 50) > 500
                                                ? 500
                                                : (index * 50))
                                            .ms,
                                  )
                                  .slideX(begin: 0.05, end: 0),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/billing/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final InvoiceModel invoice;

  const _PaymentBadge({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (invoice.status == InvoiceStatus.draft) {
      return _pill(theme, 'Draft', AppTheme.draft);
    }
    if (invoice.status == InvoiceStatus.cancelled) {
      return _pill(theme, 'Cancelled', AppTheme.cancelled);
    }

    final balance = invoice.payment.balanceAmount;
    if (balance <= 0) {
      return _pill(theme, 'Paid', AppTheme.paid);
    }
    if (invoice.payment.paidAmount > 0) {
      return _pill(
        theme,
        'Due \u20B9${balance.toStringAsFixed(2)}',
        AppTheme.partial,
      );
    }
    return _pill(theme, 'Unpaid', AppTheme.unpaid);
  }

  Widget _pill(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
