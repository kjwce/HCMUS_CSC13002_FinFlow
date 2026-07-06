import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'edit_transaction_screen.dart';

enum _HistoryFilter { all, income, expense }

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _incomeColor = Color(0xFF00513E);
  static const _expenseColor = Color(0xFFBA1A1A);

  _HistoryFilter _filter = _HistoryFilter.all;
  DateTimeRange? _dateRange;
  bool _isSavingWeeklyBudget = false;

  @override
  void initState() {
    super.initState();
    TransactionService.instance.addListener(_onDataChanged);
    WalletService.instance.addListener(_onDataChanged);
    Future.microtask(() {
      ref
          .read(transactionServiceProvider)
          .fetchTransactions()
          .catchError((e) => debugPrint('fetchTransactions error: $e'));
      ref
          .read(walletServiceProvider)
          .fetchWallets()
          .catchError((e) => debugPrint('fetchWallets error: $e'));
    });
  }

  @override
  void dispose() {
    TransactionService.instance.removeListener(_onDataChanged);
    WalletService.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    final visibleTransactions = _filteredTransactions(ts);
    final grouped = _groupByDay(visibleTransactions);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 20),
                  Responsive.h(context, 12),
                  Responsive.w(context, 20),
                  Responsive.h(context, 24),
                ),
                children: [
                  _buildFilterRow(),
                  SizedBox(height: Responsive.h(context, 14)),
                  _buildQuickInsights(ts),
                  SizedBox(height: Responsive.h(context, 18)),
                  _buildSectionTitle(visibleTransactions.length),
                  SizedBox(height: Responsive.h(context, 10)),
                  if (grouped.isEmpty)
                    _buildEmptyState()
                  else
                    ...grouped.entries.map(_buildDayGroup),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 0,
        onTabChanged: (index) => Navigator.of(context).pop(index),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 12),
        Responsive.h(context, 8),
        Responsive.w(context, 20),
        Responsive.h(context, 6),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.darkText,
          ),
          Expanded(
            child: Text(
              'Transaction History',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _headlineFont,
                fontSize: Responsive.sp(context, 22),
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _filterChip('All', _HistoryFilter.all)),
            SizedBox(width: Responsive.w(context, 8)),
            Expanded(child: _filterChip('Income', _HistoryFilter.income)),
            SizedBox(width: Responsive.w(context, 8)),
            Expanded(child: _filterChip('Expense', _HistoryFilter.expense)),
          ],
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDateRange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkText,
                  side: BorderSide(
                    color: _dateRange == null
                        ? AppColors.borderGray
                        : AppColors.primaryGreen,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 12),
                    vertical: Responsive.h(context, 12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.date_range_rounded,
                  size: Responsive.w(context, 18),
                ),
                label: Text(
                  _dateRangeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_dateRange != null) ...[
              SizedBox(width: Responsive.w(context, 8)),
              IconButton.filledTonal(
                tooltip: 'Clear date range',
                onPressed: () => setState(() => _dateRange = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _HistoryFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: Responsive.h(context, 42),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.borderGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 13),
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.darkText,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInsights(TransactionService ts) {
    return Row(
      children: [
        Expanded(child: _buildWeeklySpendingCard(ts)),
        SizedBox(width: Responsive.w(context, 12)),
        Expanded(child: _buildTopCategoryCard(ts)),
      ],
    );
  }

  Widget _buildWeeklySpendingCard(TransactionService ts) {
    final values = _weeklyExpenseValues(ts);
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final weeklyBudget = AuthService.instance.weeklyBudget;
    final hasBudget = weeklyBudget > 0;
    final budgetUsage = hasBudget ? total / weeklyBudget : 0.0;
    final progress = budgetUsage.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: AppColors.deepEmerald,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Spending',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 12),
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          SizedBox(height: Responsive.h(context, 6)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _formatMoneyCompact(total),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          if (hasBudget) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: Responsive.h(context, 5),
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: Responsive.h(context, 8)),
            Text(
              '${(budgetUsage * 100).clamp(0, 999).toStringAsFixed(0)}% of ${_formatMoneyCompact(weeklyBudget)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 10),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: Responsive.h(context, 32),
              child: OutlinedButton.icon(
                onPressed: _isSavingWeeklyBudget
                    ? null
                    : _showWeeklyBudgetDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: Icon(Icons.add_rounded, size: Responsive.w(context, 15)),
                label: Text(
                  'Set budget',
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopCategoryCard(TransactionService ts) {
    final category = _topMonthlyExpenseCategory(ts);
    final cat = TransactionCategory.fromKey(category?.key ?? 'Other');
    return _insightCard(
      title: 'Top Category',
      value: category == null ? 'No expense' : cat.label,
      leading: Container(
        width: Responsive.w(context, 38),
        height: Responsive.w(context, 38),
        decoration: BoxDecoration(
          color: cat.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          cat.icon,
          color: cat.color,
          size: Responsive.w(context, 20),
        ),
      ),
      child: Text(
        category == null
            ? 'This month is clear'
            : _formatMoneyCompact(category.value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: _bodyFont,
          fontSize: Responsive.sp(context, 12),
          color: AppColors.mutedGray,
        ),
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String value,
    required Widget child,
    Widget? leading,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: Responsive.w(context, 8)),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedGray,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 6)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 17),
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Transactions',
            style: TextStyle(
              fontFamily: _headlineFont,
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ),
        Text(
          '$count items',
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 12),
            fontWeight: FontWeight.w600,
            color: AppColors.mutedGray,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 34)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'No transactions match this filter.',
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 14),
            color: AppColors.mutedGray,
          ),
        ),
      ),
    );
  }

  Widget _buildDayGroup(MapEntry<DateTime, List<TransactionModel>> group) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(context, 8)),
            child: Text(
              _dayHeader(group.key),
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.borderGray.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: group.value.asMap().entries.map((entry) {
                return Column(
                  children: [
                    _buildTransactionRow(entry.value),
                    if (entry.key != group.value.length - 1)
                      Divider(
                        height: 1,
                        indent: Responsive.w(context, 68),
                        color: AppColors.borderGray.withValues(alpha: 0.25),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionModel tx) {
    final cat = TransactionCategory.fromKey(tx.category);
    final isIncome = tx.amount > 0;
    final wallet = WalletService.instance.byId(tx.walletId);
    final method = _walletLabel(wallet);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditTransactionScreen(transaction: tx),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 12),
          vertical: Responsive.h(context, 12),
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.w(context, 44),
              height: Responsive.w(context, 44),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                cat.icon,
                color: cat.color,
                size: Responsive.w(context, 22),
              ),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 3)),
                  Text(
                    '${_timeLabel(tx.date)} - $method',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueAccent,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 6)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 8),
                        vertical: Responsive.h(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 11),
                          fontWeight: FontWeight.w700,
                          color: cat.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(context, 10)),
            SizedBox(
              width: Responsive.w(context, 112),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatSignedMoney(tx.amount),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontSize: Responsive.sp(context, 14),
                      fontWeight: FontWeight.w800,
                      color: isIncome ? _incomeColor : _expenseColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _showWeeklyBudgetDialog() async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _WeeklyBudgetSheet(),
    );

    if (amount == null || !mounted) return;
    setState(() => _isSavingWeeklyBudget = true);
    try {
      final user = AuthService.instance.currentUser;
      await AuthService.instance.updateProfile(
        fullName: user?.fullName ?? 'New FinFlow User',
        weeklyBudget: amount,
      );
      if (!mounted) return;
      setState(() => _isSavingWeeklyBudget = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingWeeklyBudget = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save weekly budget: $e')),
      );
    }
  }

  List<TransactionModel> _filteredTransactions(TransactionService ts) {
    final txs = ts.currentUserTransactions.where((tx) {
      final typeMatch = switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.income => tx.amount > 0,
        _HistoryFilter.expense => tx.amount < 0,
      };
      if (!typeMatch) return false;
      final range = _dateRange;
      if (range == null) return true;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();
    txs.sort((a, b) => b.date.compareTo(a.date));
    return txs;
  }

  Map<DateTime, List<TransactionModel>> _groupByDay(
    List<TransactionModel> txs,
  ) {
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    return grouped;
  }

  List<int> _weeklyExpenseValues(TransactionService ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final values = List<int>.filled(7, 0);
    for (final tx in ts.currentUserTransactions) {
      if (tx.amount >= 0) continue;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final diff = day.difference(monday).inDays;
      if (diff >= 0 && diff < 7) {
        values[diff] += tx.amount.abs();
      }
    }
    return values;
  }

  MapEntry<String, int>? _topMonthlyExpenseCategory(TransactionService ts) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final map = ts.expenseByCategoryBetween(start, end);
    if (map.isEmpty) return null;
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  String _dateRangeLabel() {
    final range = _dateRange;
    if (range == null) return 'Date range';
    return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
  }

  String _dayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${_monthName(day.month)} ${day.day}, ${day.year}';
  }

  String _walletLabel(WalletModel? wallet) {
    if (wallet == null) return 'Transfer';
    return wallet.shortName.isNotEmpty ? wallet.shortName : wallet.name;
  }

  static String _formatSignedMoney(int amount) {
    final sign = amount < 0 ? '-' : '+';
    return '$sign ${_formatMoney(amount.abs())}';
  }

  static String _formatMoney(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$text VND';
  }

  static String _addCommas(String digits) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _formatMoneyCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B VND';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M VND';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K VND';
    }
    return '$amount VND';
  }

  static String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _shortDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _WeeklyBudgetSheet extends StatefulWidget {
  const _WeeklyBudgetSheet();

  @override
  State<_WeeklyBudgetSheet> createState() => _WeeklyBudgetSheetState();
}

class _WeeklyBudgetSheetState extends State<_WeeklyBudgetSheet> {
  final _controller = TextEditingController();
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_formatAmount);
  }

  @override
  void dispose() {
    _controller.removeListener(_formatAmount);
    _controller.dispose();
    super.dispose();
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _controller.text = '';
    } else {
      final formatted = _TransactionHistoryScreenState._addCommas(digits);
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _isFormatting = false;
  }

  void _save() {
    final raw = _controller.text.replaceAll(',', '');
    final value = int.tryParse(raw);
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Responsive.w(context, 20),
          right: Responsive.w(context, 20),
          top: Responsive.h(context, 20),
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              Responsive.h(context, 20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set weekly budget',
                style: TextStyle(
                  fontFamily: _TransactionHistoryScreenState._headlineFont,
                  fontSize: Responsive.sp(context, 18),
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 16)),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weekly budget',
                  suffixText: 'VND',
                ),
                onSubmitted: (_) => _save(),
              ),
              SizedBox(height: Responsive.h(context, 18)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 10)),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
