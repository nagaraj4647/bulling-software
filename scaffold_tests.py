import os

base_dir = "integration_test"
helpers_dir = os.path.join(base_dir, "helpers")

os.makedirs(helpers_dir, exist_ok=True)

mock_providers_content = """import 'package:flutter_riverpod/flutter_riverpod.dart';
// TODO: import your app's providers and mock them
// import 'package:billing_app/features/auth/providers/auth_provider.dart';

final List<Override> mockProviders = [
  // TODO: Add mock overrides
];
"""

test_app_content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing_app/main.dart'; // adjust as needed
import 'mock_providers.dart';

Widget createTestApp() {
  return ProviderScope(
    overrides: mockProviders,
    child: const BillingApp(),
  );
}
"""

tests = [
    "auth_flow_test.dart",
    "dashboard_flow_test.dart",
    "billing_flow_test.dart",
    "inventory_flow_test.dart",
    "crm_flow_test.dart",
    "finance_flow_test.dart",
    "reports_settings_test.dart"
]

test_template = """import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test {name}', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    
    // TODO: Write test flow
    expect(true, true);
  });
}
"""

with open(os.path.join(helpers_dir, "mock_providers.dart"), "w") as f:
    f.write(mock_providers_content)

with open(os.path.join(helpers_dir, "test_app.dart"), "w") as f:
    f.write(test_app_content)

for test in tests:
    test_name = test.replace(".dart", "").replace("_", " ").title()
    with open(os.path.join(base_dir, test), "w") as f:
        f.write(test_template.replace("{name}", test_name))

print("Scaffolded tests successfully.")
