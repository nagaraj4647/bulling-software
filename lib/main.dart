import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/business/presentation/business_setup_page.dart';
import 'features/business/providers/business_provider.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/presentation/widgets/dashboard_home_view.dart';
import 'features/products/presentation/products_screen.dart';
import 'features/products/presentation/product_form_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/customers/presentation/customers_screen.dart';
import 'features/customers/presentation/customer_form_screen.dart';
import 'features/customers/presentation/customer_details_screen.dart';
import 'features/billing/presentation/billing_screen.dart';
import 'features/billing/presentation/new_invoice_screen.dart';
import 'features/billing/presentation/invoice_details_screen.dart';
import 'features/suppliers/presentation/suppliers_screen.dart';
import 'features/suppliers/presentation/supplier_form_screen.dart';
import 'features/suppliers/presentation/supplier_details_screen.dart';
import 'features/purchases/presentation/purchases_screen.dart';
import 'features/purchases/presentation/new_purchase_screen.dart';
import 'features/purchases/presentation/purchase_details_screen.dart';
import 'features/expenses/presentation/expenses_screen.dart';
import 'features/expenses/presentation/expense_form_screen.dart';
import 'features/expenses/presentation/expense_details_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: BillingApp()));
}

class AppRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  AppRouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(currentBusinessProvider, (_, _) => notifyListeners());
  }
}

final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final businessState = ref.read(currentBusinessProvider);

      // Never redirect away from splash — it self-navigates after animation
      if (state.matchedLocation == '/splash') {
        return null;
      }

      // If auth state is still loading, wait
      if (authState.isLoading || !authState.hasValue) {
        return null;
      }

      final user = authState.value;
      final isLoggedIn = user != null;

      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // 1. Not authenticated -> Go to login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 2. Authenticated
      if (isLoggedIn) {
        // If business state is loading, wait for it before redirecting
        if (businessState.isLoading) {
          return null;
        }

        final hasBusiness = businessState.value != null;
        final isSettingUpBusiness = state.matchedLocation == '/business-setup';

        // Prevent going back to login screens
        if (isLoggingIn) {
          return hasBusiness ? '/dashboard' : '/business-setup';
        }

        // Force business setup if no business exists and not currently setting one up
        if (!hasBusiness && !isSettingUpBusiness) {
          return '/business-setup';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/business-setup',
        builder: (context, state) => const BusinessSetupPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardHomeView(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const BillingScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const NewInvoiceScreen(),
              ),
              GoRoute(
                path: ':invoiceId',
                builder: (context, state) => InvoiceDetailsScreen(
                  invoiceId: state.pathParameters['invoiceId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: 'edit/:productId',
                builder: (context, state) => ProductFormScreen(
                  productId: state.pathParameters['productId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const CustomerFormScreen(),
              ),
              GoRoute(
                path: 'edit/:customerId',
                builder: (context, state) => CustomerFormScreen(
                  customerId: state.pathParameters['customerId'],
                ),
              ),
              GoRoute(
                path: ':customerId',
                builder: (context, state) => CustomerDetailsScreen(
                  customerId: state.pathParameters['customerId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const SupplierFormScreen(),
              ),
              GoRoute(
                path: 'edit/:supplierId',
                builder: (context, state) => SupplierFormScreen(
                  supplierId: state.pathParameters['supplierId'],
                ),
              ),
              GoRoute(
                path: ':supplierId',
                builder: (context, state) => SupplierDetailsScreen(
                  supplierId: state.pathParameters['supplierId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const NewPurchaseScreen(),
              ),
              GoRoute(
                path: ':purchaseId',
                builder: (context, state) => PurchaseDetailsScreen(
                  purchaseId: state.pathParameters['purchaseId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ExpenseFormScreen(),
              ),
              GoRoute(
                path: 'edit/:expenseId',
                builder: (context, state) => ExpenseFormScreen(
                  expenseId: state.pathParameters['expenseId'],
                ),
              ),
              GoRoute(
                path: ':expenseId',
                builder: (context, state) => ExpenseDetailsScreen(
                  expenseId: state.pathParameters['expenseId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class BillingApp extends ConsumerWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Multi Business Billing',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
