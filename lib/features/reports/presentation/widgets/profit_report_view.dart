import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reports_provider.dart';

class ProfitReportView extends ConsumerWidget {
  const ProfitReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(profitReportSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profitReportSummaryProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: summaryAsync.when(
              data: (summary) {
                final isNegative = summary.netProfit < 0;
                final profitColor = isNegative ? Colors.red : Colors.green;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profit & Loss Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        color: profitColor.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  'Net Profit',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: profitColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${summary.netProfit.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: profitColor,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Sales',
                              value:
                                  '₹${summary.totalSales.toStringAsFixed(2)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Purchases',
                              value:
                                  '₹${summary.totalPurchases.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SummaryCard(
                        title: 'Total Expenses',
                        value: '₹${summary.totalExpenses.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
