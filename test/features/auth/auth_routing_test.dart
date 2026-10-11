import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/business/models/business_model.dart';

void main() {
  group('Auth & Navigation Guard Pure Logic Tests', () {
    String? computeRedirect({
      required bool authLoading,
      required bool hasAuthUser,
      required bool businessLoading,
      required BusinessModel? business,
      required String matchedLocation,
    }) {
      if (authLoading) return null;

      final isLoggedIn = hasAuthUser;
      final isLoggingIn =
          matchedLocation == '/login' || matchedLocation == '/register';

      // 1. Not authenticated -> Go to login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 2. Authenticated
      if (isLoggedIn) {
        if (businessLoading) return null;

        final hasBusiness = business != null;
        final isSettingUpBusiness = matchedLocation == '/business-setup';

        if (isLoggingIn) {
          return hasBusiness ? '/dashboard' : '/business-setup';
        }

        if (!hasBusiness && !isSettingUpBusiness) {
          return '/business-setup';
        }
      }

      return null;
    }

    test('Unauthenticated user attempting to access dashboard is redirected to /login', () {
      final redirect = computeRedirect(
        authLoading: false,
        hasAuthUser: false,
        businessLoading: false,
        business: null,
        matchedLocation: '/dashboard',
      );

      expect(redirect, '/login');
    });

    test('Unauthenticated user on /login stays on /login', () {
      final redirect = computeRedirect(
        authLoading: false,
        hasAuthUser: false,
        businessLoading: false,
        business: null,
        matchedLocation: '/login',
      );

      expect(redirect, isNull);
    });

    test('Unauthenticated user on /register stays on /register', () {
      final redirect = computeRedirect(
        authLoading: false,
        hasAuthUser: false,
        businessLoading: false,
        business: null,
        matchedLocation: '/register',
      );

      expect(redirect, isNull);
    });

    test(
      'Authenticated user with no business is redirected to /business-setup',
      () {
        final redirect = computeRedirect(
          authLoading: false,
          hasAuthUser: true,
          businessLoading: false,
          business: null,
          matchedLocation: '/dashboard',
        );

        expect(redirect, '/business-setup');
      },
    );

    test('Authenticated user with no business on /login is redirected to /business-setup', () {
      final redirect = computeRedirect(
        authLoading: false,
        hasAuthUser: true,
        businessLoading: false,
        business: null,
        matchedLocation: '/login',
      );

      expect(redirect, '/business-setup');
    });

    test(
      'Authenticated user with business on /login is redirected to /dashboard',
      () {
        final testBusiness = BusinessModel(
          businessId: 'biz-001',
          ownerId: 'usr-001',
          businessName: 'My Store',
          businessType: 'Retail',
          ownerName: 'Owner',
          phone: '9876543210',
          email: 'store@test.com',
          address: '123 Test St',
        );

        final redirect = computeRedirect(
          authLoading: false,
          hasAuthUser: true,
          businessLoading: false,
          business: testBusiness,
          matchedLocation: '/login',
        );

        expect(redirect, '/dashboard');
      },
    );

    test(
      'Authenticated user with business on /dashboard stays on /dashboard',
      () {
        final testBusiness = BusinessModel(
          businessId: 'biz-001',
          ownerId: 'usr-001',
          businessName: 'My Store',
          businessType: 'Retail',
          ownerName: 'Owner',
          phone: '9876543210',
          email: 'store@test.com',
          address: '123 Test St',
        );

        final redirect = computeRedirect(
          authLoading: false,
          hasAuthUser: true,
          businessLoading: false,
          business: testBusiness,
          matchedLocation: '/dashboard',
        );

        expect(redirect, isNull);
      },
    );

    test('Waits while auth or business state is loading', () {
      final authLoadingRedirect = computeRedirect(
        authLoading: true,
        hasAuthUser: false,
        businessLoading: false,
        business: null,
        matchedLocation: '/dashboard',
      );
      expect(authLoadingRedirect, isNull);

      final bizLoadingRedirect = computeRedirect(
        authLoading: false,
        hasAuthUser: true,
        businessLoading: true,
        business: null,
        matchedLocation: '/dashboard',
      );
      expect(bizLoadingRedirect, isNull);
    });
  });
}
