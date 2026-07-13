import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/notification_bell.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/finance/models/transaction_category.dart';
import '../../features/finance/models/transaction_model.dart';
import '../../features/finance/models/quick_add_draft_model.dart';
import '../../features/finance/presentation/add_transaction_sheet.dart';
import '../../features/finance/presentation/dashboard_page.dart';
import '../../features/finance/presentation/edit_transaction_screen.dart';
import '../../features/finance/presentation/goal_setup_sheet.dart';
import '../../features/finance/presentation/quick_add_review_sheet.dart';
import '../../features/finance/presentation/transaction_saved_screen.dart';
import '../../features/finance/presentation/widgets/quick_add_card.dart';
import '../../features/finance/presentation/transaction_history_screen.dart';
import '../../features/finance/providers/goal_provider.dart';
import '../../features/finance/providers/transaction_provider.dart';
import '../../features/finance/providers/wallet_provider.dart';
import '../../features/finance/services/goal_service.dart';
import '../../features/finance/services/quick_add_service.dart';
import '../../features/finance/services/quick_add_speech_recognition_service.dart';
import '../../features/finance/services/transaction_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onAddTap, this.onTabChanged});

  final VoidCallback? onAddTap;
  final ValueChanged<int>? onTabChanged;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _incomeColor = Color(0xFF00513E);
  static const _expenseColor = Color(0xFFBA1A1A);

  int _selectedTab = 2; // Monthly
  var _summaryMetric = _SummaryMetric.revenue;
  var _summaryPeriod = _SummaryPeriod.week;
  final _quickAddController = TextEditingController();
  var _isQuickAddParsing = false;
  var _isQuickAddReviewOpen = false;
  var _voiceState = _QuickAddVoiceState.idle;
  var _voiceSession = 0;
  var _voiceFinalHandled = false;
  var _latestVoiceTranscript = '';
  Timer? _voiceTimeout;

  bool get _isVoiceRecording => _voiceState == _QuickAddVoiceState.listening;
  bool get _isVoiceProcessing =>
      _voiceState == _QuickAddVoiceState.initializing ||
      _voiceState == _QuickAddVoiceState.processingFinal;

  @override
  void initState() {
    super.initState();
    // TransactionService is a ChangeNotifier but uses a plain Provider,
    // so we subscribe manually to rebuild the UI after data loads.
    TransactionService.instance.addListener(_onTransactionsChanged);
    GoalService.instance.addListener(_onTransactionsChanged);
    Future.microtask(() {
      ref
          .read(transactionServiceProvider)
          .fetchTransactions()
          .catchError((e) => debugPrint('fetchTransactions error: $e'));
    });
    Future.microtask(() {
      ref
          .read(goalServiceProvider)
          .fetchGoals()
          .catchError((e) => debugPrint('fetchGoals error: $e'));
    });
    Future.microtask(() {
      ref
          .read(walletServiceProvider)
          .fetchWallets()
          .catchError((e) => debugPrint('fetchWallets error: $e'));
    });
  }

  @override
  void dispose() {
    TransactionService.instance.removeListener(_onTransactionsChanged);
    GoalService.instance.removeListener(_onTransactionsChanged);
    _voiceTimeout?.cancel();
    if (_voiceState != _QuickAddVoiceState.idle) {
      unawaited(QuickAddSpeechRecognitionService.instance.cancelListening());
    }
    _quickAddController.dispose();
    super.dispose();
  }

  void _onTransactionsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    final showViewAll = _transactionsForSelectedTab(ts).isNotEmpty;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _buildHeaderAndBalance(ts),
              Transform.translate(
                offset: Offset(0, -Responsive.h(context, 18)),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.finFlowColors.pageBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(Responsive.w(context, 42)),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 20),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: Responsive.h(context, 14)),
                        _buildGoalSummaryCard(),
                        SizedBox(height: Responsive.h(context, 25)),
                        _buildPeriodTabs(),
                        SizedBox(height: Responsive.h(context, 25)),
                        _buildQuickAddCard(),
                        SizedBox(height: Responsive.h(context, 25)),
                        _buildTransactionList(ts),
                        SizedBox(height: Responsive.h(context, 150)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showViewAll)
          Positioned(
            left: 0,
            right: 0,
            bottom: Responsive.h(context, 18),
            child: Center(child: _buildViewAllButton()),
          ),
      ],
    );
  }

  // --- 1. Header + Balance Card đè lên ảnh ---
  Widget _buildHeaderAndBalance(TransactionService ts) {
    return SizedBox(
      height: Responsive.h(context, 275),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Image
          Container(
            height: Responsive.h(context, 292),
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/home_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 20),
                  vertical: Responsive.h(context, 10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.welcomeBack,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _headlineFont,
                              fontSize: Responsive.sp(context, 20),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF052224),
                            ),
                          ),
                          SizedBox(height: Responsive.h(context, 4)),
                          Text(
                            _greeting(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _bodyFont,
                              fontSize: Responsive.sp(context, 14),
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF052224),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Chart icon — pushes to DashboardPage
                        _PressableScale(
                          onTap: _navigateToDashboard,
                          child: Container(
                            width: Responsive.w(context, 36),
                            height: Responsive.h(context, 36),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDFF7E2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: Responsive.w(context, 19),
                                height: Responsive.h(context, 16),
                                child: SvgPicture.asset(
                                  'assets/icons/chart.svg',
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF093030),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(context, 8)),
                        const NotificationBell(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Balance Card
          Positioned(
            top: Responsive.h(context, 72),
            left: Responsive.w(context, 20),
            right: Responsive.w(context, 20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 20),
                vertical: Responsive.h(context, 14),
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildBalanceItem(
                        AppStrings.totalBalance,
                        '+${_formatMoney(ts.totalBalance)}',
                        Icons.north_east,
                        _incomeColor,
                        fontWeight: FontWeight.w700,
                      ),
                      Container(
                        width: 1,
                        height: Responsive.h(context, 40),
                        color: Colors.white.withValues(alpha: 1.2),
                      ),
                      _buildBalanceItem(
                        AppStrings.totalExpenseLabel,
                        '-${_formatMoney(ts.monthlyExpense)}',
                        Icons.south_west,
                        _expenseColor,
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(context, 12)),
                  // Progress Bar
                  _buildProgressBar(ts),
                  SizedBox(height: Responsive.h(context, 8)),
                  _buildExpenseMessage(ts),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(TransactionService ts) {
    final authService = ref.watch(authServiceProvider);
    final budgetLimit = authService.currentUser?.budgetLimit ?? 0;
    final budgetRatio = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit).clamp(0.0, 1.0)
        : 0.0;
    final rawPercent = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit) * 100
        : 0.0;
    final displayPercent = (rawPercent.clamp(0.0, 100.0) * 10).round() / 10;
    final progressColor = budgetLimit > 0 && rawPercent >= 100
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF00C49A);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly budget',
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF052224),
                ),
              ),
              Text(
                '${displayPercent.toStringAsFixed(0)}% used',
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF052224),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: Responsive.h(context, 8),
              child: Stack(
                children: [
                  Container(color: Colors.white),
                  FractionallySizedBox(
                    widthFactor: budgetRatio,
                    child: Container(color: progressColor),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_formatMoney(ts.monthlyExpense)} spent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF052224),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Text(
                  budgetLimit > 0
                      ? '${_formatMoney(budgetLimit)} limit'
                      : 'No limit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF052224),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseMessage(TransactionService ts) {
    final authService = ref.watch(authServiceProvider);
    final budgetLimit = authService.currentUser?.budgetLimit ?? 0;
    final rawPercent = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit) * 100
        : 0.0;
    final displayPercent = (rawPercent.clamp(0.0, 100.0) * 10).round() / 10;

    return Row(
      children: [
        Icon(
          budgetLimit <= 0
              ? Icons.info_outline
              : (rawPercent > 100
                    ? Icons.warning_amber
                    : Icons.check_box_outlined),
          size: Responsive.sp(context, 14),
          color: budgetLimit <= 0
              ? Colors.grey
              : (rawPercent > 100 ? Colors.red : Colors.black54),
        ),
        SizedBox(width: Responsive.w(context, 8)),
        Expanded(
          child: Text(
            budgetLimit <= 0
                ? 'Set a budget limit in Settings to track your spending.'
                : (rawPercent > 100
                      ? 'Over budget — consider adjusting your spending!'
                      : '$displayPercent% Of Your Expenses, Looks Good.'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 12),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF052224),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceItem(
    String title,
    String amount,
    IconData icon,
    Color amountColor, {
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: Responsive.sp(context, 14),
                color: Colors.black54,
              ),
              SizedBox(width: Responsive.w(context, 4)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF093030),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 4)),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                amount,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 24),
                  fontWeight: fontWeight,
                  color: amountColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Goal Summary Card ---
  Widget _buildGoalSummaryCard() {
    final gs = ref.watch(goalServiceProvider);
    final goal = gs.activeGoal;
    final ts = ref.watch(transactionServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final selectedCategory = authService.selectedCategory;
    final progress = goal != null ? gs.progressRatio(ts.totalBalance) : 0.0;

    // Computed values
    final metricRange = _summaryDateRange(_summaryPeriod);
    final metricAmount = _summaryMetric == _SummaryMetric.revenue
        ? ts.incomeBetween(metricRange.start, metricRange.end)
        : ts.expenseBetween(metricRange.start, metricRange.end);
    final metricColor = _summaryMetric == _SummaryMetric.revenue
        ? _incomeColor
        : _expenseColor;
    final metricTitle = '${_summaryMetric.label} Last ${_summaryPeriod.label}';
    final metricAmountText =
        '${_summaryMetric == _SummaryMetric.revenue ? '+' : '-'}${_formatMoney(metricAmount)}';
    final categoryExpense = selectedCategory != null
        ? ts.categoryExpenseLast7Days(selectedCategory)
        : 0;

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 20)),
      decoration: BoxDecoration(
        color: const Color(0xFF00D293),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _PressableScale(
            onTap: () => GoalSetupSheet.show(context),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: Responsive.w(context, 60),
                      height: Responsive.w(context, 60),
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        color: const Color(0xFF007AFF),
                        backgroundColor: Colors.white30,
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/home/flag.svg',
                      width: Responsive.w(context, 28),
                      height: Responsive.w(context, 28),
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF093030),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 8)),
                if (goal != null) ...[
                  Text(
                    'Saving Goal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 11),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF052224),
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 2)),
                ],
                Text(
                  goal != null
                      ? '${(progress * 100).toStringAsFixed(0)}%'
                      : 'Savings\nOn Goals',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF093030),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 15),
            ),
            child: SizedBox(
              height: Responsive.h(context, 80),
              child: const VerticalDivider(color: Colors.white54),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildSummaryRow(
                  _FigmaWalletIcon(
                    color: const Color(0xFF052224),
                    size: Responsive.w(context, 22),
                  ),
                  metricTitle,
                  metricAmountText,
                  metricColor,
                  onTap: _showSummaryMetricPicker,
                  showChevron: true,
                ),
                const Divider(color: Colors.white54),
                _buildCategoryRow(selectedCategory, categoryExpense),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _DateRange _summaryDateRange(_SummaryPeriod period) {
    final now = DateTime.now();
    final start = switch (period) {
      _SummaryPeriod.day => now.subtract(const Duration(days: 1)),
      _SummaryPeriod.week => now.subtract(const Duration(days: 7)),
      _SummaryPeriod.month => now.subtract(const Duration(days: 30)),
      _SummaryPeriod.year => now.subtract(const Duration(days: 365)),
    };
    return _DateRange(start, now);
  }

  void _showSummaryMetricPicker() {
    var selectedMetric = _summaryMetric;
    var selectedPeriod = _summaryPeriod;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.w(context, 20)),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.h(context, 20),
                horizontal: Responsive.w(context, 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose summary',
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontSize: Responsive.sp(context, 16),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003829),
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 16)),
                  _buildPickerSection(
                    title: 'Type',
                    children: _SummaryMetric.values.map((metric) {
                      return _buildPickerChip(
                        label: metric.label,
                        selected: selectedMetric == metric,
                        color: metric == _SummaryMetric.revenue
                            ? _incomeColor
                            : _expenseColor,
                        onTap: () => setSheetState(() {
                          selectedMetric = metric;
                        }),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: Responsive.h(context, 16)),
                  _buildPickerSection(
                    title: 'Period',
                    children: _SummaryPeriod.values.map((period) {
                      return _buildPickerChip(
                        label: 'Last ${period.label}',
                        selected: selectedPeriod == period,
                        color: const Color(0xFF00A37A),
                        onTap: () => setSheetState(() {
                          selectedPeriod = period;
                        }),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: Responsive.h(context, 20)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00513E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.h(context, 14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _summaryMetric = selectedMetric;
                          _summaryPeriod = selectedPeriod;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.sp(context, 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPickerSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 12),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF052224),
          ),
        ),
        SizedBox(height: Responsive.h(context, 8)),
        Wrap(
          spacing: Responsive.w(context, 8),
          runSpacing: Responsive.h(context, 8),
          children: children,
        ),
      ],
    );
  }

  Widget _buildPickerChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 14),
          vertical: Responsive.h(context, 10),
        ),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF3F5F4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : const Color(0xFFBBCCC5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 13),
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF052224),
          ),
        ),
      ),
    );
  }

  /// Build the dynamic category row (formerly hardcoded "Food Last Week").
  Widget _buildCategoryRow(String? selectedCategory, int expense) {
    final label = selectedCategory ?? 'Select category';
    final amount = selectedCategory != null
        ? '${expense > 0 ? '-' : ''}${_formatMoney(expense)}'
        : '—';
    final color = selectedCategory != null
        ? const Color(0xFF0068FF)
        : Colors.black38;

    return _PressableScale(
      onTap: () => _showCategoryPicker(selectedCategory),
      child: Row(
        children: [
          SizedBox(
            width: Responsive.w(context, 24),
            height: Responsive.w(context, 24),
            child: selectedCategory != null
                ? Icon(
                    _iconForCategory(selectedCategory),
                    size: Responsive.w(context, 22),
                    color: const Color(0xFF0068FF),
                  )
                : const Icon(
                    Icons.category_outlined,
                    size: 22,
                    color: Colors.black38,
                  ),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      selectedCategory != null
                          ? '$selectedCategory Last Week'
                          : label,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 12),
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF052224),
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 4)),
                    Icon(
                      Icons.expand_more,
                      size: Responsive.w(context, 16),
                      color: color,
                    ),
                  ],
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 15),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show a bottom sheet with all categories for the user to pick from.
  void _showCategoryPicker(String? currentSelected) {
    // Build full category list: 14 built-in + custom
    final builtIn = TransactionCategory.all;
    final custom = CustomCategoryStore.instance.items.map(
      (c) => TransactionCategory(
        key: c.name,
        label: c.name,
        icon: c.iconData,
        color: c.color,
      ),
    );
    final allCategories = [...builtIn, ...custom];

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.w(context, 20)),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.h(context, 20),
            horizontal: Responsive.w(context, 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: Responsive.w(context, 8),
                  bottom: Responsive.h(context, 12),
                ),
                child: Text(
                  'Select category to track',
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF003829),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: Responsive.h(context, 320),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: Responsive.w(context, 12),
                    runSpacing: Responsive.h(context, 12),
                    children: allCategories.map((cat) {
                      final isSelected = currentSelected == cat.key;
                      return _PressableScale(
                        onTap: () {
                          AuthService.instance.saveSelectedCategory(cat.key);
                          Navigator.of(ctx).pop();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: Responsive.w(context, 50),
                              height: Responsive.w(context, 50),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? cat.color
                                      : cat.color.withValues(alpha: 0.5),
                                  width: isSelected ? 3 : 2,
                                ),
                                color: isSelected
                                    ? cat.color.withValues(alpha: 0.1)
                                    : const Color(0xFFF5F5F5),
                              ),
                              child: Icon(
                                cat.icon,
                                color: isSelected
                                    ? cat.color
                                    : cat.color.withValues(alpha: 0.7),
                                size: Responsive.w(context, 22),
                              ),
                            ),
                            SizedBox(height: Responsive.h(context, 4)),
                            SizedBox(
                              width: Responsive.w(context, 56),
                              child: Text(
                                cat.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.sp(context, 10),
                                  color: const Color(0xFF052224),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    Widget icon,
    String title,
    String amount,
    Color color, {
    VoidCallback? onTap,
    bool showChevron = false,
  }) {
    final row = Row(
      children: [
        SizedBox(
          width: Responsive.w(context, 24),
          height: Responsive.w(context, 24),
          child: icon,
        ),
        SizedBox(width: Responsive.w(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 12),
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF052224),
                      ),
                    ),
                  ),
                  if (showChevron) ...[
                    SizedBox(width: Responsive.w(context, 4)),
                    Icon(
                      Icons.expand_more,
                      size: Responsive.w(context, 16),
                      color: color,
                    ),
                  ],
                ],
              ),
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 15),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return _PressableScale(onTap: onTap, child: row);
  }

  // --- 3. Tabs Daily/Weekly/Monthly ---
  Widget _buildPeriodTabs() {
    final labels = ['Daily', 'Weekly', 'Monthly'];

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 6)),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F3E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;

          return SizedBox(
            height: Responsive.h(context, 44),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: tabWidth * _selectedTab,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D293),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                Row(
                  children: labels.asMap().entries.map((entry) {
                    return Expanded(
                      child: _PressableScale(
                        onTap: () => setState(() => _selectedTab = entry.key),
                        child: Center(
                          child: Text(
                            entry.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _bodyFont,
                              fontSize: Responsive.sp(context, 15),
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF052224),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAddCard() => QuickAddCard(
    controller: _quickAddController,
    isLoading: _isQuickAddParsing,
    isRecording: _isVoiceRecording,
    isVoiceProcessing: _isVoiceProcessing,
    onSubmit: _submitQuickAdd,
    onVoiceTap: _handleVoiceTap,
  );

  Future<void> _handleVoiceTap() async {
    if (_isQuickAddParsing || _isQuickAddReviewOpen || _isVoiceProcessing) {
      return;
    }
    if (_isVoiceRecording) {
      await _stopVoiceListening();
      return;
    }

    final session = ++_voiceSession;
    _voiceFinalHandled = false;
    _latestVoiceTranscript = '';
    setState(() => _voiceState = _QuickAddVoiceState.initializing);
    try {
      final speech = QuickAddSpeechRecognitionService.instance;
      final available = await speech.initialize(
        onStatus: (status) => _handleVoiceStatus(session, status),
        onError: (error) => _handleVoiceError(session, error),
      );
      if (!mounted || session != _voiceSession) return;
      if (!available) {
        throw const QuickAddSpeechException(
          'RECOGNIZER_UNAVAILABLE',
          'Speech recognition is unavailable.',
        );
      }
      if (!speech.usesVietnameseLocale) {
        _showQuickAddMessage(
          AppLanguage.instance.locale == AppLocale.vietnamese
              ? 'Không có nhận diện tiếng Việt; đang dùng ngôn ngữ hệ thống.'
              : 'Vietnamese recognition is unavailable; using system locale.',
        );
      }
      await speech.startListening(
        onResult: (result) => _handleVoiceResult(session, result),
      );
      if (!mounted || session != _voiceSession) {
        await speech.cancelListening();
        return;
      }
      setState(() => _voiceState = _QuickAddVoiceState.listening);
      _voiceTimeout?.cancel();
      _voiceTimeout = Timer(
        const Duration(seconds: 30),
        () => _finishVoiceAfterStop(session, timedOut: true),
      );
    } on QuickAddSpeechException catch (error) {
      _showVoiceErrorIfCurrent(session, error.code);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_UNAVAILABLE');
    }
  }

  void _handleVoiceResult(int session, QuickAddSpeechResult result) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final transcript = result.text.trim();
    if (transcript.isNotEmpty) {
      _latestVoiceTranscript = transcript;
      _quickAddController.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(offset: transcript.length),
      );
    }
    if (result.isFinal) {
      unawaited(_submitFinalVoiceTranscript(session, transcript));
    }
  }

  void _handleVoiceStatus(int session, String status) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final normalized = status.toLowerCase();
    if (normalized == 'done' || normalized == 'notlistening') {
      _voiceTimeout?.cancel();
      _voiceTimeout = Timer(
        const Duration(milliseconds: 300),
        () => _submitFinalVoiceTranscript(session, _latestVoiceTranscript),
      );
    }
  }

  void _handleVoiceError(int session, QuickAddSpeechException error) {
    _showVoiceErrorIfCurrent(session, error.code);
  }

  Future<void> _stopVoiceListening() async {
    if (!_isVoiceRecording || _isVoiceProcessing) return;
    final session = _voiceSession;
    _voiceTimeout?.cancel();
    setState(() => _voiceState = _QuickAddVoiceState.processingFinal);
    try {
      await QuickAddSpeechRecognitionService.instance.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _submitFinalVoiceTranscript(session, _latestVoiceTranscript);
    } on QuickAddSpeechException catch (error) {
      _showVoiceErrorIfCurrent(session, error.code);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_ERROR');
    }
  }

  Future<void> _finishVoiceAfterStop(
    int session, {
    required bool timedOut,
  }) async {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    setState(() => _voiceState = _QuickAddVoiceState.processingFinal);
    try {
      await QuickAddSpeechRecognitionService.instance.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_latestVoiceTranscript.trim().isEmpty && timedOut) {
        _showVoiceErrorIfCurrent(session, 'RECOGNITION_TIMEOUT');
        return;
      }
      await _submitFinalVoiceTranscript(session, _latestVoiceTranscript);
    } catch (_) {
      _showVoiceErrorIfCurrent(session, 'RECOGNIZER_ERROR');
    }
  }

  Future<void> _submitFinalVoiceTranscript(int session, String value) async {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    final transcript = value.trim();
    if (transcript.isEmpty) {
      _showVoiceErrorIfCurrent(session, 'EMPTY_TRANSCRIPT');
      return;
    }
    _voiceFinalHandled = true;
    _voiceTimeout?.cancel();
    _quickAddController.value = TextEditingValue(
      text: transcript,
      selection: TextSelection.collapsed(offset: transcript.length),
    );
    setState(() => _voiceState = _QuickAddVoiceState.processingFinal);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || session != _voiceSession) return;
    setState(() => _voiceState = _QuickAddVoiceState.parsing);
    await _submitQuickAdd(transcript);
  }

  void _showVoiceErrorIfCurrent(int session, String code) {
    if (!mounted || session != _voiceSession || _voiceFinalHandled) return;
    _voiceFinalHandled = true;
    _voiceTimeout?.cancel();
    setState(() => _voiceState = _QuickAddVoiceState.error);
    _showQuickAddMessage(_localizedVoiceError(code));
    if (mounted && session == _voiceSession) {
      setState(() => _voiceState = _QuickAddVoiceState.idle);
    }
  }

  String _localizedVoiceError(String code) {
    final vi = AppLanguage.instance.locale == AppLocale.vietnamese;
    return switch (code) {
      'MICROPHONE_PERMISSION_DENIED' || 'error_permission' =>
        vi
            ? 'Cần quyền microphone để nhập giao dịch bằng giọng nói.'
            : 'Microphone permission is required for voice Quick Add.',
      'EMPTY_TRANSCRIPT' || 'error_no_match' =>
        vi
            ? 'Không nhận diện được nội dung giọng nói.'
            : 'No speech could be recognized.',
      'RECOGNITION_TIMEOUT' || 'error_speech_timeout' =>
        vi
            ? 'Không nhận diện được giọng nói trong thời gian cho phép.'
            : 'No speech was recognized before the timeout.',
      'RECOGNIZER_UNAVAILABLE' =>
        vi
            ? 'Thiết bị không có dịch vụ nhận diện giọng nói khả dụng.'
            : 'Speech recognition is unavailable on this device.',
      _ =>
        vi
            ? 'Nhận diện giọng nói hiện không khả dụng. Vui lòng thử lại.'
            : 'Speech recognition is unavailable. Please try again.',
    };
  }

  Future<void> _submitQuickAdd(String input) async {
    if (_isQuickAddParsing ||
        _isQuickAddReviewOpen ||
        _isVoiceRecording ||
        _isVoiceProcessing) {
      return;
    }
    final text = input.trim();
    if (text.isEmpty) {
      _showQuickAddMessage(
        AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Vui lòng nhập nội dung giao dịch.'
            : 'Please enter a transaction.',
      );
      return;
    }

    setState(() => _isQuickAddParsing = true);
    try {
      final draft = await QuickAddService.instance.parse(text);
      if (!mounted) return;
      setState(() {
        _isQuickAddParsing = false;
        _isQuickAddReviewOpen = true;
        if (_voiceState == _QuickAddVoiceState.parsing) {
          _voiceState = _QuickAddVoiceState.idle;
        }
      });
      final action = await QuickAddReviewSheet.show(
        context,
        draft: draft,
        onConfirm: () => _confirmQuickAdd(draft),
      );
      if (!mounted) return;
      _isQuickAddReviewOpen = false;

      if (action == QuickAddReviewAction.confirmed) {
        _quickAddController.clear();
        if (!mounted) return;
        // Reconstruct from draft for the saved screen (already saved by _confirmQuickAdd)
        final userId = ref.read(authServiceProvider).currentUser?.id;
        final savedTx = draft.toTransactionModel(
          id: 't_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId ?? '',
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionSavedScreen(transaction: savedTx),
          ),
        );
      } else if (action == QuickAddReviewAction.editDetails) {
        final saved = await _openQuickAddDetails(draft);
        if (!mounted) return;
        if (saved == true) {
          _quickAddController.clear();
        }
      }
    } on QuickAddException catch (error) {
      if (!mounted) return;
      _showQuickAddMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showQuickAddMessage(
        AppLanguage.instance.locale == AppLocale.vietnamese
            ? 'Không thể phân tích giao dịch lúc này.'
            : 'Unable to parse the transaction right now.',
      );
    } finally {
      if (mounted &&
          (_isQuickAddParsing || _voiceState == _QuickAddVoiceState.parsing)) {
        setState(() {
          _isQuickAddParsing = false;
          if (_voiceState == _QuickAddVoiceState.parsing) {
            _voiceState = _QuickAddVoiceState.idle;
          }
        });
      }
    }
  }

  Future<void> _confirmQuickAdd(QuickAddDraft draft) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    final transaction = draft.toTransactionModel(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
    );
    await ref.read(transactionServiceProvider).add(transaction);
  }

  Future<bool?> _openQuickAddDetails(QuickAddDraft draft) {
    return AddTransactionSheet.show(
      context,
      initialIsExpense: draft.type == QuickAddTransactionType.expense,
      initialAmount: draft.amount,
      initialName: draft.name,
      initialCategoryKey: draft.categoryKey,
      initialWalletId: draft.walletId,
      initialDate: draft.date,
      fromQuickAdd: true,
    );
  }

  void _showQuickAddMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static const _months = [
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

  // --- 4. Transaction List ---
  Widget _buildTransactionList(TransactionService ts) {
    final visibleTransactions = _transactionsForSelectedTab(ts);
    final emptyMessage = switch (_selectedTab) {
      0 => 'No transactions today.\nTap "Add" to record one.',
      1 => 'No transactions this week.\nTap "Add" to record one.',
      _ => 'No transactions this month.\nTap "Add" to record one.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: Recent transactions + Add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent transactions',
              style: TextStyle(
                fontFamily: _headlineFont,
                fontSize: Responsive.sp(context, 16),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF052224),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onAddTap,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 14),
                  vertical: Responsive.h(context, 9),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              icon: Icon(Icons.add_rounded, size: Responsive.w(context, 18)),
              label: Text(
                'Add',
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(context, 12)),
        if (visibleTransactions.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 20)),
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Column(
            children: visibleTransactions.map((t) {
              return Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(context, 15)),
                child: _PressableScale(
                  pressedOverlayColor: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditTransactionScreen(transaction: t),
                    ),
                  ),
                  child: _buildTransactionItem(
                    _iconForCategory(t.category),
                    t.name,
                    _formatTransactionTime(t.date),
                    t.category,
                    _formatSignedMoney(t.amount),
                    _iconColorForCategory(t.category),
                    t.amount > 0,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildViewAllButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _navigateToTransactionHistory,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 9),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF00C49A).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: Responsive.w(context, 5)),
              Icon(
                Icons.arrow_forward_rounded,
                size: Responsive.w(context, 15),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TransactionModel> _transactionsForSelectedTab(TransactionService ts) {
    final period = switch (_selectedTab) {
      0 => ChartPeriod.day,
      1 => ChartPeriod.week,
      _ => ChartPeriod.month,
    };
    return ts.transactionsForPeriod(period);
  }

  Widget _buildTransactionItem(
    IconData icon,
    String title,
    String date,
    String category,
    String amount,
    Color iconBg,
    bool isIncome,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 6),
        vertical: Responsive.h(context, 4),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.w(context, 12)),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          SizedBox(width: Responsive.w(context, 15)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 15),
                    color: const Color(0xFF052224),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    color: const Color(0xFF0068FF),
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: Responsive.w(context, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amount,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontWeight: FontWeight.w500,
                        fontSize: Responsive.sp(context, 15),
                        color: isIncome ? _incomeColor : _expenseColor,
                      ),
                    ),
                  ),
                ),
                if (category.isNotEmpty) ...[
                  SizedBox(height: Responsive.h(context, 4)),
                  Text(
                    category,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontWeight: FontWeight.w300,
                      fontSize: Responsive.sp(context, 13),
                      color: const Color(0xFF052224),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForCategory(String category) {
    final custom = CustomCategoryStore.instance.findByKey(category);
    if (custom != null) return custom.iconData;
    return TransactionCategory.fromKey(category).icon;
  }

  static Color _iconColorForCategory(String category) =>
      TransactionCategory.fromKey(category).color;

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

  static String _formatTransactionTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    return '$h:$m - $month ${dt.day}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.greetingMorning;
    if (hour < 18) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }

  /// Navigate to DashboardPage with a right-to-left slide transition.
  void _navigateToDashboard() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _navigateToTransactionHistory() async {
    final tabIndex = await Navigator.of(context).push<int>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TransactionHistoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (!mounted || tabIndex == null) return;
    widget.onTabChanged?.call(tabIndex);
  }
}

