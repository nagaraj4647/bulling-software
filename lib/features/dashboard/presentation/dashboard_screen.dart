import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../business/providers/business_provider.dart';
import '../../business/models/business_model.dart';
import '../../products/providers/product_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isSeeding = false;

  Future<void> _seedSampleProducts(BusinessModel business) async {
    if (_isSeeding) return;
    _isSeeding = true;

    try {
      final added = await ref
          .read(productControllerProvider.notifier)
          .seedSampleProducts();

      final updatedBusiness = business.copyWith(sampleProductsSeeded: true);
      await ref
          .read(businessControllerProvider.notifier)
          .updateBusiness(updatedBusiness);

      if (mounted && added != null && added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample products ready. $added new products added.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to seed sample products: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/billing')) return 1;
    if (location.startsWith('/products')) return 2;
    if (location.startsWith('/reports')) return 3;
    // "More" items — highlight the More tab (index 4)
    if (location.startsWith('/inventory')) return 4;
    if (location.startsWith('/customers')) return 4;
    if (location.startsWith('/suppliers')) return 4;
    if (location.startsWith('/purchases')) return 4;
    if (location.startsWith('/expenses')) return 4;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  int _calculateRailIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/billing')) return 1;
    if (location.startsWith('/products')) return 2;
    if (location.startsWith('/inventory')) return 3;
    if (location.startsWith('/customers')) return 4;
    if (location.startsWith('/suppliers')) return 5;
    if (location.startsWith('/purchases')) return 6;
    if (location.startsWith('/expenses')) return 7;
    if (location.startsWith('/reports')) return 8;
    if (location.startsWith('/settings')) return 9;
    return 0;
  }

  void _onMobileTabTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/billing');
        break;
      case 2:
        context.go('/products');
        break;
      case 3:
        context.go('/reports');
        break;
      case 4:
        _showMoreMenu(context);
        break;
    }
  }

  void _onRailTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/billing');
        break;
      case 2:
        context.go('/products');
        break;
      case 3:
        context.go('/inventory');
        break;
      case 4:
        context.go('/customers');
        break;
      case 5:
        context.go('/suppliers');
        break;
      case 6:
        context.go('/purchases');
        break;
      case 7:
        context.go('/expenses');
        break;
      case 8:
        context.go('/reports');
        break;
      case 9:
        context.go('/settings');
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Text('More', style: theme.textTheme.titleLarge),
                    const Spacer(),
                  ],
                ),
              ),
              const Divider(height: 1),
              _MoreMenuItem(
                icon: Icons.warehouse_outlined,
                selectedIcon: Icons.warehouse,
                label: 'Inventory',
                isSelected: location.startsWith('/inventory'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/inventory');
                },
              ),
              _MoreMenuItem(
                icon: Icons.people_outlined,
                selectedIcon: Icons.people,
                label: 'Customers',
                isSelected: location.startsWith('/customers'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/customers');
                },
              ),
              _MoreMenuItem(
                icon: Icons.local_shipping_outlined,
                selectedIcon: Icons.local_shipping,
                label: 'Suppliers',
                isSelected: location.startsWith('/suppliers'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/suppliers');
                },
              ),
              _MoreMenuItem(
                icon: Icons.shopping_cart_outlined,
                selectedIcon: Icons.shopping_cart,
                label: 'Purchases',
                isSelected: location.startsWith('/purchases'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/purchases');
                },
              ),
              _MoreMenuItem(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
                label: 'Expenses',
                isSelected: location.startsWith('/expenses'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/expenses');
                },
              ),
              const Divider(height: 1),
              _MoreMenuItem(
                key: const ValueKey('nav_more_settings'),
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                isSelected: location.startsWith('/settings'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/settings');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<BusinessModel?>>(currentBusinessProvider, (
      previous,
      next,
    ) {
      final business = next.value;
      if (business != null && !business.sampleProductsSeeded) {
        _seedSampleProducts(business);
      }
    });

    final businessState = ref.watch(currentBusinessProvider);
    final businessName =
        businessState.value?.businessName ?? 'Multi Business Billing';

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return _buildDesktopLayout(context, businessName);
    } else {
      return _buildMobileLayout(context, businessName);
    }
  }

  Widget _buildMobileLayout(BuildContext context, String businessName) {
    final selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(businessName),
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontSize: 18,
        ),
      ),
      body: Stack(
        children: [
          widget.child,
          if (_isSeeding)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex > 4 ? 4 : selectedIndex,
        onDestinationSelected: (index) => _onMobileTabTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, key: ValueKey('nav_home')),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined, key: ValueKey('nav_billing')),
            selectedIcon: Icon(Icons.receipt),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
              key: ValueKey('nav_products'),
            ),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, key: ValueKey('nav_reports')),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz, key: ValueKey('nav_more')),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, String businessName) {
    final selectedIndex = _calculateRailIndex(context);
    final theme = Theme.of(context);
    final isWideDesktop = MediaQuery.of(context).size.width >= 960;
    final isDark = theme.brightness == Brightness.dark;

    final navItems = [
      _DesktopNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Home',
        index: 0,
        key: const ValueKey('nav_home'),
        section: 'CORE',
      ),
      _DesktopNavItem(
        icon: Icons.receipt_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Billing',
        index: 1,
        key: const ValueKey('nav_billing'),
      ),
      _DesktopNavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: 'Products',
        index: 2,
        key: const ValueKey('nav_products'),
      ),
      _DesktopNavItem(
        icon: Icons.warehouse_outlined,
        selectedIcon: Icons.warehouse_rounded,
        label: 'Inventory',
        index: 3,
      ),
      _DesktopNavItem(
        icon: Icons.people_outlined,
        selectedIcon: Icons.people_alt_rounded,
        label: 'Customers',
        index: 4,
        section: 'MANAGEMENT',
      ),
      _DesktopNavItem(
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        label: 'Suppliers',
        index: 5,
      ),
      _DesktopNavItem(
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart_rounded,
        label: 'Purchases',
        index: 6,
      ),
      _DesktopNavItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: 'Expenses',
        index: 7,
      ),
      _DesktopNavItem(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.analytics_rounded,
        label: 'Reports',
        index: 8,
        key: const ValueKey('nav_reports'),
        section: 'INSIGHTS',
      ),
      _DesktopNavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
        index: 9,
        key: const ValueKey('nav_more_settings'),
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sleek Sidebar
          Container(
            width: isWideDesktop ? 240 : 76,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Container(
                  height: 68,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideDesktop ? 18 : 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      if (isWideDesktop) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active Store',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    children: [
                      for (final item in navItems) ...[
                        if (isWideDesktop && item.section != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                            child: Text(
                              item.section!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        _DesktopNavTile(
                          item: item,
                          isSelected: selectedIndex == item.index,
                          isCollapsed: !isWideDesktop,
                          onTap: () => _onRailTapped(item.index, context),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom Sidebar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: isWideDesktop
                      ? Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                businessName.isNotEmpty
                                    ? businessName[0].toUpperCase()
                                    : 'B',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pro Plan',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                size: 18,
                              ),
                              tooltip: 'Toggle Theme',
                              onPressed: () {
                                final notifier = ref.read(
                                  themeModeProvider.notifier,
                                );
                                notifier.setThemeMode(
                                  isDark ? ThemeMode.light : ThemeMode.dark,
                                );
                              },
                            ),
                          ],
                        )
                      : Center(
                          child: IconButton(
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 20,
                            ),
                            tooltip: 'Toggle Theme',
                            onPressed: () {
                              final notifier = ref.read(
                                themeModeProvider.notifier,
                              );
                              notifier.setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Modern Desktop Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Breadcrumb
                      Icon(
                        Icons.space_dashboard_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getSectionTitle(selectedIndex),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),

                      // Date Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formattedDate(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Quick Action: + New Invoice
                      FilledButton.icon(
                        key: const ValueKey('desktop_new_invoice_btn'),
                        onPressed: () => context.go('/billing/new'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Invoice'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Stack(
                    children: [
                      widget.child,
                      if (_isSeeding)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionTitle(int index) {
    switch (index) {
      case 0:
        return 'Overview';
      case 1:
        return 'Billing & POS';
      case 2:
        return 'Product Catalog';
      case 3:
        return 'Inventory Stock';
      case 4:
        return 'Customers';
      case 5:
        return 'Suppliers';
      case 6:
        return 'Purchases';
      case 7:
        return 'Expenses';
      case 8:
        return 'Analytics & Reports';
      case 9:
        return 'Store Settings';
      default:
        return 'Dashboard';
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

/// A menu item for the "More" bottom sheet.
class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoreMenuItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

class _DesktopNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final Key? key;
  final String? section;

  const _DesktopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    this.key,
    this.section,
  });
}

class _DesktopNavTile extends StatefulWidget {
  final _DesktopNavItem item;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _DesktopNavTile({
    required this.item,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_DesktopNavTile> createState() => _DesktopNavTileState();
}

class _DesktopNavTileState extends State<_DesktopNavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryBlue = const Color(0xFF2563EB);
    final activeBg = isDark
        ? primaryBlue.withOpacity(0.2)
        : const Color(0xFFEFF6FF);
    final hoverBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    final activeColor = primaryBlue;
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final currentColor = widget.isSelected ? activeColor : inactiveColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          key: widget.item.key,
          color: widget.isSelected
              ? activeBg
              : (_isHovered ? hoverBg : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: widget.isCollapsed
                ? Tooltip(
                    message: widget.item.label,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        widget.isSelected
                            ? widget.item.selectedIcon
                            : widget.item.icon,
                        color: currentColor,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          widget.isSelected
                              ? widget.item.selectedIcon
                              : widget.item.icon,
                          color: currentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: widget.isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: currentColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

