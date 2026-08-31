import 'package:flutter_test/flutter_test.dart';
import 'package:finflow/features/finance/models/transaction_category.dart';

void main() {
  test('legacy chart categories are renamed without losing detail', () {
    expect(
      TransactionCategory.normalizedKey('Car', isIncome: true),
      'Transport',
    );
    expect(TransactionCategory.normalizedKey('Home', isIncome: true), 'Rent');
    expect(
      TransactionCategory.normalizedKey('Gift', isIncome: true),
      'Gift Received',
    );
    expect(TransactionCategory.normalizedKey('Food', isIncome: true), 'Food');
    expect(
      TransactionCategory.normalizedKey('Service', isIncome: true),
      'Service',
    );
  });
}
