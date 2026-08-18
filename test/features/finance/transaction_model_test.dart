import 'package:finflow/features/finance/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records created_at separately from the transaction date', () {
    final transaction = TransactionModel.fromJson({
      'id': 'transaction-1',
      'user_id': 'user-1',
      'name': 'Lunch',
      'category': 'Food',
      'amount': -120000,
      'date': '2026-08-11T17:45:00',
      'created_at': '2026-08-16T03:30:00Z',
    });

    expect(transaction.date.day, 11);
    expect(transaction.recordedAt.toUtc(), DateTime.utc(2026, 8, 16, 3, 30));
  });

  test('falls back to transaction date for legacy records', () {
    final date = DateTime(2026, 8, 16, 9, 42);
    final transaction = TransactionModel(
      id: 'legacy',
      userId: 'user-1',
      name: 'Legacy transaction',
      category: 'Other',
      amount: 1000,
      date: date,
    );

    expect(transaction.recordedAt, date);
  });

  test('latest uses entry time instead of the assigned transaction date', () {
    final olderEntryWithLaterDate = TransactionModel(
      id: 'older-entry',
      userId: 'user-1',
      name: 'Scheduled bill',
      category: 'Bills',
      amount: -500000,
      date: DateTime(2026, 8, 16, 20),
      createdAt: DateTime(2026, 8, 15, 8),
    );
    final newerEntryWithEarlierDate = TransactionModel(
      id: 'newer-entry',
      userId: 'user-1',
      name: 'Food',
      category: 'Food',
      amount: 2000000,
      date: DateTime(2026, 8, 11, 17, 45),
      createdAt: DateTime(2026, 8, 16, 9),
    );

    expect(
      TransactionModel.latestRecorded([
        olderEntryWithLaterDate,
        newerEntryWithEarlierDate,
      ]),
      same(newerEntryWithEarlierDate),
    );
  });
}
