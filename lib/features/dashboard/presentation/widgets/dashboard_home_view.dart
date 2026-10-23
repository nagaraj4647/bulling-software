import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/chart_format.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../products/providers/product_provider.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../../billing/providers/billing_provider.dart';
import '../../../purchases/providers/purchase_provider.dart';
import '../../../expenses/providers/expense_provider.dart';
import '../../../business/providers/business_provider.dart';
import '../../../reports/models/report_models.dart';
import '../../../reports/providers/reports_provider.dart';

class DashboardHomeView extends ConsumerWidget {
  const DashboardHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessState = ref.watch(currentBusinessProvider);
    final businessName = businessState.value?.businessName ?? 'Your Business';
    final theme = Theme.of(context);

    // Greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $businessName 👋',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fade(duration: 350.ms).slideY(begin: 0.08, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      "Here's your live store overview and financial performance for today.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ).animate().fade(duration: 350.ms, delay: 50.ms).slideY(begin: 0.08, end: 0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Cards
          _buildSummaryCards(context, ref)
              .animate()
              .fade(duration: 450.ms, delay: 150.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 28),

          // Quick Actions
          _buildQuickActions(context)
              .animate()
              .fade(duration: 450.ms, delay: 250.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 28),

          // Sales Chart (real confirmed sales, trailing 7 days)
          const _SalesChart()
              .animate()
              .fade(duration: 450.ms, delay: 300.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 28),

