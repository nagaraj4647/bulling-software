import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/reports_provider.dart';
import 'widgets/sales_report_view.dart';
import 'widgets/purchase_report_view.dart';
import 'widgets/expense_report_view.dart';
import 'widgets/profit_report_view.dart';
import 'widgets/product_stock_report_view.dart';
import 'widgets/customer_outstanding_report_view.dart';
import 'widgets/supplier_outstanding_report_view.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportType = ref.watch(reportTypeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: Column(
        children: [
          _buildHeader(
            context,
            ref,
            reportType,
            theme,
          ).animate().fade().slideY(begin: -0.1),
          const Divider(height: 1),
          Expanded(child: _buildReportView(reportType)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ReportType currentType,
    ThemeData theme,
  ) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final showDatePicker =
        currentType == ReportType.sales ||
        currentType == ReportType.purchase ||
        currentType == ReportType.expense ||
        currentType == ReportType.profit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ReportType>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50),
                  ),
                ),
                segments: ReportType.values.map((type) {
                  return ButtonSegment<ReportType>(
                    value: type,
                    label: Text(
                      type.displayName,
                      style: theme.textTheme.labelMedium,
                    ),
                  );
                }).toList(),
                selected: {currentType},
                onSelectionChanged: (Set<ReportType> newSelection) {
                  ref
                      .read(reportTypeProvider.notifier)
                      .setType(newSelection.first);
                },
              ),
            ),
          ),
          if (showDatePicker)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 20),
                label: Text(
                  '${DateFormat('dd MMM').format(dateRange.start)} - ${DateFormat('dd MMM').format(dateRange.end.subtract(const Duration(days: 1)))}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: DateTimeRange(
                      start: dateRange.start,
                      end: dateRange.end.subtract(const Duration(days: 1)),
                    ),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context)
                            .copyWith(colorScheme: theme.colorScheme),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref
                        .read(reportDateRangeProvider.notifier)
                        .setDateRange(
                          DateRangeState(
                            picked.start,
                            DateTime(
                              picked.end.year,
                              picked.end.month,
                              picked.end.day,
                            ).add(const Duration(days: 1)),
                          ),
                        );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportView(ReportType type) {
    switch (type) {
      case ReportType.sales:
        return const SalesReportView();
      case ReportType.purchase:
        return const PurchaseReportView();
      case ReportType.expense:
        return const ExpenseReportView();
      case ReportType.profit:
        return const ProfitReportView();
      case ReportType.stock:
        return const ProductStockReportView();
      case ReportType.customer:
        return const CustomerOutstandingReportView();
      case ReportType.supplier:
        return const SupplierOutstandingReportView();
    }
  }
}
