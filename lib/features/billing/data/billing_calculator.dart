class BillingCalculator {
  static double round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  static double calculateItemSubtotal(double quantity, double unitPrice) {
    return round2(quantity * unitPrice);
  }

  static double calculateItemTaxableValue(double subtotal, double discount) {
    return round2(subtotal - discount);
  }

  static double calculateGstAmount(double taxableValue, double gstRate) {
    if (gstRate <= 0) return 0.0;
    return round2(taxableValue * (gstRate / 100));
  }

  static double calculateTaxableValueFromInclusiveTotal(
    double total,
    double gstRate,
  ) {
    if (gstRate <= 0) return total;
    return round2(total / (1 + (gstRate / 100)));
  }

  static double calculateItemTotal(double taxableValue, double totalGstAmount) {
    return round2(taxableValue + totalGstAmount);
  }

  static InvoiceTaxBreakdown determineGstSplit({
    required String? businessState,
    required String? customerState,
    required double gstRate,
    required double totalGstAmount,
  }) {
    if (gstRate <= 0) {
      return InvoiceTaxBreakdown(cgst: 0, sgst: 0, igst: 0);
    }

    if (businessState == null ||
        businessState.trim().isEmpty ||
        customerState == null ||
        customerState.trim().isEmpty) {
      // Must not silently assume intra-state.
      // UI validation must prevent reaching here, but if it does:
      throw Exception(
        'GST requires both Business and Customer state to be defined.',
      );
    }

    final isSameState =
        businessState.trim().toLowerCase() ==
        customerState.trim().toLowerCase();

    if (isSameState) {
      final halfGst = round2(totalGstAmount / 2);
      // Correct for minor 1-paisa rounding errors by making sgst take the remainder
      final remainder = round2(totalGstAmount - halfGst);
      return InvoiceTaxBreakdown(cgst: halfGst, sgst: remainder, igst: 0);
    } else {
      return InvoiceTaxBreakdown(cgst: 0, sgst: 0, igst: totalGstAmount);
    }
  }
}

class InvoiceTaxBreakdown {
  final double cgst;
  final double sgst;
  final double igst;

  InvoiceTaxBreakdown({
    required this.cgst,
    required this.sgst,
    required this.igst,
  });
}
