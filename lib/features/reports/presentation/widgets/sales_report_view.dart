import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/reports_provider.dart';
import 'report_pagination_footer.dart';

class SalesReportView extends ConsumerWidget {
  const SalesReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesReportSummaryProvider);
    final salesState = ref.watch(reportSalesProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesReportSummaryProvider);
        await ref.read(reportSalesProvider.notifier).refresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: summaryAsync.when(
              data: (summary) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Summary', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Sales',
                            value: '₹${summary.totalSales.toStringAsFixed(2)}',
                            icon: Icons.trending_up,
                            color: AppTheme.salesColor,
                          ).animate().fade().slideY(begin: 0.1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Invoices',
                            value: '${summary.invoiceCount}',
                            icon: Icons.receipt_long,
                            color: AppTheme.info,
                          ).animate().fade().slideY(begin: 0.1, delay: 50.ms),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Tax',
                            value: '₹${summary.taxTotal.toStringAsFixed(2)}',
                            icon: Icons.account_balance,
                            color: AppTheme.warning,
                          ).animate().fade().slideY(begin: 0.1, delay: 100.ms),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Discounts',
                            value:
                                '₹${summary.discountTotal.toStringAsFixed(2)}',
                            icon: Icons.local_offer,
                            color: AppTheme.accentBlue,
                          ).animate().fade().slideY(begin: 0.1, delay: 150.ms),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildChart(
                      context,
                      summary.totalSales,
                    ).animate().fade().scale(delay: 200.ms),
                  ],
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildDetailsSection(context, ref, salesState, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, double totalSales) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Trend (Mocked Data)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outlineVariant.withAlpha(30),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const style = TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          );
                          String text;
                          switch (value.toInt()) {
                            case 0:
                              text = 'Mon';
                              break;
                            case 2:
                              text = 'Wed';
                              break;
                            case 4:
                              text = 'Fri';
                              break;
                            case 6:
                              text = 'Sun';
                              break;
                            default:
                              return Container();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(text, style: style),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return Container();
                          return Text(
                            '${value.toInt()}k',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 3),
                        FlSpot(1, 2),
                        FlSpot(2, 5),
                        FlSpot(3, 3.1),
                        FlSpot(4, 4),
                        FlSpot(5, 3),
                        FlSpot(6, 4),
                      ],
                      isCurved: true,
                      color: AppTheme.salesColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.salesColor.withAlpha(30),
                      ),
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

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    dynamic salesState,
    ThemeData theme,
  ) {
    if (salesState.isLoading && salesState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (salesState.error != null && salesState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading details: ${salesState.error}'),
        ),
      );
    }

    if (salesState.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No data found for this date range.'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed Invoices', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(30),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Invoice #')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(
                    label: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: salesState.items.map<DataRow>((invoice) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('dd MMM yyyy')
                              .format(invoice.createdAt ?? DateTime.now()),
                        ),
                      ),
                      DataCell(Text(invoice.invoiceNumber)),
                      DataCell(
                        Text(invoice.customerSnapshot?.name ?? 'Walk-in'),
                      ),
                      DataCell(
                        Text(
                          '₹${invoice.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ).animate().fade().slideY(begin: 0.1, delay: 300.ms),
          ReportPaginationFooter(
            hasMore: salesState.hasMore,
            isLoadingMore: salesState.isLoadingMore,
            totalLoaded: salesState.items.length,
            onLoadMore: () => ref.read(reportSalesProvider.notifier).loadMore(),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        side: BorderSide(color: color.withOpacity(0.1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.cardColor, color.withOpacity(0.05)],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
