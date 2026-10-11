import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billing_app/core/theme/theme_mode_provider.dart';
import 'package:billing_app/features/business/models/business_model.dart';
import 'package:billing_app/features/business/providers/business_provider.dart';
import 'package:billing_app/features/settings/presentation/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessModel Settings & Immutability Tests', () {
    test('copyWith updates mutable profile fields while preserving immutable fields', () {
      final initialDate = DateTime(2026, 1, 15, 10, 30);
      final business = BusinessModel(
        businessId: 'biz-123',
        ownerId: 'owner-456',
        businessName: 'Original Store',
        businessType: 'Retail Shop',
        ownerName: 'John Doe',
        phone: '9876543210',
        email: 'store@example.com',
        address: '123 Main St',
        businessState: 'Tamil Nadu',
        gstNumber: '33AAAAA0000A1Z5',
        isGstInclusive: false,
        createdAt: initialDate,
      );

      final updated = business.copyWith(
        businessName: 'Updated Superstore',
        businessType: 'Supermarket',
        ownerName: 'Jane Doe',
        phone: '9123456780',
        email: 'newstore@example.com',
        address: '456 New Road',
        businessState: 'Karnataka',
        gstNumber: '29BBBBB1111B2Z6',
        isGstInclusive: true,
      );

      // Verify mutable fields updated
      expect(updated.businessName, 'Updated Superstore');
      expect(updated.businessType, 'Supermarket');
      expect(updated.ownerName, 'Jane Doe');
      expect(updated.phone, '9123456780');
      expect(updated.email, 'newstore@example.com');
      expect(updated.address, '456 New Road');
      expect(updated.businessState, 'Karnataka');
      expect(updated.gstNumber, '29BBBBB1111B2Z6');
      expect(updated.isGstInclusive, isTrue);

      // Verify immutable fields preserved
      expect(updated.businessId, 'biz-123');
      expect(updated.ownerId, 'owner-456');
      expect(updated.createdAt, initialDate);
    });
  });

  group('GSTIN Validation & Normalization Tests', () {
    final gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    );

    test('validates standard 15-character GSTIN format', () {
      expect(gstRegex.hasMatch('29AAAAA0000A1Z5'), isTrue);
      expect(gstRegex.hasMatch('33ABCDE1234F1Z5'), isTrue);
      expect(gstRegex.hasMatch('07AAAAA0000A1Z5'), isTrue);
    });

    test('rejects invalid GSTIN formats', () {
      expect(gstRegex.hasMatch('12345'), isFalse);
      expect(gstRegex.hasMatch('29AAAAA0000A1Z'), isFalse); // 14 chars
      expect(gstRegex.hasMatch('29AAAAA0000A1Z5A'), isFalse); // 16 chars
      expect(
        gstRegex.hasMatch('ABCDE1234F1Z500'),
        isFalse,
      ); // missing state code
      expect(
        gstRegex.hasMatch('29aaaaa0000a1z5'),
        isFalse,
      ); // lowercase before normalization
    });

    test('GSTIN normalization converts to uppercase and trims correctly', () {
      const input = '  29aaaaa0000a1z5  ';
      final normalized = input.trim().toUpperCase();
      expect(normalized, '29AAAAA0000A1Z5');
      expect(gstRegex.hasMatch(normalized), isTrue);
    });
  });

  group('Form Validation Rules Tests', () {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^[0-9]{10}$');

    test('validates phone numbers (10 numeric digits)', () {
      expect(phoneRegex.hasMatch('9876543210'), isTrue);
      expect(phoneRegex.hasMatch('987654321'), isFalse); // 9 digits
      expect(phoneRegex.hasMatch('98765432101'), isFalse); // 11 digits
      expect(phoneRegex.hasMatch('98765abcde'), isFalse); // letters
    });

    test('validates email format', () {
      expect(emailRegex.hasMatch('contact@business.com'), isTrue);
      expect(emailRegex.hasMatch('user.name@sub.domain.co'), isTrue);
      expect(emailRegex.hasMatch('invalid-email'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
    });
  });

  group('ThemeMode Persistence & Switching Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'ThemeModeNotifier defaults to system theme and persists light/dark',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(themeModeProvider), ThemeMode.system);

        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        expect(container.read(themeModeProvider), ThemeMode.dark);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_theme_mode'), 'dark');

        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.light);
        expect(container.read(themeModeProvider), ThemeMode.light);
        expect(prefs.getString('app_theme_mode'), 'light');

        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.system);
        expect(container.read(themeModeProvider), ThemeMode.system);
        expect(prefs.getString('app_theme_mode'), 'system');
      },
    );
  });

  group('SettingsScreen Widget Tests', () {
    final testBusiness = BusinessModel(
      businessId: 'biz-test-123',
      ownerId: 'owner-test-456',
      businessName: 'My Awesome Store',
      businessType: 'Retail Shop',
      ownerName: 'Alice Owner',
      phone: '9876543210',
      email: 'alice@store.com',
      address: '789 Market Street',
      businessState: 'Maharashtra',
      gstNumber: '27ABCDE1234F1Z5',
      isGstInclusive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets(
      'renders all business settings fields and opens logout confirmation dialog',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentBusinessProvider.overrideWith(
                (ref) => Future.value(testBusiness),
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify business profile fields are pre-populated
        expect(find.text('My Awesome Store'), findsOneWidget);
        expect(find.text('Alice Owner'), findsOneWidget);
        expect(find.text('9876543210'), findsOneWidget);
        expect(find.text('alice@store.com'), findsOneWidget);
        expect(find.text('789 Market Street'), findsOneWidget);
        expect(find.text('27ABCDE1234F1Z5'), findsOneWidget);

        // Verify sections are visible
        expect(find.text('Business Profile'), findsOneWidget);
        expect(find.text('Tax & GST Configuration'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Account Information'), findsOneWidget);

        // Verify Logout confirmation dialog
        final logoutButton = find.text('Log Out of Account');
        expect(logoutButton, findsOneWidget);

        await tester.ensureVisible(logoutButton);
        await tester.tap(logoutButton);
        await tester.pumpAndSettle();

        expect(find.text('Confirm Logout'), findsOneWidget);
        expect(
          find.text('Are you sure you want to log out of your account?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);

        // Tap cancel to close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Confirm Logout'), findsNothing);
      },
    );
  });
}
