import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../budget/services/category_budget_service.dart';
import '../../community/models/notification_model.dart';
import '../../community/services/notification_service.dart';
import '../../settings/services/notification_preferences_service.dart';
import '../models/transaction_model.dart';
import '../models/transaction_category.dart';
import 'goal_service.dart';
import 'wallet_service.dart';

/// Time period filter for charts.
enum ChartPeriod { day, week, month, year }

/// Represents a time range with start and end dates.
class DateRange {
  const DateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// A single bucket of time‑series data used by charts.
class PeriodBucket {
  const PeriodBucket({
    required this.label,
    required this.income,
    required this.expense,
    this.start,
    this.balanceValue,
  });
  final String label;
  final int income;
  final int expense;
  final DateTime? start;
  final int? balanceValue;
  int get balance => balanceValue ?? income - expense;
}

/// Service handling all transaction CRUD operations via Supabase.
class TransactionService extends ChangeNotifier {
  TransactionService._();

  static final TransactionService instance = TransactionService._();
  List<TransactionModel> _transactions = [];
  RealtimeChannel? _transactionsChannel;
  String? _realtimeUserId;
  int _fetchEpoch = 0;
  final Set<String> _futureDateRepairs = {};

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  List<TransactionModel> get currentUserTransactions {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    return _transactions
        .where((t) => t.userId == userId)
        .toList(growable: false);
  }

  // ── Cached computed values ──
  int? _cachedMonthlyIncome;
  int? _cachedMonthlyExpense;
  int? _cachedTotalBalance;
  final Map<String, Map<String, int>> _cachedExpenseByCategory = {};
  final Map<String, Map<String, int>> _cachedIncomeByCategory = {};
  final Map<String, Map<String, int>> _cachedIncomeByWalletType = {};
  final Map<String, Map<String, int>> _cachedExpenseByWalletType = {};
  final Map<String, List<PeriodBucket>> _cachedPeriodBuckets = {};
  final Map<String, Map<String, int>> _cachedIncomeByWallet = {};

  void _clearCache() {
    _cachedMonthlyIncome = null;
    _cachedMonthlyExpense = null;
    _cachedTotalBalance = null;
    _cachedExpenseByCategory.clear();
    _cachedIncomeByCategory.clear();
    _cachedIncomeByWalletType.clear();
    _cachedExpenseByWalletType.clear();
    _cachedPeriodBuckets.clear();
    _cachedIncomeByWallet.clear();
  }

  @override
  void notifyListeners() {
    _clearCache();
    super.notifyListeners();
  }

  /// Income in the current calendar month (cached).
  int get monthlyIncome {
    _cachedMonthlyIncome ??= _computeMonthlyIncome();
    return _cachedMonthlyIncome!;
  }

  int _computeMonthlyIncome() {
    final range = dateRangeForPeriod(ChartPeriod.month);
    return incomeBetween(range.start, range.end);
  }

  /// Expense in the current calendar month (cached).
  int get monthlyExpense {
    _cachedMonthlyExpense ??= _computeMonthlyExpense();
    return _cachedMonthlyExpense!;
  }

  int _computeMonthlyExpense() {
    final range = dateRangeForPeriod(ChartPeriod.month);
    return expenseBetween(range.start, range.end);
  }

  /// Lifetime cumulative balance = initial balances of all wallets
  /// + total income - total expense of all transactions (cached).
  int get totalBalance {
    _cachedTotalBalance ??= _computeTotalBalance();
    return _cachedTotalBalance!;
  }

  int _computeTotalBalance() {
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
        .where(
          (t) =>
              t.amount < 0 && t.category == category && t.date.isAfter(cutoff),
        )
        .fold(0, (total, t) => total + t.amount.abs());
  }

