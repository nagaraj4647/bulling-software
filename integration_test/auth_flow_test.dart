import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Test', () {
    setUpAll(() {
      // Ignore Google Fonts network errors on the emulator
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception.toString().contains('google_fonts') ||
            details.exception.toString().contains('fonts.gstatic.com')) {
          return;
        }
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (error.toString().contains('google_fonts') ||
            error.toString().contains('fonts.gstatic.com')) {
          return true;
        }
        return false;
      };
    });

    late StreamController<User?> authStream;

    setUp(() {
      // Use a single-subscription StreamController so the initial null event
      // is buffered and delivered when the StreamProvider subscribes.
      // This ensures authStateProvider starts as AsyncData(null) = logged out.
      authStream = StreamController<User?>();
      // Seed with null so the splash screen sees "logged out".
      authStream.add(null);
    });

    tearDown(() {
      authStream.close();
    });

    // ─── Helper: wait through the entire splash animation ────────────────────
    Future<void> waitThroughSplash(WidgetTester tester) async {
      // 1. Past the 200 ms initial delay; start of logo animation
      await Future.delayed(const Duration(milliseconds: 300));
      // Settle the 800 ms logo entrance animation
      await tester.pumpAndSettle();

      // 2. Past the 600 ms "hold" delay
      await Future.delayed(const Duration(milliseconds: 700));
      // Settle the 400 ms fade-out + GoRouter navigation
      await tester.pumpAndSettle();
    }

    // ─── A. App startup → Login screen ───────────────────────────────────────
    testWidgets('A. Splash screen leads to Login when unauthenticated', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthTestApp(authStream));

      // Verify splash text is initially visible.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Multi Business Billing'), findsOneWidget);

      await waitThroughSplash(tester);

      // After splash, unauthenticated → Login screen
      expect(find.text('Welcome back'), findsOneWidget);
    });

    // ─── B. Login UI elements ─────────────────────────────────────────────────
    testWidgets('B. Login screen has all required UI elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthTestApp(authStream));
      await waitThroughSplash(tester);

      // Title / header
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to manage your business'), findsOneWidget);

      // Email field
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);

      // Password field
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

      // Login button
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);

      // Register navigation link
      expect(find.widgetWithText(TextButton, 'Create Account'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
    });

    // ─── C. Login form validation ─────────────────────────────────────────────
    testWidgets(
      'C. Login form shows validation errors for empty/invalid input',
      (WidgetTester tester) async {
        await tester.pumpWidget(createAuthTestApp(authStream));
        await waitThroughSplash(tester);

        // --- C1: Empty fields ---
        // Tap login with nothing entered
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);
        expect(find.text('Please enter your password'), findsOneWidget);

        // --- C2: Invalid email ---
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'notanemail',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email'), findsOneWidget);

        // --- C3: Valid email format + password → validation passes ---
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'test@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );

        // Email error should no longer be shown once valid
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
        await tester.pump(); // pump once to see loading state
        expect(find.text('Please enter a valid email'), findsNothing);
        expect(find.text('Please enter your email'), findsNothing);
        expect(find.text('Please enter your password'), findsNothing);

        // Settle the mock login (100ms delay + navigation)
        await tester.pumpAndSettle();
      },
    );

    // ─── D. Register screen navigation ───────────────────────────────────────
    testWidgets('D. Navigate to Register screen and back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthTestApp(authStream));
      await waitThroughSplash(tester);

      // Tap the "Create Account" link on the Login screen
      await tester.tap(find.widgetWithText(TextButton, 'Create Account'));
      await tester.pumpAndSettle();

      // --- D1: Register screen visible ---
      expect(
        find.text('Create Account'),
        findsWidgets,
      ); // heading + button text
      expect(
        find.text('Set up your billing account to get started'),
        findsOneWidget,
      );

      // --- D2: All fields exist ---
      expect(
        find.widgetWithText(TextFormField, 'Business Owner Name'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        findsOneWidget,
      );

      // --- D3: Back to Login via Sign In TextButton ---
      await tester.tap(find.widgetWithText(TextButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    // ─── E. Successful mocked login → Dashboard ───────────────────────────────
    testWidgets('E. Successful login navigates to Dashboard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthTestApp(authStream));
      await waitThroughSplash(tester);

      // Verify we are on Login
      expect(find.text('Welcome back'), findsOneWidget);

      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Tap Sign In
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));

      // Allow the mock login (100 ms) + GoRouter redirect to settle
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Dashboard should now be visible
      expect(find.text('Home').last, findsOneWidget);
      expect(find.text('Test Business'), findsWidgets);

      // Login screen is gone
      expect(find.text('Welcome back'), findsNothing);
    });

    // ─── F. Logout → Login ────────────────────────────────────────────────────
    testWidgets('F. Logout from Dashboard returns to Login screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthTestApp(authStream));
      await waitThroughSplash(tester);

      // Login first
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Confirm we are on Dashboard
      expect(find.text('Home').last, findsOneWidget);

      // Navigate to Settings via the "More" tab
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();

      // Tap the "Log Out of Account" button to open the confirmation dialog
      final logoutButton = find.text('Log Out of Account');
      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Confirm the dialog appears
      expect(find.text('Confirm Logout'), findsOneWidget);

      // Tap the "Logout" confirm button inside the dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();

      // Allow mock logout (100 ms) + GoRouter redirect to settle
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Should be back on Login
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