// =============================================================================
// Figma home icons (car, wallet, food) as CustomPaint
// =============================================================================

class _FigmaWalletIcon extends StatelessWidget {
  const _FigmaWalletIcon({
    this.color = const Color(0xFF093030),
    this.size = 22,
  });
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.93),
      painter: _HomeIconPainter(
        color: color,
        path: (Canvas canvas, Size size, Paint paint) {
          final sc = size.shortestSide / 28;
          canvas.save();
          canvas.scale(sc);
          final p = Path()
            ..moveTo(21.6682, 14.3281)
            ..lineTo(12.8841, 19.9656)
            ..cubicTo(12.7171, 20.0728, 12.5042, 20.0774, 12.3328, 19.9775)
            ..lineTo(1.31931, 13.5628)
            ..cubicTo(0.978071, 13.3641, 0.967569, 12.8749, 1.29997, 12.6617)
            ..lineTo(19.2617, 1.14022)
            ..cubicTo(19.4286, 1.03318, 19.6414, 1.02858, 19.8127, 1.1283)
            ..lineTo(30.826, 7.53796)
            ..cubicTo(31.1674, 7.73662, 31.178, 8.22591, 30.8456, 8.4392)
            ..lineTo(25.6599, 11.7665)
            ..moveTo(21.6735, 18.8056)
            ..lineTo(12.8839, 24.4432)
            ..cubicTo(12.717, 24.5503, 12.5043, 24.5549, 12.333, 24.4551)
            ..lineTo(1.31917, 18.0452)
            ..cubicTo(0.977933, 17.8466, 0.967187, 17.3575, 1.29938, 17.1441)
            ..lineTo(4.2337, 15.2591)
            ..moveTo(27.912, 10.3243)
            ..lineTo(30.8258, 12.0205)
            ..cubicTo(31.1672, 12.2192, 31.1777, 12.7087, 30.8451, 12.9219)
            ..lineTo(25.6119, 16.2763)
            ..moveTo(28.1254, 14.6618)
            ..lineTo(30.8608, 16.357)
            ..cubicTo(31.1911, 16.5617, 31.1948, 17.0408, 30.8678, 17.2507)
            ..lineTo(12.8841, 28.7913)
            ..cubicTo(12.7171, 28.8985, 12.5042, 28.903, 12.3328, 28.8032)
            ..lineTo(1.31931, 22.3885)
            ..cubicTo(0.978067, 22.1898, 0.967564, 21.7005, 1.29996, 21.4873)
            ..lineTo(4.12163, 19.6774)
            ..moveTo(13.8573, 4.94937)
            ..lineTo(25.3494, 11.6406)
            ..cubicTo(25.5119, 11.7352, 25.6119, 11.9091, 25.6119, 12.0972)
            ..lineTo(25.6119, 20.3306)
            ..cubicTo(25.6119, 20.5104, 25.5204, 20.6779, 25.3691, 20.7751)
            ..lineTo(22.4873, 22.6258)
            ..cubicTo(22.1357, 22.8516, 21.6735, 22.5992, 21.6735, 22.1813)
            ..lineTo(21.6735, 14.6318)
            ..cubicTo(21.6735, 14.4438, 21.5736, 14.2699, 21.4112, 14.1753)
            ..lineTo(10.3854, 7.7506)
            ..cubicTo(10.0443, 7.55186, 10.0338, 7.06291, 10.3659, 6.84961)
            ..lineTo(13.306, 4.96139)
            ..cubicTo(13.473, 4.85419, 13.6859, 4.84954, 13.8573, 4.94937)
            ..close();
          canvas.drawPath(p, paint);
          canvas.restore();
        },
      ),
    );
  }
}

class _HomeIconPainter extends CustomPainter {
  const _HomeIconPainter({required this.color, required this.path});
  final Color color;
  final void Function(Canvas canvas, Size size, Paint paint) path;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    path(canvas, size, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeIconPainter oldDelegate) => false;
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.pressedOverlayColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? pressedOverlayColor;
  final BorderRadius? borderRadius;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.82 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: _pressed
                          ? widget.pressedOverlayColor
                          : Colors.transparent,
                      borderRadius: widget.borderRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SummaryMetric {
  revenue('Revenue'),
  expense('Expense');

  const _SummaryMetric(this.label);
  final String label;
}

enum _QuickAddVoiceState {
  idle,
  initializing,
  listening,
  processingFinal,
  parsing,
  error,
}

enum _SummaryPeriod {
  day('Day'),
  week('Week'),
  month('Month'),
  year('Year');

  const _SummaryPeriod(this.label);
  final String label;
}

class _DateRange {
  const _DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
