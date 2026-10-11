import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/billing/data/billing_calculator.dart';

void main() {
  group('BillingCalculator Unit Tests', () {
    test('round2 correctly rounds to 2 decimal places', () {
      expect(BillingCalculator.round2(10.556), 10.56);
      expect(BillingCalculator.round2(10.554), 10.55);
      expect(BillingCalculator.round2(10.0), 10.0);
      expect(BillingCalculator.round2(0.001), 0.0);
    });

    test(
      'calculateItemSubtotal multiplies quantity and unit price with rounding',
      () {
        expect(BillingCalculator.calculateItemSubtotal(3, 99.99), 299.97);
        expect(BillingCalculator.calculateItemSubtotal(2.5, 40.0), 100.0);
        expect(BillingCalculator.calculateItemSubtotal(0, 100.0), 0.0);
      },
    );

    test('calculateItemTaxableValue subtracts discount from subtotal', () {
      expect(BillingCalculator.calculateItemTaxableValue(1000.0, 100.0), 900.0);
      expect(BillingCalculator.calculateItemTaxableValue(500.0, 0.0), 500.0);
      expect(
        BillingCalculator.calculateItemTaxableValue(250.75, 50.25),
        200.50,
      );
    });

    test(
      'calculateGstAmount calculates tax based on rate and taxable value',
      () {
        expect(BillingCalculator.calculateGstAmount(1000.0, 18.0), 180.0);
        expect(BillingCalculator.calculateGstAmount(1000.0, 5.0), 50.0);
        expect(BillingCalculator.calculateGstAmount(1000.0, 12.0), 120.0);
        expect(BillingCalculator.calculateGstAmount(1000.0, 28.0), 280.0);
        expect(BillingCalculator.calculateGstAmount(1000.0, 0.0), 0.0);
      },
    );

    test(
      'calculateTaxableValueFromInclusiveTotal extracts base price correctly',
      () {
        // For inclusive ₹118 with 18% GST -> base is ₹100
        expect(
          BillingCalculator.calculateTaxableValueFromInclusiveTotal(
            118.0,
            18.0,
          ),
          100.0,
        );
        // For inclusive ₹105 with 5% GST -> base is ₹100
        expect(
          BillingCalculator.calculateTaxableValueFromInclusiveTotal(105.0, 5.0),
          100.0,
        );
        // 0% GST -> base is unchanged
        expect(
          BillingCalculator.calculateTaxableValueFromInclusiveTotal(150.0, 0.0),
          150.0,
        );
      },
    );

    test('calculateItemTotal sums taxable value and GST', () {
      expect(BillingCalculator.calculateItemTotal(100.0, 18.0), 118.0);
      expect(BillingCalculator.calculateItemTotal(250.50, 45.09), 295.59);
    });
  });

  group('determineGstSplit Intra-State vs Inter-State Tests', () {
    test(
      'splits GST equally into CGST and SGST for same state (Intra-State)',
      () {
        final breakdown = BillingCalculator.determineGstSplit(
          businessState: 'Tamil Nadu',
          customerState: 'Tamil Nadu',
          gstRate: 18.0,
          totalGstAmount: 180.0,
        );

        expect(breakdown.cgst, 90.0);
        expect(breakdown.sgst, 90.0);
        expect(breakdown.igst, 0.0);
        expect(breakdown.cgst + breakdown.sgst, 180.0);
      },
    );

    test('handles odd-cent rounding properly without losing a paisa (e.g. ₹0.05 total GST)', () {
      final breakdown = BillingCalculator.determineGstSplit(
        businessState: 'Maharashtra',
        customerState: 'Maharashtra',
        gstRate: 5.0,
        totalGstAmount: 0.05,
      );

      expect(breakdown.cgst, 0.03); // 0.05 / 2 = 0.025 -> 0.03
      expect(breakdown.sgst, 0.02); // remainder 0.05 - 0.03 = 0.02
      expect(breakdown.igst, 0.0);
      expect(BillingCalculator.round2(breakdown.cgst + breakdown.sgst), 0.05);
    });

    test('assigns 100% of GST to IGST for different states (Inter-State)', () {
      final breakdown = BillingCalculator.determineGstSplit(
        businessState: 'Tamil Nadu',
        customerState: 'Karnataka',
        gstRate: 18.0,
        totalGstAmount: 180.0,
      );

      expect(breakdown.cgst, 0.0);
      expect(breakdown.sgst, 0.0);
      expect(breakdown.igst, 180.0);
    });

    test('handles case-insensitive and whitespace trimmed state matching', () {
      final breakdown = BillingCalculator.determineGstSplit(
        businessState: '  kerala  ',
        customerState: 'KERALA',
        gstRate: 12.0,
        totalGstAmount: 120.0,
      );

      expect(breakdown.cgst, 60.0);
      expect(breakdown.sgst, 60.0);
      expect(breakdown.igst, 0.0);
    });

    test('returns zero for all taxes when gstRate is 0', () {
      final breakdown = BillingCalculator.determineGstSplit(
        businessState: 'Delhi',
        customerState: 'Delhi',
        gstRate: 0.0,
        totalGstAmount: 0.0,
      );

      expect(breakdown.cgst, 0.0);
      expect(breakdown.sgst, 0.0);
      expect(breakdown.igst, 0.0);
    });

    test('throws exception when states are missing and GST rate > 0', () {
      expect(
        () => BillingCalculator.determineGstSplit(
          businessState: null,
          customerState: 'Tamil Nadu',
          gstRate: 18.0,
          totalGstAmount: 180.0,
        ),
        throwsException,
      );

      expect(
        () => BillingCalculator.determineGstSplit(
          businessState: 'Tamil Nadu',
          customerState: '',
          gstRate: 18.0,
          totalGstAmount: 180.0,
        ),
        throwsException,
      );
    });
  });
}