  /// Balance for a specific wallet.
  /// = wallet's initialBalance + income - expense of its transactions.
  int balanceByWallet(String walletId) {
    final wallet = WalletService.instance.byId(walletId);
    final initial = wallet?.initialBalance ?? 0;
    final txs = currentUserTransactions.where((t) => t.walletId == walletId);
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

  /// Lifetime income recorded against one wallet.
  int incomeByWallet(String walletId) {
    return currentUserTransactions
        .where(
          (transaction) =>
              transaction.walletId == walletId && transaction.amount > 0,
        )
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  /// Lifetime expense recorded against one wallet.
  int expenseByWallet(String walletId) {
    return currentUserTransactions
        .where(
          (transaction) =>
              transaction.walletId == walletId && transaction.amount < 0,
        )
        .fold(0, (total, transaction) => total + transaction.amount.abs());
  }

  /// Income for a specific wallet this month.
  int monthlyIncomeByWallet(String walletId) {
    final range = dateRangeForPeriod(ChartPeriod.month);
    return currentUserTransactions
        .where(
          (t) =>
              t.walletId == walletId &&
              t.amount > 0 &&
              _isWithinRange(t.date, range.start, range.end),
        )
        .fold(0, (total, t) => total + t.amount);
  }

  /// Expense for a specific wallet this month.
  int monthlyExpenseByWallet(String walletId) {
    final range = dateRangeForPeriod(ChartPeriod.month);
    return currentUserTransactions
        .where(
          (t) =>
              t.walletId == walletId &&
              t.amount < 0 &&
              _isWithinRange(t.date, range.start, range.end),
        )
        .fold(0, (total, t) => total + t.amount.abs());
  }

  /// Total balance accumulated up to a given date.
  int balanceAtDate(DateTime date) {
    final walletService = WalletService.instance;
    final initialSum = walletService.totalInitialBalance;
    final end = date.add(const Duration(microseconds: 1));
    final txs = currentUserTransactions.where(
      (t) => _isWithinRange(t.date, DateTime(1900), end),
    );
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

  int balanceBefore(DateTime end) {
    final walletService = WalletService.instance;
    final initialSum = walletService.totalInitialBalance;
    int income = 0, expense = 0;
    for (final t in currentUserTransactions) {
      if (!_wallClockDate(t.date).isBefore(end)) continue;
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    return initialSum + income - expense;
  }

  bool _isWithinRange(DateTime date, DateTime start, DateTime end) {
    final wallClock = _wallClockDate(date);
    return !wallClock.isBefore(start) && wallClock.isBefore(end);
  }

  DateTime _wallClockDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  /// Income between two dates. [end] is exclusive.
  int incomeBetween(DateTime start, DateTime end) {
    return currentUserTransactions
        .where((t) => t.amount > 0 && _isWithinRange(t.date, start, end))
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Expense (absolute) between two dates. [end] is exclusive.
  int expenseBetween(DateTime start, DateTime end) {
    return currentUserTransactions
        .where((t) => t.amount < 0 && _isWithinRange(t.date, start, end))
        .fold(0, (sum, t) => sum + t.amount.abs());
  }

  /// Transactions in a period using the same local date range as all charts.
  List<TransactionModel> transactionsForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final range = dateRangeForPeriod(period, offset: offset);
    return currentUserTransactions
        .where((t) => _isWithinRange(t.date, range.start, range.end))
        .toList(growable: false);
  }

  /// Expense breakdown by category between two dates.
  /// Returns a map of categoryKey → total expense (positive).
  Map<String, int> expenseByCategoryBetween(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (final t in currentUserTransactions.where(
      (t) => t.amount < 0 && _isWithinRange(t.date, start, end),
    )) {
      final category = TransactionCategory.normalizedKey(
        t.category,
        isIncome: false,
      );
      map.update(
        category,
        (v) => v + t.amount.abs(),
        ifAbsent: () => t.amount.abs(),
      );
    }
    return map;
  }

  /// Income breakdown by category between two dates.
  /// Returns a map of categoryKey -> total income.
  Map<String, int> incomeByCategoryBetween(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (final t in currentUserTransactions.where(
      (t) => t.amount > 0 && _isWithinRange(t.date, start, end),
    )) {
      final category = TransactionCategory.normalizedKey(
        t.category,
        isIncome: true,
      );
      map.update(category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return map;
  }

  /// Income breakdown by walletId between two dates.
  Map<String, int> incomeByWalletBetween(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (final t in currentUserTransactions.where(
      (t) => t.amount > 0 && _isWithinRange(t.date, start, end),
    )) {
      map.update(
        t.walletId ?? '',
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
    }
    return map;
  }

  // --------------------------------------------------------------------------
  // Chart data helper methods
  // --------------------------------------------------------------------------

  /// Return an exclusive‑end date range for [period].
  /// The [end] is midnight of the day after the last included day.
  DateRange dateRangeForPeriod(ChartPeriod period, {int offset = 0}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case ChartPeriod.day:
        final targetDay = today.add(Duration(days: offset));
        return DateRange(
          start: targetDay,
          end: targetDay.add(const Duration(days: 1)),
        );
      case ChartPeriod.week:
        final daysFromMonday = today.weekday - DateTime.monday;
        final thisMonday = today
            .subtract(Duration(days: daysFromMonday))
            .add(Duration(days: offset * 7));
        return DateRange(
          start: thisMonday,
          end: thisMonday.add(const Duration(days: 7)),
        );
      case ChartPeriod.month:
        final target = DateTime(today.year, today.month + offset, 1);
        return DateRange(
          start: target,
          end: DateTime(target.year, target.month + 1, 1),
        );
      case ChartPeriod.year:
        final year = today.year + offset;
        return DateRange(
          start: DateTime(year, 1, 1),
          end: DateTime(year + 1, 1, 1),
        );
    }
  }

  /// Build a list of [PeriodBucket] for time‑series charts (cached).
  /// Buckets are ordered oldest‑to‑newest.
  List<PeriodBucket> periodBuckets(ChartPeriod period, {int offset = 0}) {
    final cacheKey = 'pb_${period.name}_${offset}_${_snapshotDate()}';
    if (_cachedPeriodBuckets.containsKey(cacheKey)) {
      return _cachedPeriodBuckets[cacheKey]!;
    }
    final result = _computePeriodBuckets(period, offset: offset);
    // Keep only last 8 cache entries to avoid memory leak
    if (_cachedPeriodBuckets.length > 8) {
      _cachedPeriodBuckets.remove(_cachedPeriodBuckets.keys.first);
    }
    _cachedPeriodBuckets[cacheKey] = result;
    return result;
  }

  String _snapshotDate() {
    final n = DateTime.now();
    return '${n.year}_${n.month}_${n.day}_${n.hour}';
  }

  List<PeriodBucket> _computePeriodBuckets(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bucketDefs = <(DateTime start, String label)>[];

    switch (period) {
      case ChartPeriod.day:
        {
          final targetDay = today.add(Duration(days: offset));
          // Preserve one data point per hour. The chart can then keep all 24
          // buckets for accurate totals while rendering only a few axis
          // labels, which is much easier to scan on a phone.
          for (var hour = 0; hour < 24; hour++) {
            final start = targetDay.add(Duration(hours: hour));
            bucketDefs.add((start, '${hour.toString().padLeft(2, '0')}:00'));
          }
          break;
        }
      case ChartPeriod.week:
        {
          final daysFromMonday = today.weekday - DateTime.monday;
          final weekStart = today
              .subtract(Duration(days: daysFromMonday))
              .add(Duration(days: offset * 7));
          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          for (int i = 0; i < 7; i++) {
            final d = weekStart.add(Duration(days: i));
            bucketDefs.add((d, names[i]));
          }
          break;
        }
      case ChartPeriod.month:
        {
          final monthStart = DateTime(today.year, today.month + offset, 1);
          final daysInMonth = DateTime(
            monthStart.year,
            monthStart.month + 1,
            0,
          ).day;
          for (int i = 0; i < daysInMonth; i++) {
            final d = monthStart.add(Duration(days: i));
            bucketDefs.add((d, '${d.day}'));
          }
          break;
        }
      case ChartPeriod.year:
        {
          final endYear = now.year + offset * 3;
          for (int i = 2; i >= 0; i--) {
            final y = endYear - i;
            bucketDefs.add((DateTime(y, 1, 1), '$y'));
          }
          break;
        }
    }

    var runningBalance = bucketDefs.isEmpty
        ? 0
        : balanceBefore(bucketDefs.first.$1);

    return bucketDefs.map((b) {
      final (start, label) = b;
      DateTime end;
      switch (period) {
        case ChartPeriod.day:
          end = start.add(const Duration(hours: 1));
          break;
        case ChartPeriod.week:
          end = start.add(const Duration(days: 1));
          break;
        case ChartPeriod.month:
          end = start.add(const Duration(days: 1));
          break;
        case ChartPeriod.year:
          end = DateTime(start.year + 1, 1, 1);
          break;
      }

      int income = 0, expense = 0;
      for (final t in currentUserTransactions) {
        if (!_isWithinRange(t.date, start, end)) continue;
        if (t.amount > 0) {
          income += t.amount;
        } else {
          expense += t.amount.abs();
        }
      }
      runningBalance += income - expense;
      return PeriodBucket(
        label: label,
        income: income,
        expense: expense,
        start: start,
        balanceValue: runningBalance,
      );
    }).toList();
  }

  /// Income breakdown by category for [period] (cached).
  Map<String, int> incomeByCategoryForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final cacheKey = 'incCat_${period.name}_${offset}_${_snapshotDate()}';
    final inner = _cachedIncomeByCategory;
    if (inner.containsKey(cacheKey)) return inner[cacheKey]!;

    final range = dateRangeForPeriod(period, offset: offset);
    final result = incomeByCategoryBetween(range.start, range.end);

    if (inner.length > 8) inner.remove(inner.keys.first);
    inner[cacheKey] = result;
    return result;
  }

  /// Expense breakdown by category for [period] (cached).
  Map<String, int> expenseByCategoryForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final cacheKey = 'exp_${period.name}_${offset}_${_snapshotDate()}';
    final inner = _cachedExpenseByCategory;
    if (inner.containsKey(cacheKey)) return inner[cacheKey]!;

    final range = dateRangeForPeriod(period, offset: offset);
    final result = expenseByCategoryBetween(range.start, range.end);

    if (inner.length > 8) inner.remove(inner.keys.first);
    inner[cacheKey] = result;
    return result;
  }

  /// Income breakdown by payment source (cash / transfer) for [period].
  Map<String, int> incomeByWalletTypeForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final cacheKey = 'incType_${period.name}_${offset}_${_snapshotDate()}';
    final inner = _cachedIncomeByWalletType;
    if (inner.containsKey(cacheKey)) return inner[cacheKey]!;

    final range = dateRangeForPeriod(period, offset: offset);
    final map = <String, int>{'cash': 0, 'transfer': 0};
    final ws = WalletService.instance;

    for (final t in currentUserTransactions) {
      if (t.amount <= 0) continue;
      if (!_isWithinRange(t.date, range.start, range.end)) continue;
      final wallet = ws.byId(t.walletId);
      final type = wallet?.type.name ?? 'transfer';
      map[type] = (map[type] ?? 0) + t.amount;
    }

    if (inner.length > 8) inner.remove(inner.keys.first);
    inner[cacheKey] = map;
    return map;
  }

  /// Expense breakdown by payment source (cash / transfer) for [period].
  Map<String, int> expenseByWalletTypeForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final cacheKey = 'expType_${period.name}_${offset}_${_snapshotDate()}';
    final inner = _cachedExpenseByWalletType;
    if (inner.containsKey(cacheKey)) return inner[cacheKey]!;

    final range = dateRangeForPeriod(period, offset: offset);
    final map = <String, int>{'cash': 0, 'transfer': 0};
    final ws = WalletService.instance;

    for (final t in currentUserTransactions) {
      if (t.amount >= 0) continue;
      if (!_isWithinRange(t.date, range.start, range.end)) continue;
      final wallet = ws.byId(t.walletId);
      final type = wallet?.type.name ?? 'transfer';
      map[type] = (map[type] ?? 0) + t.amount.abs();
    }

    if (inner.length > 8) inner.remove(inner.keys.first);
    inner[cacheKey] = map;
    return map;
  }

  /// Income breakdown by individual wallet for [period] (cached).
  Map<String, int> incomeByWalletForPeriod(
    ChartPeriod period, {
    int offset = 0,
  }) {
    final cacheKey = 'incWal_${period.name}_${offset}_${_snapshotDate()}';
    final inner = _cachedIncomeByWallet;
    if (inner.containsKey(cacheKey)) return inner[cacheKey]!;

    final range = dateRangeForPeriod(period, offset: offset);
    final result = incomeByWalletBetween(range.start, range.end);

    if (inner.length > 8) inner.remove(inner.keys.first);
    inner[cacheKey] = result;
    return result;
  }

  Future<void> fetchTransactions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      stopRealtime();
      _transactions = [];
      notifyListeners();
      return;
    }
    startRealtime(userId);
    final fetchEpoch = ++_fetchEpoch;
    final res = await Supabase.instance.client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);
    if (fetchEpoch != _fetchEpoch ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return;
    }
    final fetched = (res as List)
        .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
        .toList(growable: false);
    final now = DateTime.now();
    final repairs = <TransactionModel>[];
    _transactions = fetched
        .map((transaction) {
          final repaired = transaction.repairInvalidFutureDate(now);
          if (!identical(repaired, transaction) &&
              _futureDateRepairs.add(transaction.id)) {
            repairs.add(repaired);
          }
          return repaired;
        })
        .toList(growable: false);
    notifyListeners();
    if (repairs.isNotEmpty) {
      unawaited(_persistFutureDateRepairs(userId, repairs));
    }
  }