          // Recent Invoices & Low Stock
          LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 860) {
                    // Tablet/Desktop row
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildRecentInvoices(context, ref),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: _buildLowStockProducts(context, ref),
                        ),
                      ],
                    );
                  }
                  // Mobile column
                  return Column(
                    children: [
                      _buildRecentInvoices(context, ref),
                      const SizedBox(height: 20),
                      _buildLowStockProducts(context, ref),
                    ],
                  );
                },
              )
              .animate()
              .fade(duration: 450.ms, delay: 350.ms)
              .slideY(begin: 0.04, end: 0),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final totalProducts =
        productsState.value?.where((p) => p.isActive).length.toString() ??
        '0';

    final customersState = ref.watch(customersProvider);
    final totalCustomers =
        customersState.value?.where((c) => c.isActive).length.toString() ??
        '0';

    final todaySalesAsync = ref.watch(todaySalesProvider);
    final todayPurchasesAsync = ref.watch(todayPurchasesProvider);
    final todayExpensesAsync = ref.watch(todayExpensesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 1.35;

        if (constraints.maxWidth > 1150) {
          crossAxisCount = 3;
          childAspectRatio = 1.85;
        } else if (constraints.maxWidth > 720) {
          crossAxisCount = 3;
          childAspectRatio = 1.6;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 1.3;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: childAspectRatio,
          children: [
            _MetricCard(
              title: "TODAY'S SALES",
              asyncValue: todaySalesAsync,
              icon: Icons.trending_up_rounded,
              accentColor: AppTheme.salesColor,
              subtitle: "Confirmed revenue",
            ),
            _MetricCard(
              title: "TODAY'S PURCHASES",
              asyncValue: todayPurchasesAsync,
              icon: Icons.shopping_bag_outlined,
              accentColor: AppTheme.purchasesColor,
              subtitle: "Inbound stock",
            ),
            _MetricCard(
              title: "TODAY'S EXPENSES",
              asyncValue: todayExpensesAsync,
              icon: Icons.receipt_long_outlined,
              accentColor: AppTheme.expensesColor,
              subtitle: "Operating costs",
            ),
            _ProfitCard(
              sales: todaySalesAsync,
              purchases: todayPurchasesAsync,
              expenses: todayExpensesAsync,
            ),
            _CountCard(
              title: 'CUSTOMERS',
              value: totalCustomers,
              icon: Icons.people_alt_outlined,
              accentColor: const Color(0xFF0284C7),
              subtitle: "Active accounts",
            ),
            _CountCard(
              title: 'PRODUCTS',
              value: totalProducts,
              icon: Icons.inventory_2_outlined,
              accentColor: AppTheme.stockColor,
              subtitle: "Catalog items",
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionChip(
              key: const ValueKey('add_invoice_btn'),
              label: 'New Invoice',
              icon: Icons.add_circle_outline,
              isPrimary: true,
              onTap: () => context.go('/billing/new'),
            ),
            _QuickActionChip(
              key: const ValueKey('add_product_btn'),
              label: 'Add Product',
              icon: Icons.add_box_outlined,
              onTap: () => context.go('/products/add'),
            ),
            _QuickActionChip(
              key: const ValueKey('add_customer_btn'),
              label: 'Add Customer',
              icon: Icons.person_add_outlined,
              onTap: () => context.go('/customers/add'),
            ),
            _QuickActionChip(
              key: const ValueKey('add_supplier_btn'),
              label: 'Add Supplier',
              icon: Icons.store_outlined,
              onTap: () => context.go('/suppliers/add'),
            ),
            _QuickActionChip(
              key: const ValueKey('add_purchase_btn'),
              label: 'New Purchase',
              icon: Icons.shopping_basket_outlined,
              onTap: () => context.go('/purchases/new'),
            ),
            _QuickActionChip(
              key: const ValueKey('add_expense_btn'),
              label: 'Add Expense',
              icon: Icons.receipt_long_outlined,
              onTap: () => context.go('/expenses/new'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentInvoices(BuildContext context, WidgetRef ref) {
    final asyncInvoices = ref.watch(recentInvoicesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Invoices', style: theme.textTheme.titleMedium),
              TextButton(
                onPressed: () => context.go('/billing'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          asyncInvoices.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, stack) => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Failed to load invoices')),
            ),
            data: (invoices) {
              if (invoices.isEmpty) {
                return AppEmptyState(
                  icon: Icons.receipt_outlined,
                  title: 'No invoices yet',
                  subtitle: 'Create your first invoice to start billing',
                  actionLabel: 'Create Invoice',
                  onAction: () => context.go('/billing/new'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.receipt,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      invoice.customerSnapshot?.name ?? 'Walk-in Customer',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      invoice.invoiceNumber.isNotEmpty
                          ? invoice.invoiceNumber
                          : 'Draft',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    trailing: Text(
                      'Rs.${invoice.grandTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => context.go('/billing/\${invoice.invoiceId}'),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockProducts(BuildContext context, WidgetRef ref) {
    final asyncProducts = ref.watch(lowStockProductsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Text('Low Stock Alerts', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          asyncProducts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, stack) => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Failed to load products')),
            ),
            data: (products) {
              if (products.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All products are well stocked',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

// ── Private Widget Components ──────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String title;
  final AsyncValue<double> asyncValue;
  final IconData icon;
  final Color accentColor;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.asyncValue,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Label & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
            ],
          ),

          // Value
          asyncValue.when(
            data: (val) => Text(
              '₹${val.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            loading: () => Text(
              '₹0.00',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: const Color(0xFF94A3B8),
              ),
            ),
            error: (_, _) => Text(
              '₹0.00',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),

          // Subtitle
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  final AsyncValue<double> sales;
  final AsyncValue<double> purchases;
  final AsyncValue<double> expenses;

  const _ProfitCard({
    required this.sales,
    required this.purchases,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppTheme.profitColor;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final sVal = sales.value ?? 0.0;
    final pVal = purchases.value ?? 0.0;
    final eVal = expenses.value ?? 0.0;
    final netProfit = sVal - pVal - eVal;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY'S PROFIT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: accentColor,
                  size: 17,
                ),
              ),
            ],
          ),
          Text(
            '₹${netProfit.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
              color: netProfit >= 0
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : AppTheme.error,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                netProfit >= 0 ? "Positive margin" : "Deficit today",
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String subtitle;

  const _CountCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: widget.isPrimary
            ? FilledButton.icon(
                onPressed: widget.onTap,
                icon: Icon(widget.icon, size: 18),
                label: Text(widget.label),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: _isHovered ? 4 : 0,
                  shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: widget.onTap,
                icon: Icon(
                  widget.icon,
                  size: 18,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                ),
                label: Text(widget.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E293B),
                  backgroundColor: _isHovered
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9))
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white),
                  side: BorderSide(
                    color: _isHovered
                        ? const Color(0xFF2563EB)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SalesChart extends ConsumerWidget {
  const _SalesChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trendAsync = ref.watch(dashboardWeeklySalesTrendProvider);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Performance Trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: trendAsync.when(
              data: (points) => _buildTrend(context, points),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Could not load sales trend',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Real confirmed-sales trend for the trailing 7 days, bucketed per local
  /// calendar day by ReportsService.getDailySalesTrend.
  Widget _buildTrend(BuildContext context, List<DailySalesPoint> points) {
    final theme = Theme.of(context);
    if (points.isEmpty || points.every((p) => p.total == 0)) {
      return Center(
        child: Text(
          'No sales in the last 7 days',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    }
    var maxTotal = 0.0;
    for (final p in points) {
      if (p.total > maxTotal) maxTotal = p.total;
    }
    final maxY = niceCeil(maxTotal);
    final dayFormat = DateFormat('EEE');
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              strokeWidth: 1,
              dashArray: [5, 5],
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
                const style = TextStyle(fontSize: 12, color: Colors.grey);
                final i = value.toInt();
                if (value != i.toDouble() || i < 0 || i >= points.length) {
                  return const SizedBox();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(dayFormat.format(points[i].day), style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 4,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  compactAmount(value),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).clamp(1, double.infinity).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].total),
            ],
            isCurved: true,
            color: AppTheme.accentBlue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accentBlue.withOpacity(0.15),
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentBlue.withOpacity(0.3),
                  AppTheme.accentBlue.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
