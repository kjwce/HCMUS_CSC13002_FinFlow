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

  test('keeps a stored UTC marker as the entered local transaction time', () {
    final transaction = TransactionModel.fromJson({
      'id': 'new-transaction',
      'user_id': 'user-1',
      'name': 'Food',
      'category': 'Food',
      'amount': -1000000,
      'date': '2026-08-17T17:38:00Z',
      'created_at': '2026-08-17T10:38:00Z',
    });

    expect(transaction.date, DateTime(2026, 8, 17, 17, 38));
    expect(transaction.date.isUtc, isFalse);
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

  test('latest occurred uses transaction date and ignores future entries', () {
    final grabEnteredLast = TransactionModel(
      id: 'grab',
      userId: 'user-1',
      name: 'Grab',
      category: 'Transport',
      amount: -150000,
      date: DateTime(2026, 10, 18, 15, 18),
      createdAt: DateTime(2026, 8, 29, 8),
    );
    final wifi = TransactionModel(
      id: 'wifi',
      userId: 'user-1',
      name: 'wifi',
      category: 'Internet & Utilities',
      amount: -200000,
      date: DateTime(2026, 8, 29, 7),
      createdAt: DateTime(2026, 8, 29, 7),
    );
    final food = TransactionModel(
      id: 'food',
      userId: 'user-1',
      name: 'Food',
      category: 'Food',
      amount: -500000,
      date: DateTime(2026, 8, 29, 5, 34),
      createdAt: DateTime(2026, 8, 29, 9),
    );

    expect(
      TransactionModel.latestOccurred([
        grabEnteredLast,
        food,
        wifi,
      ], asOf: DateTime(2026, 8, 29, 12)),
      same(wifi),
    );
  });
}
