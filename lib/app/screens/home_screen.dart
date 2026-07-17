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
import '../../features/finance/presentation/dashboard_page.dart';
import '../../features/finance/presentation/edit_transaction_screen.dart';
import '../../features/finance/presentation/goal_setup_sheet.dart';
import '../../features/finance/presentation/transaction_history_screen.dart';
import '../../features/finance/providers/goal_provider.dart';
import '../../features/finance/providers/transaction_provider.dart';
import '../../features/finance/providers/wallet_provider.dart';
import '../../features/finance/services/goal_service.dart';
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
    super.dispose();
  }

  void _onTransactionsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildStitchHero(ts),
                Transform.translate(
                  offset: Offset(0, -Responsive.h(context, 24)),
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.finFlowColors.pageBackground,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(Responsive.w(context, 32)),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: Responsive.h(context, 24)),
                          _sectionTitle('Savings Goals'),
                          SizedBox(height: Responsive.h(context, 12)),
                          _buildGoalSummaryCard(),
                          SizedBox(height: Responsive.h(context, 24)),
                          _buildTransactionList(ts),
                          SizedBox(height: Responsive.h(context, 32)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final user = ref.watch(authServiceProvider).currentUser;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'FinFlow User';
    final avatarUrl = user?.avatarUrl?.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 10),
        Responsive.w(context, 20),
        Responsive.h(context, 10),
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 42),
            height: Responsive.w(context, 42),
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFF8DE6C4),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(displayName),
                    )
                  : _avatarFallback(displayName),
            ),
          ),
          SizedBox(width: Responsive.w(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    color: const Color(0xFF60736D),
                  ),
                ),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 20),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF063B30),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return ColoredBox(
      color: const Color(0xFFE7F7F0),
      child: Center(
        child: Text(
          name.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: _headlineFont,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF07513F),
            fontSize: Responsive.sp(context, 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStitchHero(TransactionService ts) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 18),
        Responsive.w(context, 20),
        Responsive.h(context, 48),
      ),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/home_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildGlassMetric(
                  title: AppStrings.totalBalance,
                  amount: ts.totalBalance,
                  icon: Icons.north_east_rounded,
                  color: _incomeColor,
                ),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: _buildGlassMetric(
                  title: AppStrings.totalExpenseLabel,
                  amount: ts.monthlyExpense,
                  icon: Icons.south_west_rounded,
                  color: _expenseColor,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 12)),
          _buildProgressBar(ts),
          SizedBox(height: Responsive.h(context, 12)),
          Semantics(
            button: true,
            label: 'View Financial Insights',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _navigateToDashboard,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF07513F),
                  foregroundColor: Colors.white,
                  minimumSize: Size.fromHeight(Responsive.h(context, 50)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.insights_rounded, size: 20),
                label: Text(
                  'View Financial Insights',
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.sp(context, 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMetric({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33002D22),
            blurRadius: 24,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x26FFFFFF),
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 8)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _formatMoneyValue(amount.abs()),
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontSize: Responsive.sp(context, 20),
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' VND',
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: _headlineFont,
        fontSize: Responsive.sp(context, 20),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF052224),
      ),
    );
  }

  // --- 1. Header + Balance Card đè lên ảnh ---
  // Kept temporarily for visual rollback while the Stitch hero is validated.
  // ignore: unused_element
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
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33002D22),
            blurRadius: 24,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x26FFFFFF),
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
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
    const metricColor = Colors.white;
    final metricTitle = '${_summaryMetric.label} Last ${_summaryPeriod.label}';
    final metricAmountText =
        '${_summaryMetric == _SummaryMetric.revenue ? '+' : '-'}${_formatMoney(metricAmount)}';
    final categoryExpense = selectedCategory != null
        ? ts.categoryExpenseLast7Days(selectedCategory)
        : 0;

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 20)),
      decoration: BoxDecoration(
        color: const Color(0xFF07513F),
        borderRadius: BorderRadius.circular(32),
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
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/home/flag.svg',
                      width: Responsive.w(context, 28),
                      height: Responsive.w(context, 28),
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
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
                      color: Colors.white70,
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
                    color: Colors.white,
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
                    color: Colors.white,
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
    const color = Colors.white;

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
                    color: Colors.white,
                  )
                : const Icon(
                    Icons.category_outlined,
                    size: 22,
                    color: Colors.white70,
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
                        color: Colors.white70,
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
                        color: Colors.white70,
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
                      color: const Color(0xFF00B884),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26006B52),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: labels.asMap().entries.map((entry) {
                    final isSelected = _selectedTab == entry.key;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: '${entry.value} transactions',
                        child: _PressableScale(
                          onTap: () => setState(() => _selectedTab = entry.key),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily: _bodyFont,
                                fontSize: Responsive.sp(context, 15),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF052224),
                              ),
                              child: Text(
                                entry.value,
                                textAlign: TextAlign.center,
                              ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _sectionTitle('Recent Transactions')),
            _buildViewAllButton(),
          ],
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _buildPeriodTabs(),
        SizedBox(height: Responsive.h(context, 14)),
        if (visibleTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 28)),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF6F8980),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    color: const Color(0xFF60736D),
                    fontSize: Responsive.sp(context, 13),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleTransactions.length,
            separatorBuilder: (_, _) =>
                SizedBox(height: Responsive.h(context, 10)),
            itemBuilder: (context, index) {
              final transaction = visibleTransactions[index];
              return Semantics(
                button: true,
                label:
                    '${transaction.name}, ${_formatSignedMoney(transaction.amount)}',
                child: _PressableScale(
                  pressedOverlayColor: const Color(0x14000000),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditTransactionScreen(transaction: transaction),
                    ),
                  ),
                  child: _buildTransactionItem(
                    _iconForCategory(transaction.category),
                    transaction.name,
                    _formatTransactionTime(transaction.date),
                    transaction.category,
                    _formatSignedMoney(transaction.amount),
                    _iconColorForCategory(transaction.category),
                    transaction.amount > 0,
                  ),
                ),
              );
            },
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
            color: const Color(0xFFE3F5ED),
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
                  color: const Color(0xFF07513F),
                ),
              ),
              SizedBox(width: Responsive.w(context, 5)),
              Icon(
                Icons.arrow_forward_rounded,
                size: Responsive.w(context, 15),
                color: const Color(0xFF07513F),
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
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2600523C),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 7),
          ),
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 42),
            height: Responsive.w(context, 42),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: Responsive.w(context, 21),
            ),
          ),
          SizedBox(width: Responsive.w(context, 15)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.sp(context, 14),
                    color: const Color(0xFF052224),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    color: const Color(0xFF70827C),
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.w(context, 122)),
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
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.sp(context, 14),
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
                      fontWeight: FontWeight.w400,
                      fontSize: Responsive.sp(context, 12),
                      color: const Color(0xFF70827C),
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
    return TransactionCategory.resolve(category).icon;
  }

  static Color _iconColorForCategory(String category) =>
      TransactionCategory.resolve(category).color;

  static String _formatSignedMoney(int amount) {
    final sign = amount < 0 ? '-' : '+';
    return '$sign ${_formatMoney(amount.abs())}';
  }

  static String _formatMoney(int amount) {
    return '${_formatMoneyValue(amount)} VND';
  }

  static String _formatMoneyValue(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return text;
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
