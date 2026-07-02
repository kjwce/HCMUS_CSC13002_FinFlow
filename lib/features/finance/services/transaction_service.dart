import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_model.dart';
import 'wallet_service.dart';

/// Service handling all transaction CRUD operations via Supabase.
class TransactionService extends ChangeNotifier {
  TransactionService._();

  static final TransactionService instance = TransactionService._();
  List<TransactionModel> _transactions = [];

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  List<TransactionModel> get currentUserTransactions {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    return _transactions
        .where((t) => t.userId == userId)
        .toList(growable: false);
  }

  /// Income transactions across ALL time.
  int get monthlyIncome {
    final now = DateTime.now();
    return currentUserTransactions
        .where((t) => t.amount > 0 && _sameMonth(t.date, now))
        .fold(0, (total, t) => total + t.amount);
  }

  /// Expense transactions across ALL time.
  int get monthlyExpense {
    final now = DateTime.now();
    return currentUserTransactions
        .where((t) => t.amount < 0 && _sameMonth(t.date, now))
        .fold(0, (total, t) => total + t.amount.abs());
  }

  /// Lifetime cumulative balance = initial balances of all wallets
  /// + total income - total expense of all transactions.
  int get totalBalance {
    final walletService = WalletService.instance;
    final initialSum = walletService.totalInitialBalance;
    int income = 0, expense = 0;
    for (final t in currentUserTransactions) {
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    return initialSum + income - expense;
  }

  /// Kept for backward compatibility.
  int get monthlyBalance => totalBalance;

  /// Sum of all income (amount > 0) in the last 7 rolling days.
  int get revenueLast7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return currentUserTransactions
        .where((t) => t.amount > 0 && t.date.isAfter(cutoff))
        .fold(0, (total, t) => total + t.amount);
  }

  /// Sum of all expense (amount < 0) for a given [category] in the last 7 rolling days.
  int categoryExpenseLast7Days(String category) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return currentUserTransactions
        .where((t) =>
            t.amount < 0 &&
            t.category == category &&
            t.date.isAfter(cutoff))
        .fold(0, (total, t) => total + t.amount.abs());
  }

  /// Balance for a specific wallet.
  /// = wallet's initialBalance + income - expense of its transactions.
  int balanceByWallet(String walletId) {
    final wallet = WalletService.instance.byId(walletId);
    final initial = wallet?.initialBalance ?? 0;
    final txs =
        currentUserTransactions.where((t) => t.walletId == walletId);
    int income = 0, expense = 0;
    for (final t in txs) {
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    return initial + income - expense;
  }

  /// Income for a specific wallet this month.
  int monthlyIncomeByWallet(String walletId) {
    final now = DateTime.now();
    return currentUserTransactions
        .where((t) =>
            t.walletId == walletId &&
            t.amount > 0 &&
            _sameMonth(t.date, now))
        .fold(0, (total, t) => total + t.amount);
  }

  /// Expense for a specific wallet this month.
  int monthlyExpenseByWallet(String walletId) {
    final now = DateTime.now();
    return currentUserTransactions
        .where((t) =>
            t.walletId == walletId &&
            t.amount < 0 &&
            _sameMonth(t.date, now))
        .fold(0, (total, t) => total + t.amount.abs());
  }

  /// Total balance accumulated up to a given date.
  int balanceAtDate(DateTime date) {
    final walletService = WalletService.instance;
    final initialSum = walletService.totalInitialBalance;
    final txs = currentUserTransactions
        .where((t) => !t.date.isAfter(date));
    int income = 0, expense = 0;
    for (final t in txs) {
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    return initialSum + income - expense;
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  Future<void> fetchTransactions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _transactions = [];
      notifyListeners();
      return;
    }
    final res = await Supabase.instance.client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);
    _transactions = (res as List)
        .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> add(TransactionModel transaction) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client.from('transactions').insert({
      'id': transaction.id,
      'user_id': userId,
      'title': transaction.title,
      'category': transaction.category,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      if (transaction.walletId != null) 'wallet_id': transaction.walletId,
    });
    await fetchTransactions();
  }

  Future<void> update(TransactionModel transaction) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('transactions')
        .update({
          'title': transaction.title,
          'category': transaction.category,
          'amount': transaction.amount,
          'date': transaction.date.toIso8601String(),
          if (transaction.walletId != null) 'wallet_id': transaction.walletId,
        })
        .eq('id', transaction.id)
        .eq('user_id', userId);
    await fetchTransactions();
  }

  Future<void> delete(String transactionId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('transactions')
        .delete()
        .eq('id', transactionId)
        .eq('user_id', userId);
    await fetchTransactions();
  }

  Future<void> clearAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('transactions')
        .delete()
        .eq('user_id', userId);
    _transactions = [];
    notifyListeners();
  }
}