  Future<void> _persistFutureDateRepairs(
    String userId,
    List<TransactionModel> repairs,
  ) async {
    try {
      await Future.wait(
        repairs.map(
          (transaction) => Supabase.instance.client
              .from('transactions')
              .update({'date': TransactionModel.databaseIso(transaction.date)})
              .eq('id', transaction.id)
              .eq('user_id', userId),
        ),
      );
    } catch (error) {
      debugPrint('Unable to repair future transaction dates: $error');
    } finally {
      _futureDateRepairs.removeAll(
        repairs.map((transaction) => transaction.id),
      );
    }
  }

  /// Keep every transaction-backed surface synchronized with changes made on
  /// another device or directly in Supabase.
  void startRealtime(String userId) {
    if (_realtimeUserId == userId && _transactionsChannel != null) return;
    stopRealtime(clearUser: false);
    _realtimeUserId = userId;
    _transactionsChannel = Supabase.instance.client
        .channel('transactions-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            if (Supabase.instance.client.auth.currentUser?.id != userId) return;
            fetchTransactions().catchError(
              (Object error) =>
                  debugPrint('Realtime transaction refresh failed: $error'),
            );
          },
        )
        .subscribe();
  }

  void stopRealtime({bool clearUser = true}) {
    _transactionsChannel?.unsubscribe();
    _transactionsChannel = null;
    if (clearUser) _realtimeUserId = null;
  }

  Future<List<String>> add(
    TransactionModel transaction, {
    bool isImported = false,
    Map<String, int> goalWithdrawals = const {},
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final completedBefore = GoalService.instance.goals
        .where((goal) => goal.isCompleted)
        .map((goal) => goal.id)
        .toSet();

    await Supabase.instance.client.rpc(
      'create_transaction_with_goal_handling',
      params: {
        'p_id': transaction.id,
        'p_name': transaction.name,
        'p_category': transaction.category,
        'p_amount': transaction.amount,
        'p_date': TransactionModel.databaseIso(transaction.date),
        'p_wallet_id': transaction.walletId,
        'p_is_imported': isImported,
        'p_withdrawals': goalWithdrawals.entries
            .map((entry) => {'goal_id': entry.key, 'amount': entry.value})
            .toList(growable: false),
      },
    );
    await Future.wait([fetchTransactions(), GoalService.instance.fetchGoals()]);
    await _emitBudgetNotifications();
    return GoalService.instance.goals
        .where((goal) => goal.isCompleted && !completedBefore.contains(goal.id))
        .map((goal) => goal.id)
        .toList(growable: false);
  }

  Future<void> update(
    TransactionModel transaction, {
    Map<String, int> goalWithdrawals = const {},
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client.rpc(
      'update_transaction_with_goal_handling',
      params: {
        'p_id': transaction.id,
        'p_name': transaction.name,
        'p_category': transaction.category,
        'p_amount': transaction.amount,
        'p_date': TransactionModel.databaseIso(transaction.date),
        'p_wallet_id': transaction.walletId,
        'p_withdrawals': goalWithdrawals.entries
            .map((entry) => {'goal_id': entry.key, 'amount': entry.value})
            .toList(growable: false),
      },
    );
    await Future.wait([fetchTransactions(), GoalService.instance.fetchGoals()]);
    await _emitBudgetNotifications();
  }

  Future<void> delete(String transactionId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await Supabase.instance.client
        .from('transactions')
        .delete()
        .eq('id', transactionId)
        .eq('user_id', userId);
    await Future.wait([fetchTransactions(), GoalService.instance.fetchGoals()]);
    await _emitBudgetNotifications();
  }

  Future<void> _emitBudgetNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('daily_budget, weekly_budget, budget_limit')
          .eq('id', userId)
          .single();
      await CategoryBudgetService.instance.fetchCurrentMonth();
      final preferences = NotificationPreferencesService.instance.value;
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final weekStart = dayStart.subtract(
        Duration(days: dayStart.weekday - DateTime.monday),
      );
      final monthStart = DateTime(now.year, now.month);
      final nextMonth = DateTime(now.year, now.month + 1);
      int spent(DateTime start, DateTime end, {String? category}) {
        return currentUserTransactions
            .where(
              (item) =>
                  item.amount < 0 &&
                  !item.date.isBefore(start) &&
                  item.date.isBefore(end) &&
                  (category == null || item.category == category),
            )
            .fold(0, (sum, item) => sum + item.amount.abs());
      }

      await _emitBudgetLevel(
        name: 'Daily spending',
        nameVi: 'Chi tiêu hôm nay',
        category: null,
        period: 'daily',
        periodKey:
            '${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}',
        spent: spent(dayStart, dayStart.add(const Duration(days: 1))),
        limit: (profile['daily_budget'] as num?)?.toInt() ?? 0,
        threshold: preferences.dailyBudgetThreshold,
      );
      await _emitBudgetLevel(
        name: 'Weekly spending',
        nameVi: 'Chi tiêu tuần này',
        category: null,
        period: 'weekly',
        periodKey:
            '${weekStart.year}-W${((weekStart.difference(DateTime(weekStart.year)).inDays) ~/ 7) + 1}',
        spent: spent(weekStart, weekStart.add(const Duration(days: 7))),
        limit: (profile['weekly_budget'] as num?)?.toInt() ?? 0,
        threshold: preferences.weeklyBudgetThreshold,
      );
      await _emitBudgetLevel(
        name: 'Monthly spending',
        nameVi: 'Chi tiêu tháng này',
        category: null,
        period: 'monthly',
        periodKey: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        spent: spent(monthStart, nextMonth),
        limit: (profile['budget_limit'] as num?)?.toInt() ?? 0,
        threshold: preferences.monthlyBudgetThreshold,
      );
      for (final budget in CategoryBudgetService.instance.budgets) {
        await _emitBudgetLevel(
          name: budget.category,
          nameVi: budget.category,
          category: budget.category,
          period: 'monthly',
          periodKey:
              '${budget.year}-${budget.month.toString().padLeft(2, '0')}',
          spent: spent(monthStart, nextMonth, category: budget.category),
          limit: budget.limitAmount,
          threshold: preferences.monthlyBudgetThreshold,
          entityId: budget.id,
        );
      }
    } catch (error) {
      debugPrint('budget notification evaluation failed: $error');
    }
  }

  Future<void> _emitBudgetLevel({
    required String name,
    required String nameVi,
    required String? category,
    required String period,
    required String periodKey,
    required int spent,
    required int limit,
    required int threshold,
    String? entityId,
  }) async {
    if (limit <= 0) return;
    final percent = spent * 100 / limit;
    if (percent < threshold) return;
    final exceeded = percent >= 100;
    final type = exceeded ? 'budget_exceeded' : 'budget_threshold';
    final notificationPayload = <String, dynamic>{
      'name': name,
      'name_vi': nameVi,
      'period': period,
      'spent': spent,
      'limit': limit,
      'remaining': (limit - spent).clamp(0, limit),
      'percent': percent.round(),
      'threshold': threshold,
    };
    if (category != null) notificationPayload['category'] = category;
    await NotificationService.instance.create(
      category: NotificationCategory.budget,
      type: type,
      priority: exceeded
          ? NotificationPriority.high
          : NotificationPriority.normal,
      actionRequired: exceeded,
      entityType: entityId == null ? 'budget' : 'category_budget',
      entityId: entityId,
      routeName: 'category_budgets',
      dedupeKey:
          'budget:${entityId ?? period}:$periodKey:${exceeded ? 'exceeded' : threshold}',
      payload: notificationPayload,
      body: '$spent / $limit VND',
    );
  }

  Future<void> clearAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('transactions')
        .delete()
        .eq('user_id', userId);
    _transactions = [];
    await GoalService.instance.fetchGoals();
    notifyListeners();
  }
}
