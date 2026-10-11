import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing_app/main.dart'; // adjust as needed

import 'mock_providers.dart';

Widget createTestApp() {
  return ProviderScope(overrides: mockProviders, child: const BillingApp());
}

/// Creates a test app for the auth flow test.
/// The [authStream] controls the authentication state (start with null = logged out,
/// add FakeUser() to simulate login, add null to simulate logout).
Widget createAuthTestApp(StreamController<User?> authStream) {
  return ProviderScope(
    overrides: [...createAuthTestProviders(authStream)],
    child: const BillingApp(),
  );
}
