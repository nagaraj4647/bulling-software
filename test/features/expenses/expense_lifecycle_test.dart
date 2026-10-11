import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/expenses/models/expense_model.dart';

void main() {
  group('ExpenseModel Lifecycle & Invariants Tests', () {
    final sampleExpense = ExpenseModel(
      expenseId: 'exp-001',
      businessId: 'biz-001',
      expenseDate: DateTime(2026, 3, 3, 14, 30),
      category: ExpenseCategory.electricity,
      description: 'Monthly office electricity bill',
      amount: 2500.0,
      paymentMethod: 'UPI',
      notes: 'EB Bill for Feb',
      status: ExpenseStatus.draft,
      createdAt: DateTime(2026, 3, 3, 14, 30),
      updatedAt: DateTime(2026, 3, 3, 14, 30),
    );

    test('copyWith updates draft expense fields correctly', () {
      final updatedExpense = sampleExpense.copyWith(
        category: ExpenseCategory.rent,
        description: 'Office monthly rent',
        amount: 15000.0,
        paymentMethod: 'Bank',
      );

      expect(updatedExpense.category, ExpenseCategory.rent);
      expect(updatedExpense.description, 'Office monthly rent');
      expect(updatedExpense.amount, 15000.0);
      expect(updatedExpense.paymentMethod, 'Bank');
      expect(updatedExpense.businessId, sampleExpense.businessId);
      expect(updatedExpense.expenseId, sampleExpense.expenseId);
    });

    test('Status transitions: draft -> confirmed -> cancelled', () {
      final confirmed = sampleExpense.copyWith(status: ExpenseStatus.confirmed);
      expect(confirmed.status, ExpenseStatus.confirmed);

      final cancelled = confirmed.copyWith(status: ExpenseStatus.cancelled);
      expect(cancelled.status, ExpenseStatus.cancelled);
    });

    test('Expense amount must be positive invariant', () {
      expect(sampleExpense.amount > 0, isTrue);

      final invalidAmount = 0.0;
      expect(invalidAmount > 0, isFalse);

      final negativeAmount = -50.0;
      expect(negativeAmount > 0, isFalse);
    });

    test('All enum categories are supported', () {
      for (final cat in ExpenseCategory.values) {
        final exp = sampleExpense.copyWith(category: cat);
        expect(exp.category, cat);
      }
    });
  });
}
