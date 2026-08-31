import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/app_language.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/finflow_action_icon.dart';
import '../../core/widgets/home_header_controls.dart';
import '../../core/widgets/notification_bell.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../shell/finflow_app.dart';
import '../../features/budget/providers/category_budget_provider.dart';
import '../../features/budget/services/category_budget_service.dart';
import '../../features/budget/models/category_budget_model.dart';
import '../../features/budget/presentation/category_budget_dialog.dart';
import '../../features/finance/models/transaction_category.dart';
import '../../features/finance/models/goal_model.dart';
import '../../features/finance/models/goal_category.dart';
import '../../features/finance/models/recurring_model.dart';
import '../../features/finance/models/transaction_model.dart';
import '../../features/finance/presentation/dashboard_page.dart';
import '../../features/finance/presentation/edit_transaction_screen.dart';
import '../../features/finance/presentation/goal_sheets.dart';
import '../../features/finance/presentation/widgets/goal_ui.dart';
import '../../features/finance/presentation/transaction_history_screen.dart';
import '../../features/finance/providers/goal_provider.dart';
import '../../features/finance/providers/transaction_provider.dart';
import '../../features/finance/providers/wallet_provider.dart';
import '../../features/finance/providers/recurring_provider.dart';
import '../../features/finance/services/recurring_service.dart';
import '../../features/finance/services/goal_service.dart';
import '../../features/finance/services/transaction_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onAddTap,
    this.onTabChanged,
    this.isActive = true,
  });

  final VoidCallback? onAddTap;
  final ValueChanged<int>? onTabChanged;
  final bool isActive;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _incomeColor = Color(0xFF00513E);
  static const _expenseColor = Color(0xFFBA1A1A);
  static const _darkPage = Color(0xFF081C18);
  static const _darkSurface = Color(0xFF16352E);
  static const _darkElevatedSurface = Color(0xFF1B3D35);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkSectionHeader = Color(0xFF005C49);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondaryText = Color(0xFFA9C1B9);
  static const _darkMutedText = Color(0xFF78958B);
  static const _darkPositive = Color(0xFF38D6AC);
  static const _darkNegative = Color(0xFFFF6B70);
  static const _darkWarning = Color(0xFFFFD166);
  static const _darkHeroLowerSurface = Color(0xFF112622);
  static const _darkTransactionsSurface = Color(0xFF111A2C);
  static const _darkBudgetSurface = Color(0xFF241B11);
  static const _darkGoalsSurface = Color(0xFF1C162A);
  static const _darkCategoriesSurface = Color(0xFF122421);
  static const _darkRecurringSurface = Color(0xFF151726);
  static const _darkInsightSurface = Color(0xFF102923);

  var _summaryMetric = _SummaryMetric.revenue;
  var _summaryPeriod = _SummaryPeriod.week;
  var _cashFlowPeriod = _CashFlowPeriod.monthly;
  var _budgetPageIndex = 0;
  var _progressAnimationEpoch = 0;
  PageRoute<dynamic>? _subscribedRoute;
  final _budgetPageController = PageController(viewportFraction: 0.88);
  @override
  void initState() {
    super.initState();
    // TransactionService is a ChangeNotifier but uses a plain Provider,
    // so we subscribe manually to rebuild the UI after data loads.
    TransactionService.instance.addListener(_onTransactionsChanged);
    GoalService.instance.addListener(_onTransactionsChanged);
    CategoryBudgetService.instance.addListener(_onTransactionsChanged);
    RecurringService.instance.addListener(_onTransactionsChanged);
    Future.microtask(() {
      ref
          .read(transactionServiceProvider)
          .fetchTransactions()
          .catchError((e) => debugPrint('fetchTransactions error: $e'));
    });
    Future.microtask(() {
      ref
          .read(categoryBudgetServiceProvider)
          .fetchCurrentMonth()
          .catchError((e) => debugPrint('fetchCategoryBudgets error: $e'));
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
    Future.microtask(() {
      ref
          .read(recurringServiceProvider)
          .fetch()
          .catchError((e) => debugPrint('fetchRecurring error: $e'));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    final route = modalRoute is PageRoute<dynamic> ? modalRoute : null;
    if (route == _subscribedRoute) return;
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restartHomeProgressAnimations();
        _refreshTransactions();
      });
    }
  }

  @override
  void didPopNext() {
    _restartHomeProgressAnimations();
    _refreshTransactions();
    ref
        .read(recurringServiceProvider)
        .fetch()
        .catchError((error) => debugPrint('refreshRecurring error: $error'));
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    TransactionService.instance.removeListener(_onTransactionsChanged);
    GoalService.instance.removeListener(_onTransactionsChanged);
    CategoryBudgetService.instance.removeListener(_onTransactionsChanged);
    RecurringService.instance.removeListener(_onTransactionsChanged);
    _budgetPageController.dispose();
    super.dispose();
  }

  void _restartHomeProgressAnimations() {
    if (!mounted || !widget.isActive) return;
    setState(() => _progressAnimationEpoch++);
  }

  void _refreshTransactions() {
    if (!mounted) return;
    ref
        .read(transactionServiceProvider)
        .fetchTransactions()
        .catchError((error) => debugPrint('refreshTransactions error: $error'));
  }

  Widget _animatedHomeProgress({
    required String id,
    required double target,
    required Widget Function(double value) builder,
  }) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      key: ValueKey('home-progress-$id-$_progressAnimationEpoch'),
      tween: Tween<double>(begin: 0, end: target.clamp(0.0, 1.0)),
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 1050),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => builder(value),
    );
  }

  void _onTransactionsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? const [Color(0xFFF4FBF8), Color(0xFFEAF7F2)]
              : const [_darkPage, _darkPage],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildStitchHero(ts),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.w(context, 20),
                      Responsive.h(context, 4),
                      Responsive.w(context, 20),
                      0,
                    ),
                    child: _buildOverviewGrid(ts),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTransactionList(ts),
                        SizedBox(height: Responsive.h(context, 32)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authServiceProvider).currentUser;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : AppStrings.choose('FinFlow User', 'Người dùng FinFlow');
    final avatarUrl = user?.avatarUrl?.trim();

    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 20),
          Responsive.h(context, 10),
          Responsive.w(context, 20),
          Responsive.h(context, 10),
        ),
        decoration: BoxDecoration(
          border: isDark
              ? const Border(bottom: BorderSide(color: _darkBorder))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.w(context, 42),
              height: Responsive.w(context, 42),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDark ? _darkPositive : const Color(0xFF8DE6C4),
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
                      color: isDark
                          ? _darkSecondaryText
                          : const Color(0xFF60736D),
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
                      color: isDark ? _darkText : const Color(0xFF063B30),
                    ),
                  ),
                ],
              ),
            ),
            const HomeLanguageSelector(),
            SizedBox(width: Responsive.w(context, 8)),
            const HomeThemeToggle(),
            SizedBox(width: Responsive.w(context, 8)),
            const NotificationBell(),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? _darkElevatedSurface : const Color(0xFFE7F7F0),
      child: Center(
        child: Text(
          name.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: _headlineFont,
            fontWeight: FontWeight.w700,
            color: isDark ? _darkPositive : const Color(0xFF07513F),
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
        Responsive.h(context, 24),
      ),
      child: Column(children: [_buildBalanceGlassCard(ts)]),
    );
  }

  Widget _buildOverviewGrid(TransactionService ts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayTransactions = ts.currentUserTransactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(today) &&
              transaction.date.isBefore(tomorrow),
        )
        .toList(growable: false);
    final todayNet = todayTransactions.fold<int>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final allTransactions = ts.currentUserTransactions;
    final latestTransaction = TransactionModel.latestOccurred(
      allTransactions,
      asOf: now,
    );

    final weeklyRange = ts.dateRangeForPeriod(ChartPeriod.week);
    final weeklySpent = ts.expenseBetween(weeklyRange.start, weeklyRange.end);
    final weeklyLimit = ref.read(authServiceProvider).weeklyBudget;
    final weeklyPercent = weeklyLimit <= 0 ? 0.0 : weeklySpent / weeklyLimit;

    final goals = ref.watch(goalServiceProvider).activeGoals;
    final primaryGoal =
        goals.where((goal) => goal.isPrimary).firstOrNull ?? goals.firstOrNull;

    final monthRange = ts.dateRangeForPeriod(ChartPeriod.month);
    final monthIncome = ts.incomeBetween(monthRange.start, monthRange.end);
    final monthExpense = ts.expenseBetween(monthRange.start, monthRange.end);
    final monthNet = monthIncome - monthExpense;
    final savingsRate = monthIncome <= 0
        ? null
        : (monthNet / monthIncome) * 100;

    final categoryExpenses = ts.expenseByCategoryBetween(
      monthRange.start,
      monthRange.end,
    );
    final topCategoryEntry = categoryExpenses.entries.isEmpty
        ? null
        : (categoryExpenses.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
    final categoryBudgets = ref.watch(categoryBudgetServiceProvider).budgets;
    final topCategoryBudget = topCategoryEntry == null
        ? null
        : categoryBudgets
              .where((budget) => budget.category == topCategoryEntry.key)
              .firstOrNull;

    ref.watch(recurringServiceRevisionProvider);
    final recurring = ref.read(recurringServiceProvider);
    final upcoming7 = recurring.upcomingOccurrencesWithin(
      const Duration(days: 7),
    );
    final nextOccurrence = upcoming7.firstOrNull;
    final nextRecurring = nextOccurrence?.schedule;
    final recurringTotal = upcoming7.fold<int>(
      0,
      (sum, occurrence) => sum + occurrence.schedule.amount.abs(),
    );

    final horizontalGap = Responsive.w(context, 12).clamp(8.0, 12.0);
    final rowOneHeight = Responsive.w(context, 190).clamp(190.0, 204.0);
    // Goals and Categories have the same compact information density as the
    // first Bento row. Keeping this row taller leaves a visibly empty footer,
    // especially in the Categories card.
    final rowTwoHeight = MediaQuery.sizeOf(context).width < 360
        ? 218.0
        : Responsive.w(context, 198).clamp(206.0, 212.0);
    // The weekly calendar and the two-bar insight chart both fit comfortably
    // at this height. The previous 292–308 range left a large empty footer in
    // both cards on common phone widths.
    final rowThreeHeight = MediaQuery.sizeOf(context).width < 360
        ? 294.0
        : 288.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.choose('Overview', 'Tổng quan'),
          style: TextStyle(
            fontFamily: _headlineFont,
            fontSize: Responsive.sp(context, 22),
            fontWeight: FontWeight.w800,
            color: isDark ? _darkText : const Color(0xFF006C53),
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        SizedBox(
          height: rowOneHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildTransactionsBentoCard(
                  count: todayTransactions.length,
                  netAmount: todayNet,
                  latest: latestTransaction,
                ),
              ),
              SizedBox(width: horizontalGap),
              Expanded(
                child: _buildBudgetBentoCard(
                  spent: weeklySpent,
                  limit: weeklyLimit,
                  percent: weeklyPercent,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        SizedBox(
          height: rowTwoHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildGoalsBentoCard(
                  goal: primaryGoal,
                  activeCount: goals.length,
                ),
              ),
              SizedBox(width: horizontalGap),
              Expanded(
                child: _buildCategoriesBentoCard(
                  category: topCategoryEntry?.key,
                  spent: topCategoryEntry?.value ?? 0,
                  budget: topCategoryBudget,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        SizedBox(
          height: rowThreeHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildRecurringBentoCard(
                  next: nextRecurring,
                  nextDate: nextOccurrence?.date,
                  upcoming: upcoming7,
                  total: recurringTotal,
                ),
              ),
              SizedBox(width: horizontalGap),
              Expanded(
                child: _buildInsightBentoCard(
                  income: monthIncome,
                  expense: monthExpense,
                  net: monthNet,
                  savingsRate: savingsRate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsBentoCard({
    required int count,
    required int netAmount,
    required TransactionModel? latest,
  }) {
    const accent = Color(0xFF1677C8);
    final latestCategory = TransactionCategory.resolve(
      latest?.category ?? 'Other',
    );
    final amountColor = latest == null || latest.amount >= 0
        ? const Color(0xFF087A5A)
        : const Color(0xFFE64B3C);
    return _buildBentoShell(
      key: const Key('overview-card-transactions'),
      title: AppStrings.choose('Transactions', 'Giao dịch'),
      icon: Icons.receipt_long_rounded,
      accent: accent,
      lightBackground: const Color(0xFFF0F8FF),
      darkBackground: _darkTransactionsSurface,
      semanticsValue: latest == null
          ? AppStrings.choose('No transactions yet', 'Chưa có giao dịch')
          : '${latest.name}, ${_overviewSignedMoney(latest.amount)}',
      onTap: _navigateToTransactionHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.choose('$count today', '$count hôm nay'),
            style: _bentoValueStyle(accent, 20),
          ),
          const SizedBox(height: 2),
          _fitBentoText(
            _overviewSignedMoney(netAmount),
            style: _bentoBodyStyle(12, strong: true),
          ),
          const Spacer(),
          _bentoEyebrow(AppStrings.choose('LATEST', 'GẦN NHẤT')),
          const SizedBox(height: 6),
          if (latest == null)
            Text(
              AppStrings.choose('No recent activity', 'Chưa có hoạt động mới'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bentoBodyStyle(11.5, muted: true, strong: true),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: latestCategory.buildIcon(size: 18, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bentoBodyStyle(14, strong: true),
                      ),
                      _fitBentoText(
                        _overviewSignedMoney(latest.amount),
                        style: _bentoBodyStyle(
                          12,
                          strong: true,
                        ).copyWith(color: amountColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _fitBentoText(
              '${AppStrings.categoryName(latest.category)} · ${_overviewTransactionDate(latest.date)}',
              style: _bentoBodyStyle(10.5, muted: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetBentoCard({
    required int spent,
    required int limit,
    required double percent,
  }) {
    final status = _budgetOverviewStatus(percent, hasLimit: limit > 0);
    final remaining = math.max(0, limit - spent);
    final displayPercent = (percent * 100).clamp(0, 100).round();
    return _buildBentoShell(
      key: const Key('overview-card-budget'),
      title: AppStrings.choose('Budget', 'Ngân sách'),
      icon: Icons.account_balance_wallet_rounded,
      iconAssetPath: 'assets/icons/home/bento_budget_wallet.svg',
      accent: const Color(0xFFE49A18),
      lightBackground: const Color(0xFFFFFDF5),
      darkBackground: _darkBudgetSurface,
      semanticsValue: limit > 0
          ? '$displayPercent%, ${formatVnd(remaining)} VND'
          : AppStrings.choose('No limit set', 'Chưa đặt hạn mức'),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.budgetOverview),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bentoEyebrow(AppStrings.choose('WEEKLY BUDGET', 'NGÂN SÁCH TUẦN')),
          const SizedBox(height: 8),
          _fitBentoText(
            limit > 0
                ? AppStrings.choose(
                    '$displayPercent% used',
                    'Đã dùng $displayPercent%',
                  )
                : AppStrings.choose('No limit set', 'Chưa đặt hạn mức'),
            style: _bentoValueStyle(status.color, 20),
          ),
          const SizedBox(height: 2),
          _fitBentoText(
            limit > 0
                ? AppStrings.choose(
                    '${formatVnd(remaining)} VND left',
                    'Còn ${formatVnd(remaining)} VND',
                  )
                : AppStrings.choose(
                    'Set a weekly limit',
                    'Đặt hạn mức hàng tuần',
                  ),
            style: _bentoBodyStyle(11.5),
          ),
          const SizedBox(height: 13),
          _overviewProgress(percent, status.color),
          const Spacer(),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsBentoCard({
    required GoalModel? goal,
    required int activeCount,
  }) {
    const accent = Color(0xFF7957C8);
    final displayPercent = ((goal?.progress ?? 0) * 100).clamp(0, 100).round();
    return _buildBentoShell(
      key: const Key('overview-card-goals'),
      title: AppStrings.choose('Goals', 'Mục tiêu'),
      icon: Icons.savings_outlined,
      accent: accent,
      lightBackground: const Color(0xFFFCF9FF),
      darkBackground: _darkGoalsSurface,
      semanticsValue: goal == null
          ? AppStrings.choose('No active goals', 'Chưa có mục tiêu')
          : '${goal.name}, $displayPercent%',
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.savingGoals),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bentoEyebrow(AppStrings.choose('PRIMARY GOAL', 'MỤC TIÊU CHÍNH')),
          const SizedBox(height: 6),
          if (goal == null)
            _OverviewNamedIconRow(
              icon: Icons.add_task_rounded,
              label: AppStrings.choose('Create a goal', 'Tạo mục tiêu'),
              color: accent,
            )
          else
            _OverviewNamedIconRow(
              iconWidget: goalIconWidgetFor(
                goal.category,
                color: accent,
                size: 17,
              ),
              label: goal.name,
              color: accent,
            ),
          const SizedBox(height: 6),
          Text(
            goal == null
                ? AppStrings.choose('0% achieved', 'Đạt 0%')
                : AppStrings.choose(
                    '$displayPercent% achieved',
                    'Đạt $displayPercent%',
                  ),
            style: _bentoValueStyle(accent, 16),
          ),
          const SizedBox(height: 2),
          _fitBentoText(
            goal == null
                ? AppStrings.choose(
                    'Start your first saving goal',
                    'Bắt đầu mục tiêu đầu tiên',
                  )
                : '${formatVnd(goal.allocatedAmount)}/${formatVnd(goal.targetAmount)} VND',
            style: _bentoBodyStyle(10.5),
          ),
          const SizedBox(height: 7),
          _overviewProgress(goal?.progress ?? 0, accent),
          const Spacer(),
          Text(
            AppStrings.choose(
              '$activeCount active goals',
              '$activeCount mục tiêu đang chạy',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bentoBodyStyle(10.5, muted: true),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesBentoCard({
    required String? category,
    required int spent,
    required CategoryBudgetModel? budget,
  }) {
    const accent = Color(0xFF008E83);
    final percent = budget == null || budget.limitAmount <= 0
        ? 0.0
        : spent / budget.limitAmount;
    final displayPercent = (percent * 100).clamp(0, 100).round();
    final status = _categoryOverviewStatus(percent, hasBudget: budget != null);
    final resolved = TransactionCategory.resolve(category ?? 'Other');
    return _buildBentoShell(
      key: const Key('overview-card-categories'),
      title: AppStrings.choose('Categories', 'Danh mục'),
      icon: Icons.category_rounded,
      iconAssetPath: 'assets/icons/home/bento_categories_shapes.svg',
      accent: accent,
      lightBackground: const Color(0xFFF2FBF9),
      darkBackground: _darkCategoriesSurface,
      semanticsValue: category == null
          ? AppStrings.choose('No spending yet', 'Chưa có chi tiêu')
          : '${AppStrings.categoryName(category)}, $displayPercent%',
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.categoryBudgets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bentoEyebrow(AppStrings.choose('TOP SPENDING', 'CHI NHIỀU NHẤT')),
          const SizedBox(height: 8),
          _OverviewNamedIconRow(
            iconWidget: resolved.buildIcon(size: 17, color: accent),
            label: category == null
                ? AppStrings.choose('No spending yet', 'Chưa có chi tiêu')
                : AppStrings.categoryName(category),
            color: accent,
          ),
          const SizedBox(height: 9),
          Text(
            category == null
                ? AppStrings.choose('0% used', 'Đã dùng 0%')
                : budget == null
                ? AppStrings.choose('No budget set', 'Chưa đặt ngân sách')
                : AppStrings.choose(
                    '$displayPercent% used',
                    'Đã dùng $displayPercent%',
                  ),
            style: _bentoValueStyle(status.color, 16),
          ),
          const SizedBox(height: 2),
          _fitBentoText(
            budget == null
                ? '${formatVnd(spent)} VND ${AppStrings.choose('spent', 'đã chi')}'
                : '${formatVnd(spent)} / ${formatVnd(budget.limitAmount)} VND',
            style: _bentoBodyStyle(10.5),
          ),
          const SizedBox(height: 9),
          _overviewProgress(percent, status.color),
        ],
      ),
    );
  }

  Widget _buildRecurringBentoCard({
    required RecurringSchedule? next,
    required DateTime? nextDate,
    required List<RecurringOccurrence> upcoming,
    required int total,
  }) {
    const accent = Color(0xFF4F46E5);
    final category = TransactionCategory.resolve(next?.category ?? 'Other');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _buildBentoShell(
      key: const Key('overview-card-recurring'),
      title: AppStrings.choose('Recurring', 'Định kỳ'),
      icon: Icons.event_repeat_rounded,
      accent: accent,
      lightBackground: const Color(0xFFF5F7FF),
      darkBackground: _darkRecurringSurface,
      semanticsValue: next == null
          ? AppStrings.choose('No upcoming payments', 'Không có khoản sắp tới')
          : '${next.name}, ${_overviewSignedMoney(next.amount)}',
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
      child: next == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: accent,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.choose(
                    'No upcoming payments',
                    'Không có khoản sắp tới',
                  ),
                  textAlign: TextAlign.center,
                  style: _bentoBodyStyle(12, strong: true),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.choose(
                    'Your next 7 days are clear',
                    '7 ngày tới đang trống',
                  ),
                  textAlign: TextAlign.center,
                  style: _bentoBodyStyle(11.5, muted: true),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bentoEyebrow(
                  AppStrings.choose('NEXT PAYMENT', 'KHOẢN TIẾP THEO'),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: category.buildIcon(size: 17, color: accent),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bentoBodyStyle(14, strong: true),
                          ),
                          Text(
                            '${AppStrings.categoryName(next.category)} · ${_overviewFrequency(next.frequency)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bentoBodyStyle(10.5, muted: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _fitBentoText(
                  _overviewSignedMoney(next.amount),
                  style: _bentoValueStyle(accent, 20),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _OverviewPill(
                      label: _overviewDueLabel(nextDate!),
                      color: _overviewDueColor(nextDate),
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _OverviewPill(
                        label:
                            next.postingMode == RecurringPostingMode.automatic
                            ? AppStrings.choose('Auto-post', 'Tự động')
                            : AppStrings.choose('Needs review', 'Cần duyệt'),
                        color:
                            next.postingMode == RecurringPostingMode.automatic
                            ? accent
                            : const Color(0xFFEF6262),
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: accent.withValues(alpha: .14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.choose('NEXT 7 DAYS', '7 NGÀY TỚI'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bentoBodyStyle(
                          9.5,
                          muted: true,
                          strong: true,
                        ).copyWith(letterSpacing: .4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _fitBentoText(
                      _overviewWeekRangeLabel(today),
                      alignment: Alignment.centerRight,
                      style: _bentoBodyStyle(9.5, muted: true, strong: true),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.choose(
                          '${upcoming.length} payments',
                          '${upcoming.length} khoản',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bentoBodyStyle(11.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: _fitBentoText(
                        '${formatOverviewCompactMoney(total)} VND',
                        alignment: Alignment.centerRight,
                        style: _bentoBodyStyle(11.5, strong: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _OverviewWeekCalendar(
                  start: today,
                  occurrences: upcoming,
                  accent: accent,
                ),
              ],
            ),
    );
  }

  Widget _buildInsightBentoCard({
    required int income,
    required int expense,
    required int net,
    required double? savingsRate,
  }) {
    final valueColor = net >= 0
        ? const Color(0xFF087A5A)
        : const Color(0xFFEF6262);
    return _buildBentoShell(
      key: const Key('overview-card-insight'),
      title: AppStrings.choose('Insight', 'Phân tích'),
      icon: Icons.analytics_rounded,
      iconAssetPath: 'assets/icons/home/bento_insight_chart_bar.svg',
      accent: const Color(0xFF087A5A),
      lightBackground: const Color(0xFFF0FAF6),
      darkBackground: _darkInsightSurface,
      semanticsValue: _overviewSignedMoney(net),
      onTap: _navigateToDashboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bentoEyebrow(
            AppStrings.choose('MONTHLY INSIGHT', 'PHÂN TÍCH THÁNG'),
          ),
          const SizedBox(height: 7),
          Text(
            AppStrings.choose('Net cash flow', 'Dòng tiền ròng'),
            style: _bentoBodyStyle(11.5, muted: true, strong: true),
          ),
          const SizedBox(height: 4),
          _OverviewInlineAmount(
            amount: _overviewSignedMoneyValue(net),
            color: valueColor,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: _OverviewIncomeExpenseComparison(
              income: income,
              expense: expense,
              incomeColor: const Color(0xFF087A5A),
              expenseColor: const Color(0xFFFF6B4A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            savingsRate == null
                ? AppStrings.choose(
                    'More data needed for insights',
                    'Cần thêm dữ liệu để phân tích',
                  )
                : AppStrings.choose(
                    'Savings rate ${savingsRate.round()}%',
                    'Tỷ lệ tiết kiệm ${savingsRate.round()}%',
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoShell({
    required Key key,
    required String title,
    required IconData icon,
    String? iconAssetPath,
    required Color accent,
    required Color lightBackground,
    Color? darkBackground,
    required String semanticsValue,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '$title. $semanticsValue',
      child: _PressableScale(
        onTap: onTap,
        tapHandledByChild: true,
        pressedScale: .975,
        pressedOpacity: .96,
        pressedOffset: const Offset(0, .008),
        duration: const Duration(milliseconds: 160),
        pressedOverlayColor: accent.withValues(alpha: .06),
        borderRadius: radius,
        child: Material(
          key: key,
          color: isDark ? darkBackground ?? _darkSurface : lightBackground,
          elevation: isDark ? 3 : 6,
          surfaceTintColor: Colors.transparent,
          shadowColor: isDark
              ? Colors.black.withValues(alpha: .48)
              : accent.withValues(alpha: .32),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: isDark ? _darkBorder : accent.withValues(alpha: .24),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: accent.withValues(alpha: .12),
            highlightColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBentoHeader(
                  title: title,
                  icon: icon,
                  iconAssetPath: iconAssetPath,
                  accent: accent,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      Responsive.w(context, 16).clamp(11.0, 16.0),
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoHeader({
    required String title,
    required IconData icon,
    String? iconAssetPath,
    required Color accent,
  }) {
    final headerColor = _bentoHeaderColor(accent);
    return Container(
      height: 46,
      width: double.infinity,
      color: headerColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 14).clamp(8.0, 14.0),
      ),
      child: Row(
        children: [
          if (iconAssetPath != null)
            SvgPicture.asset(
              iconAssetPath,
              key: Key('bento-header-icon-$title'),
              width: 21,
              height: 21,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            )
          else
            Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 7),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .20),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoEyebrow(String value) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: _bentoBodyStyle(11, muted: true, strong: true).copyWith(
      letterSpacing: .55,
      color: Theme.of(context).brightness == Brightness.dark
          ? _darkSecondaryText
          : null,
    ),
  );

  TextStyle _bentoValueStyle(Color color, double size) => TextStyle(
    fontFamily: _headlineFont,
    fontSize: math.max(size, 9.5),
    fontWeight: FontWeight.w800,
    color: _bentoContentColor(color),
    height: 1.12,
  );

  TextStyle _bentoBodyStyle(
    double size, {
    bool muted = false,
    bool strong = false,
  }) => TextStyle(
    fontFamily: _bodyFont,
    fontSize: size,
    fontWeight: strong
        ? FontWeight.w700
        : muted
        ? FontWeight.w600
        : FontWeight.w500,
    color: muted
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF8FA89F)
              : const Color(0xFF40534F))
        : (Theme.of(context).brightness == Brightness.dark
              ? _darkText
              : const Color(0xFF24312E)),
    height: 1.2,
  );

  Widget _fitBentoText(
    String value, {
    required TextStyle style,
    Alignment alignment = Alignment.centerLeft,
  }) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(value, maxLines: 1, style: style),
  );

  Color _bentoHeaderColor(Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    if (color == const Color(0xFFE49A18)) return const Color(0xFFD97706);
    if (color == const Color(0xFF087A5A)) return const Color(0xFF059669);
    return color;
  }

  Color _bentoContentColor(Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    if (color == const Color(0xFF1677C8)) return const Color(0xFF6EAEFF);
    if (color == const Color(0xFFE49A18)) return _darkWarning;
    if (color == const Color(0xFF7957C8)) return const Color(0xFFB08DFF);
    if (color == const Color(0xFF008E83) || color == const Color(0xFF087A5A)) {
      return _darkPositive;
    }
    if (color == const Color(0xFF4F46E5)) return const Color(0xFF818CF8);
    if (color == const Color(0xFFE64B3C) || color == const Color(0xFFEF6262)) {
      return _darkNegative;
    }
    return color;
  }

  Widget _overviewProgress(double value, Color color) {
    final resolvedColor = _bentoContentColor(color);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 7,
        value: value.clamp(0.0, 1.0),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? _darkHeroLowerSurface
            : color.withValues(alpha: .18),
        valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
      ),
    );
  }

  // Kept temporarily while the data-driven Bento layout is rolled out.
  // ignore: unused_element
  Widget _buildLegacyOverviewGrid(TransactionService ts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayCount = ts.currentUserTransactions.where((transaction) {
      final date = transaction.date;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final weeklyRange = ts.dateRangeForPeriod(ChartPeriod.week);
    final weeklySpent = ts.expenseBetween(weeklyRange.start, weeklyRange.end);
    final weeklyLimit = ref.read(authServiceProvider).weeklyBudget;
    final weeklyPercent = weeklyLimit <= 0
        ? 0
        : ((weeklySpent / weeklyLimit) * 100).clamp(0, 100).round();
    final goals = ref.watch(goalServiceProvider).activeGoals;
    ref.watch(recurringServiceRevisionProvider);
    final recurring = ref.read(recurringServiceProvider);
    final goalProgress = goals.isEmpty
        ? 0
        : (goals.map((goal) => goal.progress).reduce((a, b) => a + b) /
                  goals.length *
                  100)
              .round();
    final categoryExpenses = ts.expenseByCategoryBetween(
      weeklyRange.start,
      weeklyRange.end,
    );
    final topCategory = categoryExpenses.entries.isEmpty
        ? null
        : (categoryExpenses.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.choose('Overview', 'Tổng quan'),
          style: TextStyle(
            fontFamily: _headlineFont,
            fontSize: Responsive.sp(context, 22),
            fontWeight: FontWeight.w800,
            color: isDark ? _darkText : const Color(0xFF006C53),
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: Responsive.w(context, 12),
          mainAxisSpacing: Responsive.h(context, 12),
          childAspectRatio: 1.04,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildOverviewCard(
              title: AppStrings.choose('Transactions', 'Giao dịch'),
              subtitle: AppStrings.choose(
                '$todayCount transactions today',
                '$todayCount giao dịch hôm nay',
              ),
              icon: Icons.receipt_long_rounded,
              colors: const [Color(0xFF1677C8), Color(0xFF3DB7E4)],
              onTap: _navigateToTransactionHistory,
            ),
            _buildOverviewCard(
              title: AppStrings.choose('Budgets', 'Ngân sách'),
              subtitle: weeklyLimit > 0
                  ? AppStrings.choose(
                      'Weekly · $weeklyPercent% used',
                      'Tuần · đã dùng $weeklyPercent%',
                    )
                  : AppStrings.choose('Weekly · No limit', 'Tuần · Chưa đặt'),
              icon: Icons.pie_chart_rounded,
              colors: const [Color(0xFFE49A18), Color(0xFFF3C553)],
              progress: weeklyLimit > 0 ? weeklyPercent / 100 : null,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.budgetOverview),
            ),
            _buildOverviewCard(
              title: AppStrings.choose('Saving Goals', 'Mục tiêu tiết kiệm'),
              subtitle: AppStrings.choose(
                '${goals.length} active',
                '${goals.length} đang hoạt động',
              ),
              badge: '$goalProgress%',
              icon: Icons.savings_rounded,
              colors: const [Color(0xFF7957C8), Color(0xFFB47BE3)],
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.savingGoals),
            ),
            _buildOverviewCard(
              title: AppStrings.choose('Categories', 'Danh mục'),
              subtitle: topCategory == null
                  ? AppStrings.choose('No spending yet', 'Chưa có chi tiêu')
                  : AppStrings.categoryName(topCategory),
              icon: Icons.category_rounded,
              colors: const [Color(0xFF008E83), Color(0xFF32C5B5)],
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.categoryBudgets),
            ),
            _buildOverviewCard(
              title: AppStrings.choose('Recurring', 'Định kỳ'),
              subtitle: AppStrings.choose(
                '${recurring.upcomingOccurrences.length} upcoming in 7 days',
                '${recurring.upcomingOccurrences.length} sắp tới trong 7 ngày',
              ),
              icon: Icons.event_repeat_rounded,
              colors: const [Color(0xFF5267D9), Color(0xFF7F8FF0)],
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
            ),
            _buildOverviewCard(
              title: AppStrings.choose('Analytics', 'Phân tích'),
              subtitle: AppStrings.choose(
                'Monthly insights ready',
                'Đã sẵn sàng phân tích tháng',
              ),
              icon: Icons.insights_rounded,
              colors: const [Color(0xFF087A5A), Color(0xFF00B889)],
              onTap: _navigateToDashboard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    String? badge,
    double? progress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? _darkSurface
        : Color.alphaBlend(colors.first.withValues(alpha: .095), Colors.white);
    final radius = BorderRadius.circular(Responsive.w(context, 16));
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark
            ? Colors.transparent
            : colors.first.withValues(alpha: .16),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isDark ? _darkBorder : colors.first.withValues(alpha: .16),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: colors.first.withValues(alpha: .14),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(context, 14)),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: Responsive.w(context, 42),
                      height: Responsive.w(context, 42),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withValues(alpha: .25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 21),
                    ),
                    SizedBox(height: Responsive.h(context, 10)),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w700,
                        color: isDark ? _darkText : const Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 4)),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 11),
                        color: isDark
                            ? _darkSecondaryText
                            : const Color(0xFF48645D),
                      ),
                    ),
                    if (progress != null) ...[
                      SizedBox(height: Responsive.h(context, 7)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: progress,
                          backgroundColor: colors.first.withValues(alpha: .16),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.first,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: Responsive.w(context, 28),
                    height: Responsive.w(context, 28),
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: .16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.first.withValues(alpha: .12),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.first,
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: Responsive.w(context, 2),
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.first.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 10),
                          fontWeight: FontWeight.w800,
                          color: colors.first,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceGlassCard(TransactionService ts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (income, expense, balance) = switch (_cashFlowPeriod) {
      _CashFlowPeriod.daily => _cashFlowForPeriod(ts, ChartPeriod.day),
      _CashFlowPeriod.weekly => _cashFlowForPeriod(ts, ChartPeriod.week),
      _CashFlowPeriod.monthly => _cashFlowForPeriod(ts, ChartPeriod.month),
      _CashFlowPeriod.allTime => (
        ts.currentUserTransactions
            .where((transaction) => transaction.amount > 0)
            .fold(0, (total, transaction) => total + transaction.amount),
        ts.currentUserTransactions
            .where((transaction) => transaction.amount < 0)
            .fold(0, (total, transaction) => total + transaction.amount.abs()),
        ts.totalBalance,
      ),
    };
    final radius = BorderRadius.circular(Responsive.w(context, 32));

    return Container(
      key: const Key('home-balance-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF006C53),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00513E), Color(0xFF00785D)],
              )
            : null,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .5)
                : const Color(0x4000513E),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 20),
              Responsive.h(context, 18),
              Responsive.w(context, 20),
              Responsive.h(context, 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.choose('TOTAL BALANCE', 'TỔNG SỐ DƯ'),
                        key: const Key('home-total-balance-label'),
                        style: TextStyle(
                          fontFamily: _headlineFont,
                          fontSize: Responsive.sp(
                            context,
                            20,
                          ).clamp(18.0, 22.0),
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _buildCashFlowPeriodMenu(isDark),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 10)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _formatMoneyValue(balance),
                          style: TextStyle(
                            fontFamily: _headlineFont,
                            fontSize: Responsive.sp(context, 40),
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: '  VND',
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: Responsive.sp(context, 18),
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: .9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .1)),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildCashFlowGlassMetric(
                      title: AppStrings.choose('TOTAL INCOME', 'TỔNG THU NHẬP'),
                      amount: income,
                      icon: Icons.trending_up_rounded,
                      color: isDark ? _darkPositive : const Color(0xFF064E3B),
                      background: isDark
                          ? _darkHeroLowerSurface
                          : const Color(0xFFECFDF5),
                      sign: '+',
                    ),
                  ),
                  Expanded(
                    child: _buildCashFlowGlassMetric(
                      title: AppStrings.choose(
                        'TOTAL EXPENSE',
                        'TỔNG CHI TIÊU',
                      ),
                      amount: expense,
                      icon: Icons.trending_down_rounded,
                      color: isDark ? _darkNegative : const Color(0xFF991B1B),
                      background: isDark
                          ? _darkHeroLowerSurface
                          : const Color(0xFFFEF2F2),
                      sign: '-',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (int, int, int) _cashFlowForPeriod(
    TransactionService service,
    ChartPeriod period,
  ) {
    final range = service.dateRangeForPeriod(period);
    final income = service.incomeBetween(range.start, range.end);
    final expense = service.expenseBetween(range.start, range.end);
    return (income, expense, income - expense);
  }

  Widget _buildCashFlowGlassMetric({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    required Color background,
    required String sign,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: Key(
        sign == '+' ? 'cash-flow-income-panel' : 'cash-flow-expense-panel',
      ),
      decoration: BoxDecoration(
        color: background,
        border: isDark && sign == '+'
            ? const Border(right: BorderSide(color: _darkBorder))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 16),
          vertical: Responsive.h(context, 14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AnimatedTrendIcon(
                  icon: icon,
                  color: color,
                  isIncome: sign == '+',
                  stagger: sign == '-'
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  enabled: widget.isActive,
                  size: Responsive.w(context, 16),
                ),
                SizedBox(width: Responsive.w(context, 5)),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 11),
                        fontWeight: FontWeight.w700,
                        letterSpacing: .55,
                        color: color.withValues(alpha: .9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(context, 5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$sign${_formatMoneyValue(amount.abs())}',
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 18),
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
                        color: color.withValues(alpha: .7),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowPeriodMenu(bool isDark) {
    final foreground = isDark ? _darkText : Colors.white;
    final border = isDark ? _darkBorder : Colors.white.withValues(alpha: .30);
    return Semantics(
      button: true,
      label: AppStrings.choose('Choose period', 'Chọn khoảng thời gian'),
      child: Material(
        color: isDark
            ? _darkElevatedSurface
            : Colors.white.withValues(alpha: .16),
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          onTap: _showSummaryPeriodDialog,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 12),
              vertical: Responsive.h(context, 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _cashFlowPeriod.optionTitle,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                SizedBox(width: Responsive.w(context, 3)),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: Responsive.w(context, 18),
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSummaryPeriodDialog() async {
    var selected = _cashFlowPeriod;
    final result = await showDialog<_CashFlowPeriod>(
      context: context,
      barrierColor: const Color(0x990B1612),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.choose(
                                'Summary Period',
                                'Khoảng thời gian tổng hợp',
                              ),
                              style: TextStyle(
                                fontFamily: _headlineFont,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: goalText,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              AppStrings.choose(
                                'Choose how income and expenses are summarized.',
                                'Chọn cách tổng hợp thu nhập và chi tiêu.',
                              ),
                              style: TextStyle(
                                fontFamily: _bodyFont,
                                fontSize: 14,
                                height: 1.25,
                                color: goalMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: AppStrings.choose('Close', 'Đóng'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded, color: goalMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._CashFlowPeriod.values.map(
                    (period) => Padding(
                      padding: EdgeInsets.only(
                        bottom: period == _CashFlowPeriod.values.last ? 0 : 10,
                      ),
                      child: _SummaryPeriodOptionCard(
                        period: period,
                        selected: selected == period,
                        onTap: () => setDialogState(() => selected = period),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: goalPrimary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(AppStrings.choose('Apply', 'Áp dụng')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(foregroundColor: goalPrimary),
                      child: Text(
                        AppStrings.cancel,
                        style: const TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _cashFlowPeriod = result);
    }
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
                  _buildBudgetCarousel(ts),
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

  Widget _buildBudgetCarousel(TransactionService ts) {
    final authService = ref.watch(authServiceProvider);
    final periods = <({String title, ChartPeriod period, int limit})>[
      (
        title: AppStrings.choose('Daily budget', 'Ngân sách ngày'),
        period: ChartPeriod.day,
        limit: authService.dailyBudget,
      ),
      (
        title: AppStrings.choose('Weekly budget', 'Ngân sách tuần'),
        period: ChartPeriod.week,
        limit: authService.weeklyBudget,
      ),
      (
        title: AppStrings.choose('Monthly budget', 'Ngân sách tháng'),
        period: ChartPeriod.month,
        limit: authService.currentUser?.budgetLimit ?? 0,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: math.max(
            Responsive.h(context, 168),
            Responsive.w(context, 168),
          ),
          child: PageView.builder(
            controller: _budgetPageController,
            padEnds: false,
            physics: const BouncingScrollPhysics(),
            itemCount: periods.length,
            onPageChanged: (index) {
              if (_budgetPageIndex != index) {
                setState(() => _budgetPageIndex = index);
              }
            },
            itemBuilder: (context, index) {
              final item = periods[index];
              final range = ts.dateRangeForPeriod(item.period);
              final spent = ts.expenseBetween(range.start, range.end);
              return Padding(
                padding: EdgeInsets.only(
                  right: index == periods.length - 1
                      ? 0
                      : Responsive.w(context, 12),
                ),
                child: _buildBudgetCard(
                  title: item.title,
                  spent: spent,
                  budgetLimit: item.limit,
                ),
              );
            },
          ),
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Semantics(
          label: AppStrings.choose(
            '${periods[_budgetPageIndex].title}, page ${_budgetPageIndex + 1} of ${periods.length}',
            '${periods[_budgetPageIndex].title}, trang ${_budgetPageIndex + 1}/${periods.length}',
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(periods.length, (index) {
              final isSelected = index == _budgetPageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: Responsive.w(context, isSelected ? 12 : 6),
                height: Responsive.h(context, 6),
                margin: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 3),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).brightness == Brightness.dark
                            ? _darkPositive
                            : const Color(0xFF00856A)
                      : Theme.of(context).brightness == Brightness.dark
                      ? _darkBorder
                      : const Color(0xFFA9D5C5),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard({
    required String title,
    required int spent,
    required int budgetLimit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawPercent = budgetLimit > 0 ? (spent / budgetLimit) * 100 : 0.0;
    final displayPercent = rawPercent.clamp(0.0, 100.0);
    final budgetRatio = (rawPercent / 100).clamp(0.0, 1.0);
    final ({String label, Color color, Color background}) status =
        budgetLimit <= 0
        ? (
            label: AppStrings.choose('NO LIMIT', 'CHƯA ĐẶT'),
            color: isDark ? _darkSecondaryText : goalMuted,
            background: isDark ? _darkElevatedSurface : goalSurfaceLow,
          )
        : rawPercent >= 100
        ? (
            label: AppStrings.choose('OVER BUDGET', 'VƯỢT NGÂN SÁCH'),
            color: isDark ? _darkNegative : goalError,
            background: isDark ? _darkElevatedSurface : const Color(0xFFFEE2E2),
          )
        : rawPercent >= 75
        ? (
            label: AppStrings.choose('NEAR LIMIT', 'GẦN HẠN MỨC'),
            color: const Color(0xFFF59E0B),
            background: isDark ? _darkElevatedSurface : const Color(0xFFFFF4E5),
          )
        : (
            label: AppStrings.choose('ON TRACK', 'ĐÚNG KẾ HOẠCH'),
            color: isDark ? _darkPositive : goalPrimary,
            background: isDark ? _darkElevatedSurface : const Color(0xFFE5F6F0),
          );

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(context, 24)),
        border: Border.all(
          color: isDark ? _darkBorder : goalOutline.withValues(alpha: .1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x1F002D22),
            blurRadius: isDark ? 12 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: FontWeight.w500,
                    color: isDark ? _darkText : goalText,
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(context, 8)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 12),
                      vertical: Responsive.h(context, 5),
                    ),
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(99),
                      border: isDark ? Border.all(color: _darkBorder) : null,
                    ),
                    child: Text(
                      status.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 10),
                        fontWeight: FontWeight.w800,
                        letterSpacing: .45,
                        color: isDark ? _darkSecondaryText : status.color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 13)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${displayPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, 30),
                    fontWeight: FontWeight.w800,
                    color: status.color,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: AppStrings.choose(' used', ' đã dùng'),
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 18),
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(context, 10)),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: Responsive.h(context, 12),
              child: Stack(
                children: [
                  Container(
                    color: isDark ? _darkBorder : const Color(0xFFEEEEF0),
                  ),
                  _animatedHomeProgress(
                    id: 'budget-$title',
                    target: budgetRatio,
                    builder: (value) => FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: status.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 13)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: isDark ? _darkSecondaryText : goalMuted,
                  ),
                  children: budgetLimit > 0
                      ? [
                          TextSpan(
                            text: AppStrings.choose('Spent ', 'Đã chi '),
                          ),
                          TextSpan(
                            text: _formatMoneyValue(spent),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' / '),
                          TextSpan(
                            text: _formatMoneyValue(budgetLimit),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' VND'),
                        ]
                      : [
                          TextSpan(
                            text: AppStrings.choose('Spent ', 'Đã chi '),
                          ),
                          TextSpan(
                            text: _formatMoneyValue(spent),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: AppStrings.choose(
                              ' VND · No limit',
                              ' VND · Chưa đặt hạn mức',
                            ),
                          ),
                        ],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Retained for the legacy stacked-header layout.
  // ignore: unused_element
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
                AppStrings.choose('Monthly budget', 'Ngân sách tháng'),
                style: TextStyle(
                  fontFamily: _bodyFont,
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF052224),
                ),
              ),
              Text(
                AppStrings.choose(
                  '${displayPercent.toStringAsFixed(0)}% used',
                  'Đã dùng ${displayPercent.toStringAsFixed(0)}%',
                ),
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
                  AppStrings.choose(
                    '${_formatMoney(ts.monthlyExpense)} spent',
                    'Đã chi ${_formatMoney(ts.monthlyExpense)}',
                  ),
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
                      ? AppStrings.choose(
                          '${_formatMoney(budgetLimit)} limit',
                          'Hạn mức ${_formatMoney(budgetLimit)}',
                        )
                      : AppStrings.choose('No limit', 'Chưa đặt hạn mức'),
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
                ? AppStrings.choose(
                    'Set a budget limit in Settings to track your spending.',
                    'Đặt hạn mức trong Cài đặt để theo dõi chi tiêu.',
                  )
                : (rawPercent > 100
                      ? AppStrings.overBudget
                      : AppStrings.choose(
                          '$displayPercent% Of Your Expenses, Looks Good.',
                          'Bạn đã dùng $displayPercent% ngân sách, vẫn ổn.',
                        )),
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

  // Kept for the legacy home layout variants; the current Home no longer
  // renders this section because goals are opened from the Overview card.
  // ignore: unused_element
  Widget _buildRefinedGoalsSection(TransactionService ts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = ref.watch(goalServiceProvider);
    final goals = service.activeGoals.take(4).toList(growable: false);
    final available = service.availableForGoals(ts.totalBalance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(
          title: AppStrings.choose('Savings Goals', 'Mục tiêu tiết kiệm'),
          addTooltip: AppStrings.choose('Create new goal', 'Tạo mục tiêu mới'),
          onAdd: () => Navigator.of(context).pushNamed(AppRoutes.createGoal),
          onViewAll: () =>
              Navigator.of(context).pushNamed(AppRoutes.savingGoals),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 16),
            vertical: Responsive.h(context, 12),
          ),
          decoration: BoxDecoration(
            color: isDark ? _darkElevatedSurface : const Color(0x3300C49A),
            borderRadius: BorderRadius.circular(12),
            border: isDark ? Border.all(color: _darkBorder) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.choose(
                        'Available for goals',
                        'Có thể dành cho mục tiêu',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? _darkSecondaryText : goalMuted,
                      ),
                    ),
                    Text(
                      '${formatVnd(available)} VND',
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _darkText : goalDark,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: goals.isEmpty
                    ? () =>
                          Navigator.of(context).pushNamed(AppRoutes.createGoal)
                    : () => AllocateMoneySheet.show(
                        context,
                        allowGoalSelection: true,
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? _darkSectionHeader : goalPrimary,
                  foregroundColor: _darkText,
                  shape: const StadiumBorder(),
                  minimumSize: Size(0, Responsive.h(context, 44)),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 18),
                  ),
                ),
                child: Text(
                  goals.isEmpty
                      ? AppStrings.choose('Create goal', 'Tạo mục tiêu')
                      : AppStrings.choose('Allocate', 'Phân bổ'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (goals.isEmpty)
          Material(
            color: isDark ? _darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isDark
                  ? const BorderSide(color: _darkBorder)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.createGoal),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const GoalIconTile(category: 'Other Goal'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.choose(
                              'Create your first savings goal',
                              'Tạo mục tiêu tiết kiệm đầu tiên',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            AppStrings.choose(
                              'Allocate only when you are ready.',
                              'Chỉ phân bổ tiền khi bạn đã sẵn sàng.',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: goalMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: Responsive.h(context, 214),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: goals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _buildHomeGoalCard(goals[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeGoalCard(GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radiusValue = Responsive.w(context, 16);
    final radius = BorderRadius.circular(radiusValue);
    final card = Material(
      color: isDark ? _darkSurface : Colors.white,
      elevation: isDark ? 0 : (goal.isPrimary ? 4 : 2),
      shadowColor: goal.isPrimary
          ? const Color(0x42D99A00)
          : const Color(0x20006C53),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: isDark
            ? BorderSide(
                color: goal.isPrimary ? _darkWarning : _darkBorder,
                width: goal.isPrimary ? 1.5 : 1,
              )
            : goal.isPrimary
            ? BorderSide.none
            : const BorderSide(color: Color(0x337B8B84)),
      ),
      child: InkWell(
        borderRadius: radius,
        splashFactory: InkRipple.splashFactory,
        splashColor: goalPrimary.withValues(alpha: .14),
        highlightColor: isDark
            ? _darkElevatedSurface.withValues(alpha: .72)
            : const Color(0x8CE5F6F0),
        onTap: () async {
          await Future<void>.delayed(const Duration(milliseconds: 135));
          if (!mounted) return;
          await Navigator.of(
            context,
          ).pushNamed(AppRoutes.goalDetails, arguments: goal.id);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 20),
            Responsive.h(context, 16),
            Responsive.w(context, 20),
            Responsive.h(context, 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GoalIconTile(category: goal.category, size: 40),
                  SizedBox(width: Responsive.w(context, 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: Responsive.sp(context, 16),
                            fontWeight: FontWeight.w600,
                            color: isDark ? _darkText : goalText,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 8)),
                        Text(
                          AppStrings.categoryName(
                            GoalCategory.fromKey(goal.category).label,
                          ),
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: Responsive.sp(context, 12),
                            color: isDark ? _darkSecondaryText : goalMuted,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal.isProtected)
                    Icon(
                      Icons.lock_rounded,
                      size: 20,
                      color: isDark ? _darkMutedText : goalMuted,
                    ),
                ],
              ),
              // Keep the progress block visually connected to the goal
              // metadata. A Spacer pushed it too close to the card bottom on
              // wider/shorter devices and created a large empty band.
              SizedBox(height: Responsive.h(context, 20)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${(goal.progress * 100).round()}%',
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 22),
                        fontWeight: FontWeight.w800,
                        color: isDark ? _darkPositive : goalPrimary,
                        height: 1.05,
                      ),
                    ),
                    TextSpan(
                      text: AppStrings.choose('  achieved', '  hoàn thành'),
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 13),
                        fontWeight: FontWeight.w500,
                        color: isDark ? _darkSecondaryText : goalMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(context, 7)),
              _animatedHomeProgress(
                id: 'goal-${goal.id}',
                target: goal.progress,
                builder: (value) => _buildHomeGoalProgress(value),
              ),
              SizedBox(height: Responsive.h(context, 10)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatVnd(goal.allocatedAmount)} / ${formatVnd(goal.targetAmount)} VND',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: isDark ? _darkPositive : goalPrimary,
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? _darkBorder : const Color(0xFFD8E5DF),
              ),
              SizedBox(height: Responsive.h(context, 8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: Responsive.w(context, 14),
                    color: isDark ? _darkSecondaryText : goalMuted,
                  ),
                  SizedBox(width: Responsive.w(context, 6)),
                  Flexible(
                    child: Text(
                      formatGoalDate(goal.targetDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 12),
                        fontWeight: FontWeight.w500,
                        color: isDark ? _darkText : goalText,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      width: Responsive.w(context, 280),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: Responsive.h(context, 14),
              bottom: Responsive.h(context, 5),
            ),
            child: SizedBox(
              height: Responsive.h(context, 190),
              child: goal.isPrimary
                  ? _AnimatedPrimaryGoalBorder(
                      borderRadius: radiusValue,
                      child: card,
                    )
                  : card,
            ),
          ),
          if (goal.isPrimary)
            Positioned(
              top: 0,
              right: Responsive.w(context, 20),
              child: const _PrimaryGoalBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeGoalProgress(double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = value.clamp(0.0, 1.0);
    return SizedBox(
      height: Responsive.h(context, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = progress <= 0
              ? 0.0
              : math.max(10.0, constraints.maxWidth * progress);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? _darkBorder : goalSurfaceLow,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: isDark ? _darkPositive : goalPrimary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Kept for the legacy home layout variants; category budgets are opened
  // from the Overview card instead of being duplicated on Home.
  // ignore: unused_element
  Widget _buildCategoryBudgetSection(TransactionService ts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budgets = ref.watch(categoryBudgetServiceProvider).budgets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(
          title: AppStrings.choose(
            'Budget by Category',
            'Ngân sách theo danh mục',
          ),
          addTooltip: AppStrings.choose(
            'Add category budget',
            'Thêm ngân sách danh mục',
          ),
          onAdd: _openCategoryBudgetDialog,
          onViewAll: () =>
              Navigator.of(context).pushNamed(AppRoutes.categoryBudgets),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        if (budgets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? _darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? _darkBorder
                    : goalOutline.withValues(alpha: .25),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? _darkElevatedSurface : goalMint,
                  child: Icon(
                    Icons.pie_chart_outline_rounded,
                    color: isDark ? _darkPositive : goalPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.choose(
                          'No category budgets yet',
                          'Chưa có ngân sách danh mục',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? _darkText : goalText,
                        ),
                      ),
                      Text(
                        AppStrings.choose(
                          'Set limits to track category spending here.',
                          'Đặt hạn mức để theo dõi chi tiêu theo danh mục.',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? _darkSecondaryText : goalMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openCategoryBudgetDialog(),
                  icon: const Icon(Icons.add_rounded, color: goalPrimary),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? _darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? _darkBorder
                    : goalOutline.withValues(alpha: .22),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x33000000)
                      : const Color(0x12006C53),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: budgets
                  .take(4)
                  .map((budget) => _buildCategoryBudgetRow(budget, ts))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryBudgetRow(
    CategoryBudgetModel budget,
    TransactionService ts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final range = ts.dateRangeForPeriod(ChartPeriod.month);
    final expenses = ts.expenseByCategoryBetween(range.start, range.end);
    final key = switch (budget.category.toLowerCase()) {
      'food & dining' => 'Food',
      'transportation' => 'Transport',
      _ => budget.category,
    };
    final spent = expenses[key] ?? 0;
    final usedPercent = budget.limitAmount <= 0
        ? 0.0
        : (spent / budget.limitAmount) * 100;
    final ratio = budget.limitAmount <= 0
        ? 0.0
        : (spent / budget.limitAmount).clamp(0.0, 1.0);
    final category = TransactionCategory.resolve(key);
    final barColor = usedPercent >= 90
        ? isDark
              ? _darkNegative
              : goalError
        : usedPercent >= 70
        ? const Color(0xFFF59E0B)
        : isDark
        ? _darkPositive
        : goalPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashFactory: InkRipple.splashFactory,
        splashColor: goalPrimary.withValues(alpha: .14),
        highlightColor: isDark
            ? _darkElevatedSurface.withValues(alpha: .72)
            : const Color(0x8CE5F6F0),
        onTap: () async {
          await Future<void>.delayed(const Duration(milliseconds: 135));
          if (!mounted) return;
          await _openCategoryBudgetDialog(budget: budget, spent: spent);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? _darkBorder : const Color(0x667AA493),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: category.color.withValues(alpha: .14),
                    child: category.buildIcon(size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.categoryName(budget.category),
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 16),
                        fontWeight: FontWeight.w500,
                        color: isDark ? _darkText : goalText,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Text(
                    '${usedPercent.round()}%',
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontSize: Responsive.sp(context, 22),
                      fontWeight: FontWeight.w800,
                      color: barColor,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    AppStrings.choose(' used', ' đã dùng'),
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 13),
                      fontWeight: FontWeight.w600,
                      color: isDark ? _darkSecondaryText : goalMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 10,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? _darkBorder : goalSurfaceLow,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        _animatedHomeProgress(
                          id: 'category-budget-${budget.id}',
                          target: ratio,
                          builder: (value) {
                            final fillWidth = value <= 0
                                ? 0.0
                                : math.max(10.0, constraints.maxWidth * value);
                            return Container(
                              width: fillWidth,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.choose(
                      'Spent: ${formatVnd(spent)} VND',
                      'Đã chi: ${formatVnd(spent)} VND',
                    ),
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? _darkSecondaryText
                          : const Color(0xFF34423C),
                    ),
                  ),
                  Text(
                    AppStrings.choose(
                      'Budget: ${formatVnd(budget.limitAmount)} VND',
                      'Ngân sách: ${formatVnd(budget.limitAmount)} VND',
                    ),
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? _darkSecondaryText
                          : const Color(0xFF34423C),
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

  Future<void> _openCategoryBudgetDialog({
    CategoryBudgetModel? budget,
    int spent = 0,
  }) async {
    final result = await showCategoryBudgetDialog(
      context,
      budget: budget,
      currentSpent: spent,
    );
    if (result == null || !mounted) return;

    final service = ref.read(categoryBudgetServiceProvider);
    try {
      if (result.action == CategoryBudgetDialogAction.delete &&
          budget != null) {
        await service.delete(budget.id);
        return;
      }
      if (result.action == CategoryBudgetDialogAction.save) {
        await service.save(result.category, result.limitAmount);
        if (budget != null && result.category != budget.category) {
          await service.delete(budget.id);
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Could not update budget: $error',
              'Không thể cập nhật ngân sách: $error',
            ),
          ),
        ),
      );
    }
  }

  // --- Legacy summary widgets retained for existing metric pickers. ---
  // ignore: unused_element
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
    final metricTitle = AppStrings.choose(
      '${_summaryMetric.label} Last ${_summaryPeriod.label}',
      '${_summaryMetric.label} ${_summaryPeriod.label.toLowerCase()} qua',
    );
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
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.savingGoals),
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
                    AppStrings.choose('Saving Goal', 'Mục tiêu tiết kiệm'),
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
                      : AppStrings.savingsOnGoals,
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
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.w(context, 20)),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
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
                      AppStrings.choose('Choose summary', 'Chọn tổng hợp'),
                      style: TextStyle(
                        fontFamily: _headlineFont,
                        fontSize: Responsive.sp(context, 16),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003829),
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 16)),
                    _buildPickerSection(
                      title: AppStrings.choose('Type', 'Loại'),
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
                      title: AppStrings.choose('Period', 'Thời gian'),
                      children: _SummaryPeriod.values.map((period) {
                        return _buildPickerChip(
                          label: AppStrings.choose(
                            'Last ${period.label}',
                            '${period.label} qua',
                          ),
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
                          AppStrings.choose('Apply', 'Áp dụng'),
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
          ),
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
    final label = selectedCategory == null
        ? AppStrings.choose('Select category', 'Chọn danh mục')
        : AppStrings.categoryName(selectedCategory);
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
                ? TransactionCategory.resolve(selectedCategory).buildIcon(
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
                          ? AppStrings.choose(
                              '$selectedCategory Last Week',
                              '${AppStrings.categoryName(selectedCategory)} tuần trước',
                            )
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
    final builtIn = TransactionCategory.expenses;
    final custom = CustomCategoryStore.instance.items
        .where((category) => category.type == TransactionCategoryType.expense)
        .map(
          (c) => TransactionCategory(
            key: c.name,
            label: c.name,
            icon: c.iconData,
            color: c.color,
            type: c.type,
          ),
        );
    final allCategories = [...builtIn, ...custom];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.w(context, 20)),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
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
                    AppStrings.choose(
                      'Select category to track',
                      'Chọn danh mục để theo dõi',
                    ),
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
                                child: cat.buildIcon(
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
                                  AppStrings.categoryName(cat.label),
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

  static List<String> get _months => AppStrings.isVietnamese
      ? const [
          'Thg 1',
          'Thg 2',
          'Thg 3',
          'Thg 4',
          'Thg 5',
          'Thg 6',
          'Thg 7',
          'Thg 8',
          'Thg 9',
          'Thg 10',
          'Thg 11',
          'Thg 12',
        ]
      : const [
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final visibleTransactions =
        ts.currentUserTransactions
            .where((transaction) => !transaction.date.isAfter(now))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final recentTransactions = visibleTransactions.take(3).toList();
    final emptyMessage = AppStrings.noTransactionsYet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(
          title: AppStrings.choose('Recent Transactions', 'Giao dịch gần đây'),
          titleFontSize: 18,
          onViewAll: _navigateToTransactionHistory,
        ),
        SizedBox(height: Responsive.h(context, 12)),
        if (recentTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 28)),
            decoration: BoxDecoration(
              color: isDark ? _darkSurface : const Color(0xFFF3F7F5),
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: _darkBorder) : null,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: isDark ? _darkMutedText : const Color(0xFF6F8980),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    color: isDark
                        ? _darkSecondaryText
                        : const Color(0xFF60736D),
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
            itemCount: recentTransactions.length,
            separatorBuilder: (_, _) =>
                SizedBox(height: Responsive.h(context, 10)),
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return _SwipeToDeleteTransaction(
                key: ValueKey('swipe-transaction-${transaction.id}'),
                onDelete: () => _deleteTransactionWithUndo(transaction),
                child: Semantics(
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
                      TransactionCategory.resolve(transaction.category),
                      transaction.name,
                      _formatTransactionTime(transaction.date),
                      AppStrings.categoryName(transaction.category),
                      _formatSignedMoney(transaction.amount),
                      transaction.amount > 0,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _deleteTransactionWithUndo(TransactionModel transaction) async {
    try {
      await ref.read(transactionServiceProvider).delete(transaction.id);
      if (!mounted) return;
      _showDeletedSnackBar(transaction);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.choose(
                'Unable to delete transaction: $error',
                'Không thể xóa giao dịch: $error',
              ),
            ),
          ),
        );
      }
      rethrow;
    }
  }

  void _showDeletedSnackBar(TransactionModel transaction) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('transaction-deleted-snackbar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE7EBE9),
          elevation: 8,
          margin: EdgeInsets.fromLTRB(
            Responsive.w(context, 12),
            0,
            Responsive.w(context, 12),
            Responsive.h(context, 10),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Container(
                width: Responsive.w(context, 24),
                height: Responsive.w(context, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E0),
                  shape: BoxShape.circle,
                ),
                child: FinFlowTrashIcon(
                  size: Responsive.w(context, 14),
                  color: const Color(0xFFBA1A1A),
                ),
              ),
              SizedBox(width: Responsive.w(context, 9)),
              Expanded(
                child: Text(
                  AppStrings.choose('Transaction Deleted', 'Đã xóa giao dịch'),
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF313936),
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            key: const Key('undo-delete-transaction-button'),
            label: AppStrings.choose('Undo', 'Hoàn tác'),
            textColor: const Color(0xFF006C53),
            onPressed: () => _restoreDeletedTransaction(transaction),
          ),
        ),
      );
  }

  Future<void> _restoreDeletedTransaction(TransactionModel transaction) async {
    try {
      await ref.read(transactionServiceProvider).add(transaction);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppStrings.choose('Transaction restored', 'Đã khôi phục giao dịch'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Unable to restore transaction: $error',
              'Không thể khôi phục giao dịch: $error',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildHomeSectionHeader({
    required String title,
    required VoidCallback onViewAll,
    VoidCallback? onAdd,
    String? addTooltip,
    double titleFontSize = 16,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF073F34);
    return SizedBox(
      height: Responsive.h(context, 44),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: _headlineFont,
                    fontSize: Responsive.sp(context, titleFontSize),
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(context, 12)),
          if (onAdd != null) ...[
            Tooltip(
              message: addTooltip ?? AppStrings.add,
              child: _buildSectionHeaderAction(
                onTap: onAdd,
                semanticLabel: addTooltip ?? AppStrings.add,
                width: 36,
                borderRadius: 18,
                child: Icon(
                  Icons.add_rounded,
                  color: foreground,
                  size: Responsive.w(context, 20),
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
          ],
          _buildSectionHeaderAction(
            onTap: onViewAll,
            semanticLabel: AppStrings.choose(
              'View all $title',
              'Xem tất cả $title',
            ),
            width: 92,
            borderRadius: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.choose('View All', 'Xem tất cả'),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 14),
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 4)),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: Responsive.w(context, 16),
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderAction({
    required VoidCallback onTap,
    required String semanticLabel,
    required double width,
    required double borderRadius,
    required Widget child,
  }) {
    final radius = BorderRadius.circular(Responsive.w(context, borderRadius));
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: Responsive.w(context, width),
        height: Responsive.h(context, 36),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    TransactionCategory categoryData,
    String title,
    String date,
    String category,
    String amount,
    bool isIncome,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: isDark ? _darkHeroLowerSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? _darkBorder : const Color(0xFFD6E7E0),
        ),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1800523C),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x2400523C),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 42),
            height: Responsive.w(context, 42),
            decoration: BoxDecoration(
              color: isDark
                  ? _darkElevatedSurface
                  : categoryData.color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(10),
              border: isDark ? Border.all(color: _darkBorder) : null,
            ),
            child: categoryData.buildIcon(size: Responsive.w(context, 19)),
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
                    color: isDark ? _darkText : const Color(0xFF052224),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    color: isDark
                        ? _darkSecondaryText
                        : const Color(0xFF52655E),
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w500,
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
                        color: isDark
                            ? isIncome
                                  ? _darkPositive
                                  : _darkNegative
                            : isIncome
                            ? _incomeColor
                            : _expenseColor,
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
                      fontWeight: FontWeight.w500,
                      fontSize: Responsive.sp(context, 12),
                      color: isDark
                          ? _darkSecondaryText
                          : const Color(0xFF52655E),
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

({String label, Color color}) _budgetOverviewStatus(
  double percent, {
  required bool hasLimit,
}) {
  if (!hasLimit) {
    return (
      label: AppStrings.choose('SET BUDGET', 'ĐẶT NGÂN SÁCH'),
      color: const Color(0xFFE49A18),
    );
  }
  if (percent < .7) {
    return (
      label: AppStrings.choose('ON TRACK', 'ĐÚNG TIẾN ĐỘ'),
      color: const Color(0xFF087A5A),
    );
  }
  if (percent < .9) {
    return (
      label: AppStrings.choose('NEAR LIMIT', 'GẦN HẠN MỨC'),
      color: const Color(0xFFE49A18),
    );
  }
  if (percent < 1) {
    return (
      label: AppStrings.choose('LIMIT WARNING', 'SẮP CHẠM HẠN MỨC'),
      color: const Color(0xFFEF6262),
    );
  }
  return (
    label: AppStrings.choose('OVER BUDGET', 'VƯỢT NGÂN SÁCH'),
    color: const Color(0xFFBA1A1A),
  );
}

({String label, Color color}) _categoryOverviewStatus(
  double percent, {
  required bool hasBudget,
}) {
  if (!hasBudget || percent < .7) {
    return (
      label: AppStrings.choose('ON TRACK', 'ĐÚNG TIẾN ĐỘ'),
      color: const Color(0xFF008E83),
    );
  }
  if (percent < .9) {
    return (
      label: AppStrings.choose('NEAR LIMIT', 'GẦN HẠN MỨC'),
      color: const Color(0xFFE49A18),
    );
  }
  if (percent < 1) {
    return (
      label: AppStrings.choose('LIMIT WARNING', 'SẮP CHẠM HẠN MỨC'),
      color: const Color(0xFFEF6262),
    );
  }
  return (
    label: AppStrings.choose('OVER BUDGET', 'VƯỢT NGÂN SÁCH'),
    color: const Color(0xFFBA1A1A),
  );
}

String _overviewSignedMoney(int amount) {
  return '${_overviewSignedMoneyValue(amount)} VND';
}

String _overviewSignedMoneyValue(int amount) {
  final sign = amount < 0 ? '−' : '+';
  return '$sign${formatVnd(amount.abs())}';
}

@visibleForTesting
String formatOverviewCompactMoney(int amount) {
  final absolute = amount.abs();
  if (absolute >= 1000000000) {
    return '${_trimOverviewDecimal(absolute / 1000000000)}B';
  }
  if (absolute >= 1000000) {
    return '${_trimOverviewDecimal(absolute / 1000000)}M';
  }
  if (absolute >= 1000) {
    return '${_trimOverviewDecimal(absolute / 1000)}K';
  }
  return '$absolute';
}

String _trimOverviewDecimal(double value) {
  final formatted = value.toStringAsFixed(value >= 10 ? 1 : 2);
  return formatted
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _overviewFrequency(RecurringFrequency frequency) => switch (frequency) {
  RecurringFrequency.daily => AppStrings.choose('Daily', 'Hàng ngày'),
  RecurringFrequency.weekly => AppStrings.choose('Weekly', 'Hàng tuần'),
  RecurringFrequency.monthly => AppStrings.choose('Monthly', 'Hàng tháng'),
};

String _overviewDueLabel(DateTime date) {
  final days = _overviewDaysUntil(date);
  if (days < 0) return AppStrings.choose('OVERDUE', 'QUÁ HẠN');
  if (days == 0) return AppStrings.choose('TODAY', 'HÔM NAY');
  if (days == 1) return AppStrings.choose('TOMORROW', 'NGÀY MAI');
  return _overviewShortDate(date);
}

Color _overviewDueColor(DateTime date) {
  final days = _overviewDaysUntil(date);
  if (days <= 0) return const Color(0xFFFF6B4A);
  if (days == 1) return const Color(0xFFE49A18);
  return const Color(0xFF5267D9);
}

int _overviewDaysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

String _overviewShortDate(DateTime date) {
  if (AppStrings.isVietnamese) return '${date.day}/${date.month}';
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
  return '${months[date.month - 1]} ${date.day}';
}

String _overviewTransactionDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (transactionDay == today) {
    return '${AppStrings.choose('Today', 'Hôm nay')}, $time';
  }
  if (transactionDay == today.subtract(const Duration(days: 1))) {
    return '${AppStrings.choose('Yesterday', 'Hôm qua')}, $time';
  }
  return '${_overviewShortDate(date)}, $time';
}

String _overviewWeekRangeLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  final startLabel = _overviewShortDate(start).toUpperCase();
  if (start.month == end.month) {
    return '$startLabel — ${end.day}';
  }
  return '$startLabel — ${_overviewShortDate(end).toUpperCase()}';
}

String overviewCompactWeekdayLabel(DateTime day, {AppLocale? locale}) {
  const englishWeekdays = ['M', 'T', 'W', 'T', 'F', 'Sa', 'Su'];
  const vietnameseWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final labels = (locale ?? AppLanguage.instance.locale) == AppLocale.english
      ? englishWeekdays
      : vietnameseWeekdays;
  return labels[day.weekday - DateTime.monday];
}

class _OverviewInlineAmount extends StatelessWidget {
  const _OverviewInlineAmount({required this.amount, required this.color});

  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: amount,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          TextSpan(
            text: '  VND',
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: .82),
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    ),
  );
}

class _OverviewWeekCalendar extends StatelessWidget {
  const _OverviewWeekCalendar({
    required this.start,
    required this.occurrences,
    required this.accent,
  });

  final DateTime start;
  final List<RecurringOccurrence> occurrences;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(days.length, (index) {
        final day = days[index];
        final isToday = index == 0;
        final occurrence = occurrences.where((item) {
          return item.date.year == day.year &&
              item.date.month == day.month &&
              item.date.day == day.day;
        }).firstOrNull;
        final dotColor =
            occurrence?.schedule.postingMode == RecurringPostingMode.review
            ? const Color(0xFFFF6B4A)
            : accent;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                overviewCompactWeekdayLabel(day),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFA9C1B9)
                      : const Color(0xFF52625E),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF6B4A)),
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday
                        ? const Color(0xFFFF6B4A)
                        : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF4FBF8)
                        : const Color(0xFF24312E),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: occurrence == null ? Colors.transparent : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _OverviewIncomeExpenseComparison extends StatelessWidget {
  const _OverviewIncomeExpenseComparison({
    required this.income,
    required this.expense,
    required this.incomeColor,
    required this.expenseColor,
  });

  final int income;
  final int expense;
  final Color incomeColor;
  final Color expenseColor;

  @override
  Widget build(BuildContext context) {
    final maximum = math.max(income, expense);
    final incomeFactor = maximum == 0 ? .06 : income / maximum;
    final expenseFactor = maximum == 0 ? .06 : expense / maximum;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A493F)
                      : const Color(0xFFD6E6E0),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _OverviewComparisonBar(
                  factor: incomeFactor,
                  color: incomeColor,
                ),
                const SizedBox(width: 14),
                _OverviewComparisonBar(
                  factor: expenseFactor,
                  color: expenseColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _OverviewComparisonLabel(
              label: AppStrings.choose('Income', 'Thu nhập'),
              value: formatOverviewCompactMoney(income),
              color: incomeColor,
            ),
            const SizedBox(width: 14),
            _OverviewComparisonLabel(
              label: AppStrings.choose('Expenses', 'Chi tiêu'),
              value: formatOverviewCompactMoney(expense),
              color: expenseColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewComparisonBar extends StatelessWidget {
  const _OverviewComparisonBar({required this.factor, required this.color});

  final double factor;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: factor.clamp(.06, 1.0),
        widthFactor: .82,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ),
    ),
  );
}

class _OverviewComparisonLabel extends StatelessWidget {
  const _OverviewComparisonLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFA9C1B9)
                  : const Color(0xFF4B5B57),
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 5 : 7,
      vertical: compact ? 2 : 3,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: compact ? 8.5 : 9.5,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

class _OverviewNamedIconRow extends StatelessWidget {
  const _OverviewNamedIconRow({
    required this.label,
    required this.color,
    this.icon,
    this.iconWidget,
  }) : assert(icon != null || iconWidget != null);

  final String label;
  final Color color;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: iconWidget ?? Icon(icon, size: 17, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF4FBF8)
                : const Color(0xFF1A1C1E),
          ),
        ),
      ),
    ],
  );
}

// Kept with the legacy Bento implementation for visual rollback.
// ignore: unused_element
class _OverviewActivityBars extends StatelessWidget {
  const _OverviewActivityBars({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<int>(0, math.max);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: 2),
            Expanded(
              child: Container(
                height: maximum == 0
                    ? 4
                    : math.max(
                        4,
                        constraints.maxHeight * values[index] / maximum,
                      ),
                decoration: BoxDecoration(
                  color: index == values.length - 1
                      ? color
                      : color.withValues(alpha: .30),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Kept with the legacy Bento implementation for visual rollback.
// ignore: unused_element
class _OverviewRecurringTimeline extends StatelessWidget {
  const _OverviewRecurringTimeline({
    required this.schedules,
    required this.color,
  });

  final List<RecurringSchedule> schedules;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 4,
                right: 4,
                child: Container(
                  height: 1,
                  color: color.withValues(alpha: .30),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < schedules.length; index++)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color:
                                schedules[index].postingMode ==
                                    RecurringPostingMode.review
                                ? const Color(0xFFFF6B4A)
                                : index == 0
                                ? color
                                : color.withValues(alpha: .55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            for (final schedule in schedules)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _overviewDueLabel(schedule.nextOccurrence),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: _overviewDueColor(schedule.nextOccurrence),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Kept with the legacy Bento implementation for visual rollback.
// ignore: unused_element
class _OverviewCashFlowBars extends StatelessWidget {
  const _OverviewCashFlowBars({
    required this.values,
    required this.incomeColor,
    required this.expenseColor,
  });

  final List<({int income, int expense})> values;
  final Color incomeColor;
  final Color expenseColor;

  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<int>(
      0,
      (current, item) => math.max(current, math.max(item.income, item.expense)),
    );
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    3,
                    (_) => Divider(
                      height: 1,
                      color: incomeColor.withValues(alpha: .10),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in values)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _OverviewBar(
                              heightFactor: maximum == 0
                                  ? 0
                                  : item.income / maximum,
                              color: incomeColor,
                            ),
                            const SizedBox(width: 2),
                            _OverviewBar(
                              heightFactor: maximum == 0
                                  ? 0
                                  : item.expense / maximum,
                              color: expenseColor,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: List.generate(
            values.length,
            (index) => Expanded(
              child: Text(
                'W${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFA9C1B9)
                      : const Color(0xFF40534F),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewBar extends StatelessWidget {
  const _OverviewBar({required this.heightFactor, required this.color});

  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: heightFactor <= 0 ? .05 : heightFactor.clamp(.08, 1.0),
    child: Container(
      width: 6,
      decoration: BoxDecoration(
        color: heightFactor <= 0 ? color.withValues(alpha: .16) : color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    ),
  );
}

// Kept with the legacy Bento implementation for visual rollback.
// ignore: unused_element
class _OverviewLegend extends StatelessWidget {
  const _OverviewLegend({
    required this.income,
    required this.expense,
    required this.incomeColor,
    required this.expenseColor,
  });

  final int income;
  final int expense;
  final Color incomeColor;
  final Color expenseColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _item(AppStrings.choose('Income', 'Thu'), income, incomeColor),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: _item(
          AppStrings.choose('Expenses', 'Chi'),
          expense,
          expenseColor,
        ),
      ),
    ],
  );

  Widget _item(String label, int value, Color color) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          '$label ${formatOverviewCompactMoney(value)}',
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

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

class _SwipeToDeleteTransaction extends StatefulWidget {
  const _SwipeToDeleteTransaction({
    required super.key,
    required this.child,
    required this.onDelete,
  });

  final Widget child;
  final Future<void> Function() onDelete;

  @override
  State<_SwipeToDeleteTransaction> createState() =>
      _SwipeToDeleteTransactionState();
}

class _SwipeToDeleteTransactionState extends State<_SwipeToDeleteTransaction>
    with TickerProviderStateMixin {
  static const _actionExtent = 58.0;
  static const _cornerOverlap = 22.0;
  late final AnimationController _slideController;
  late final AnimationController _removeController;
  var _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _removeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _removeController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDeleting) return;
    _slideController.value =
        (_slideController.value - details.primaryDelta! / _actionExtent).clamp(
          0.0,
          1.0,
        );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isDeleting) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        velocity < -250 || (velocity <= 250 && _slideController.value >= 0.38);
    _slideController.animateTo(shouldOpen ? 1 : 0, curve: Curves.easeOutCubic);
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    await _removeController.animateTo(0, curve: Curves.easeInOutCubic);
    try {
      await widget.onDelete();
    } catch (_) {
      if (!mounted) return;
      await _removeController.animateTo(1, curve: Curves.easeOutCubic);
      await _slideController.animateBack(0, curve: Curves.easeOutCubic);
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _removeController,
        curve: Curves.easeInOutCubic,
      ),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _removeController,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _slideController,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _actionExtent + _cornerOverlap,
                      child: Material(
                        color: const Color(0xFFBA1A1A),
                        child: InkWell(
                          key: const Key('swipe-delete-transaction-button'),
                          onTap: _isDeleting ? null : _delete,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _cornerOverlap,
                            ),
                            child: Semantics(
                              button: true,
                              label: AppStrings.choose(
                                'Delete transaction',
                                'Xóa giao dịch',
                              ),
                              child: Center(
                                child: _isDeleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const FinFlowTrashIcon(
                                        color: Colors.white,
                                        size: 24,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  builder: (context, child) => Align(
                    alignment: Alignment.centerRight,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: _slideController.value,
                        child: IgnorePointer(
                          ignoring: _slideController.value < 0.9,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _slideController,
                child: widget.child,
                builder: (context, child) => Transform.translate(
                  offset: Offset(-_actionExtent * _slideController.value, 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    child: PhysicalModel(
                      shape: BoxShape.rectangle,
                      color: const Color(0xFFF3F7F5),
                      elevation: 0,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: child,
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

class _AnimatedTrendIcon extends StatefulWidget {
  const _AnimatedTrendIcon({
    required this.icon,
    required this.color,
    required this.isIncome,
    required this.stagger,
    required this.enabled,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final bool isIncome;
  final Duration stagger;
  final bool enabled;
  final double size;

  @override
  State<_AnimatedTrendIcon> createState() => _AnimatedTrendIconState();
}

class _AnimatedTrendIconState extends State<_AnimatedTrendIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _lastShouldAnimate;
  var _startEpoch = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedTrendIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.stagger != widget.stagger) {
      _lastShouldAnimate = null;
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate =
        widget.enabled && TickerMode.valuesOf(context).enabled && !reduceMotion;
    if (_lastShouldAnimate == shouldAnimate) return;
    _lastShouldAnimate = shouldAnimate;
    final epoch = ++_startEpoch;
    _controller
      ..stop()
      ..value = 0;
    if (!shouldAnimate) return;

    if (widget.stagger == Duration.zero) {
      _controller.repeat();
      return;
    }
    Future<void>.delayed(widget.stagger, () {
      if (!mounted || epoch != _startEpoch || _lastShouldAnimate != true) {
        return;
      }
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _startEpoch++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staticIcon = Icon(
      widget.icon,
      size: widget.size,
      color: widget.color,
    );
    if (_lastShouldAnimate != true) return staticIcon;

    return AnimatedBuilder(
      animation: _controller,
      child: staticIcon,
      builder: (context, child) {
        const movingFraction = 450 / 1600;
        const returningEnd = 900 / 1600;
        final value = _controller.value;
        final double travel;
        if (value <= movingFraction) {
          travel = Curves.easeInOut.transform(value / movingFraction);
        } else if (value <= returningEnd) {
          travel =
              1 -
              Curves.easeInOut.transform(
                (value - movingFraction) / movingFraction,
              );
        } else {
          travel = 0;
        }
        final target = Offset(2, widget.isIncome ? -3 : 3);
        return Transform.translate(
          offset: target * travel,
          child: Opacity(opacity: .75 + (.25 * travel), child: child),
        );
      },
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.pressedOverlayColor,
    this.borderRadius,
    this.tapHandledByChild = false,
    this.pressedScale = .97,
    this.pressedOpacity = .82,
    this.pressedOffset = Offset.zero,
    this.duration = const Duration(milliseconds: 110),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? pressedOverlayColor;
  final BorderRadius? borderRadius;
  final bool tapHandledByChild;
  final double pressedScale;
  final double pressedOpacity;
  final Offset pressedOffset;
  final Duration duration;

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
    final animatedChild = AnimatedSlide(
      offset: _pressed ? widget.pressedOffset : Offset.zero,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1,
          duration: widget.duration,
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

    if (widget.tapHandledByChild) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: animatedChild,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: animatedChild,
    );
  }
}

enum _CashFlowPeriod {
  daily,
  weekly,
  monthly,
  allTime;

  String get label => switch (this) {
    daily => AppStrings.choose('Today', 'Hôm nay'),
    weekly => AppStrings.choose('This Week', 'Tuần này'),
    monthly => AppStrings.choose('This Month', 'Tháng này'),
    allTime => AppStrings.choose('All Time', 'Từ đầu đến nay'),
  };

  String get optionTitle => switch (this) {
    daily => AppStrings.daily,
    weekly => AppStrings.weekly,
    monthly => AppStrings.monthly,
    allTime => AppStrings.choose('All time', 'Từ đầu đến nay'),
  };

  String get description => switch (this) {
    daily => AppStrings.choose(
      'Balance, income and expenses recorded today',
      'Số dư, thu nhập và chi tiêu ghi nhận hôm nay',
    ),
    weekly => AppStrings.choose(
      'Balance, income and expenses recorded this week',
      'Số dư, thu nhập và chi tiêu ghi nhận tuần này',
    ),
    monthly => AppStrings.choose(
      'Balance, income and expenses recorded this month',
      'Số dư, thu nhập và chi tiêu ghi nhận tháng này',
    ),
    allTime => AppStrings.choose(
      'Current balance and all recorded transactions',
      'Số dư hiện tại và toàn bộ giao dịch đã ghi nhận',
    ),
  };

  IconData get icon => switch (this) {
    daily => Icons.schedule_rounded,
    weekly => Icons.calendar_today_outlined,
    monthly => Icons.account_balance_wallet_outlined,
    allTime => Icons.history_rounded,
  };
}

class _SummaryPeriodOptionCard extends StatefulWidget {
  const _SummaryPeriodOptionCard({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final _CashFlowPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SummaryPeriodOptionCard> createState() =>
      _SummaryPeriodOptionCardState();
}

class _SummaryPeriodOptionCardState extends State<_SummaryPeriodOptionCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final radius = BorderRadius.circular(16);
    return AnimatedScale(
      scale: _pressed ? .98 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 76,
        decoration: BoxDecoration(
          color: selected ? goalPrimary : goalSurfaceLow,
          borderRadius: radius,
          border: Border.all(
            color: selected ? Colors.transparent : goalOutline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            splashColor: selected
                ? Colors.white.withValues(alpha: .14)
                : goalPrimary.withValues(alpha: .12),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F6F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.period.icon,
                      size: 21,
                      color: const Color(0xFF007A5E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.period.optionTitle,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : goalText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.period.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: 13,
                            height: 1.1,
                            color: selected
                                ? const Color(0xFF94EACA)
                                : goalMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? goalSuccess : Colors.transparent,
                      shape: BoxShape.circle,
                      border: selected
                          ? null
                          : Border.all(color: goalOutline, width: 2),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryGoalBadge extends StatelessWidget {
  const _PrimaryGoalBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: Responsive.h(context, 28),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFFFBF47) : const Color(0xFFF9C74F),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isDark ? const Color(0xFFFFBF47) : const Color(0xFFD99A00),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: Responsive.w(context, 14),
            color: isDark ? const Color(0xFF16352E) : const Color(0xFF4A3500),
          ),
          SizedBox(width: Responsive.w(context, 4)),
          Text(
            AppStrings.choose('Primary', 'Ưu tiên'),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 11),
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF16352E) : const Color(0xFF4A3500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPrimaryGoalBorder extends StatefulWidget {
  const _AnimatedPrimaryGoalBorder({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<_AnimatedPrimaryGoalBorder> createState() =>
      _AnimatedPrimaryGoalBorderState();
}

class _AnimatedPrimaryGoalBorderState extends State<_AnimatedPrimaryGoalBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable == _disableAnimations && _controller.isAnimating) return;
    _disableAnimations = disable;
    if (disable) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _RunningGoldBorderPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
            showTracer: !_disableAnimations,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RunningGoldBorderPainter extends CustomPainter {
  const _RunningGoldBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.showTracer,
  });

  final double progress;
  final double borderRadius;
  final bool showTracer;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(1),
          Radius.circular(math.max(0, borderRadius - 1)),
        ),
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = showTracer ? 1.5 : 2
        ..color = showTracer
            ? const Color(0xFFD99A00)
            : const Color(0xFFFFD84D),
    );
    if (!showTracer) return;

    final metric = path.computeMetrics().first;
    final segmentLength = math.min(58.0, metric.length * .18);
    final start = progress * metric.length;
    final end = start + segmentLength;
    final segment = Path();
    if (end <= metric.length) {
      segment.addPath(metric.extractPath(start, end), Offset.zero);
    } else {
      segment
        ..addPath(metric.extractPath(start, metric.length), Offset.zero)
        ..addPath(metric.extractPath(0, end - metric.length), Offset.zero);
    }

    canvas.drawPath(
      segment,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x66FFD84D)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawPath(
      segment,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFD84D),
    );
  }

  @override
  bool shouldRepaint(covariant _RunningGoldBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        borderRadius != oldDelegate.borderRadius ||
        showTracer != oldDelegate.showTracer;
  }
}

enum _SummaryMetric {
  revenue('Revenue', 'Thu nhập'),
  expense('Expense', 'Chi tiêu');

  const _SummaryMetric(this.englishLabel, this.vietnameseLabel);
  final String englishLabel;
  final String vietnameseLabel;
  String get label => AppStrings.choose(englishLabel, vietnameseLabel);
}

enum _SummaryPeriod {
  day('Day', 'Ngày'),
  week('Week', 'Tuần'),
  month('Month', 'Tháng'),
  year('Year', 'Năm');

  const _SummaryPeriod(this.englishLabel, this.vietnameseLabel);
  final String englishLabel;
  final String vietnameseLabel;
  String get label => AppStrings.choose(englishLabel, vietnameseLabel);
}

class _DateRange {
  const _DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
