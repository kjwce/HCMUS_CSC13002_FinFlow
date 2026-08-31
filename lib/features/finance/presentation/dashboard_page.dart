import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/category_donut_breakdown.dart';
import '../models/transaction_category.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DashboardPage
// ══════════════════════════════════════════════════════════════════════════════

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const _darkPage = Color(0xFF081C18);
  static const _darkSurface = Color(0xFF16352E);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkHeader = Color(0xFF005C49);
  static const _darkText = Color(0xFFF4FBF8);
  static const _darkSecondaryText = Color(0xFFA9C1B9);
  static const _darkIncome = Color(0xFF38D6AC);
  static const _darkExpense = Color(0xFFFF6B70);
  static const _darkBalance = Color(0xFF5B9BFF);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg => _isDark ? _darkPage : const Color(0xFFE4F4ED);
  Color get _headerBg => _isDark ? _darkPage : const Color(0xFFE4F4ED);
  Color get _surfaceContainer => _isDark ? _darkPage : const Color(0xFFEEEEF0);
  Color get _outlineVariant =>
      _isDark ? _darkSecondaryText : const Color(0xFFBBCAC2);
  Color get _onSurface => _isDark ? _darkText : const Color(0xFF1A1C1E);
  Color get _onSurfaceVariant =>
      _isDark ? _darkSecondaryText : const Color(0xFF3C4A44);
  Color get _primary => _isDark ? _darkText : const Color(0xFF00513E);
  Color get _chartHeader => _isDark ? _darkHeader : const Color(0xFF07513F);
  Color get _income => _isDark ? _darkIncome : const Color(0xFF00C49A);
  Color get _expense => _isDark ? _darkExpense : const Color(0xFFFF6B6B);
  Color get _balance => _isDark ? _darkBalance : const Color(0xFF4A90E2);
  Color get _segmentBg => _isDark ? _darkSurface : const Color(0xFFEEEEF0);

  bool _dataLoaded = false;
  bool _mounted = false;

  ChartPeriod _period = ChartPeriod.month;
  int _offset = 0;
  Timer? _refreshTimer;
  DateTime _lastRefreshDate = DateTime.now();
  bool _chartValuesVisible = false;

  // ── Toggles ──
  // ── Touch state ──
  int _touchedLineIndex = -1; // Chart 1
  int _touchedPieIndex = -1; // Chart 2
  int _touchedIncomePieIndex = -1; // Chart 4 donut

  @override
  void initState() {
    super.initState();
    _mounted = true;
    // Trigger data fetch — HomeScreen may not have been visited yet.
    Future.microtask(() async {
      try {
        await Future.wait([
          ref.read(transactionServiceProvider).fetchTransactions(),
          ref.read(walletServiceProvider).fetchWallets(),
        ]);
      } catch (e) {
        debugPrint('Dashboard fetch error: $e');
      } finally {
        if (_mounted) {
          setState(() => _dataLoaded = true);
          _runChartValueAnimation();
          _startRefreshTimer();
        }
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final oldDate = _lastRefreshDate;
      final periodChanged =
          now.day != oldDate.day ||
          _isoWeek(now) != _isoWeek(oldDate) ||
          now.month != oldDate.month ||
          now.year != oldDate.year;
      if (periodChanged && _mounted) {
        setState(() => _lastRefreshDate = now);
      }
    });
  }

  int _isoWeek(DateTime d) {
    final startOfYear = DateTime(d.year, 1, 1);
    final diff = d.difference(startOfYear).inDays;
    return (diff / 7).ceil() + 1;
  }

  @override
  void dispose() {
    _mounted = false;
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _runChartValueAnimation() {
    if (!_dataLoaded || !_mounted) return;
    setState(() => _chartValuesVisible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        setState(() => _chartValuesVisible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      // Show a compact loading indicator instead of partial render
      return Material(
        color: _pageBg,
        child: Column(
          children: [
            _buildHeader(),
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final ts = ref.watch(transactionServiceProvider);
    ref.watch(walletServiceProvider);

    // ── Danh sách items trong scroll view (dùng ListView.builder để lazy render) ──
    final items = <Widget>[SizedBox(height: Responsive.h(context, 24))];
    items.addAll([
      // ── Chart 1: Income, Expense & Balance Line ──
      RepaintBoundary(child: _buildIncomeExpenseLineChart(ts)),
      SizedBox(height: Responsive.h(context, 24)),
    ]);
    items.addAll([
      // ── Chart 2: Income Donut ──
      RepaintBoundary(child: _buildIncomeDonutChart(ts)),
      SizedBox(height: Responsive.h(context, 24)),
      // ── Chart 3: Expense Donut ──
      RepaintBoundary(child: _buildExpenseDonutChart(ts)),
      SizedBox(height: Responsive.h(context, 24)),
      // ── Chart 4: Income & Expense by Source ──
      RepaintBoundary(child: _buildSourceGroupedBarChart(ts)),
      SizedBox(height: Responsive.h(context, 24)),
      // ── Chart 5: Income vs Expense Grouped Bar ──
      RepaintBoundary(child: _buildIncomeVsExpenseChart(ts)),
      SizedBox(height: Responsive.h(context, 24)),
      SizedBox(height: Responsive.h(context, 48)),
    ]);

    return Material(
      color: _pageBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) => items[index],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Reusable helpers
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    double chartHeight = 200,
  }) {
    final radiusValue = Responsive.w(context, 28);
    final cardRadius = BorderRadius.circular(radiusValue);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: _isDark
                ? const Color(0x33000000)
                : _primary.withValues(alpha: 0.07),
            blurRadius: _isDark ? 12 : 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: _isDark ? _darkSurface : Colors.white,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: _isDark ? _darkBorder : _primary.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 12),
              ),
              decoration: BoxDecoration(
                color: _chartHeader,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radiusValue),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _isDark ? _darkBorder : _chartHeader,
                  ),
                ),
              ),
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, 18),
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(Responsive.w(context, 20)),
              decoration: BoxDecoration(
                color: _isDark
                    ? _darkSurface
                    : Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(radiusValue),
                ),
              ),
              child: SizedBox(
                height: Responsive.h(context, chartHeight),
                child: chart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(ChartPeriod period, int offset) {
    final now = DateTime.now();
    switch (period) {
      case ChartPeriod.day:
        final d = now.subtract(Duration(days: -offset));
        return offset == 0
            ? AppStrings.choose('Today', 'Hôm nay')
            : '${d.day}/${d.month}/${d.year}';
      case ChartPeriod.week:
        final weekStart = now.subtract(
          Duration(days: now.weekday - 1 + (-offset * 7)),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        return offset == 0
            ? AppStrings.choose('This week', 'Tuần này')
            : '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}';
      case ChartPeriod.month:
        final d = DateTime(now.year, now.month + offset);
        return offset == 0
            ? '${_monthName(now.month)} ${now.year}'
            : '${_monthName(d.month)} ${d.year}';
      case ChartPeriod.year:
        return '${now.year + offset}';
    }
  }

  String _monthName(int month) {
    if (AppStrings.isVietnamese) return 'Tháng $month';
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  Widget _emptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: Responsive.sp(context, 40),
            color: (_isDark ? _darkSecondaryText : AppColors.mutedGray)
                .withValues(alpha: 0.5),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Text(
            AppStrings.choose('No data', 'Không có dữ liệu'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.sp(context, 13),
              color: _isDark ? _darkSecondaryText : AppColors.mutedGray,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. Sticky mint header
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        topInset + Responsive.h(context, 8),
        Responsive.w(context, 20),
        Responsive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: _headerBg,
        border: _isDark
            ? const Border(bottom: BorderSide(color: Color(0x4D29483F)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: _primary),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: AppStrings.choose('Back', 'Quay lại'),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: Responsive.w(context, 8)),
              Text(
                AppStrings.choose('Financial Insights', 'Phân tích tài chính'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(context, 22),
                  color: _primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _pickDashboardDate,
                tooltip: AppStrings.choose('Choose date', 'Chọn ngày'),
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 21,
                  color: _primary,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.w(context, 4)),
            decoration: BoxDecoration(
              color: _segmentBg,
              borderRadius: BorderRadius.circular(99),
              border: _isDark ? Border.all(color: _darkBorder) : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labels = [
                  AppStrings.daily,
                  AppStrings.weekly,
                  AppStrings.monthly,
                ];
                final periods = [
                  ChartPeriod.day,
                  ChartPeriod.week,
                  ChartPeriod.month,
                ];
                final selectedIndex = periods.indexOf(_period);
                final tabWidth = constraints.maxWidth / labels.length;

                return SizedBox(
                  height: Responsive.h(context, 44),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: tabWidth * selectedIndex,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          margin: EdgeInsets.all(Responsive.w(context, 1)),
                          decoration: BoxDecoration(
                            color: _isDark ? _darkHeader : _primary,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: (_isDark ? _darkHeader : _primary)
                                    .withValues(alpha: 0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: labels.asMap().entries.map((entry) {
                          final index = entry.key;
                          final isSelected = selectedIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final nextPeriod = periods[index];
                                if (_period == nextPeriod) return;
                                setState(() {
                                  _period = nextPeriod;
                                  _offset = 0;
                                  _touchedLineIndex = -1;
                                });
                                _runChartValueAnimation();
                              },
                              child: Center(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontSize: Responsive.sp(context, 13),
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? _darkText
                                        : _onSurfaceVariant,
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
          ),
          SizedBox(height: Responsive.h(context, 10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _canGoBackward ? () => _shiftPeriod(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: _primary,
              ),
              SizedBox(
                width: Responsive.w(context, 170),
                child: Text(
                  _periodLabel(_period, _offset),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _offset < 0 ? () => _shiftPeriod(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: _primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canGoBackward {
    final limit = switch (_period) {
      ChartPeriod.day => -365,
      ChartPeriod.week => -52,
      ChartPeriod.month => -24,
      ChartPeriod.year => -5,
    };
    return _offset > limit;
  }

  void _shiftPeriod(int delta) {
    setState(() {
      _offset = (_offset + delta).clamp(-365, 0);
      _touchedLineIndex = -1;
    });
    _runChartValueAnimation();
  }

  Future<void> _pickDashboardDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    final offset = switch (_period) {
      ChartPeriod.day => DateUtils.dateOnly(
        picked,
      ).difference(DateUtils.dateOnly(now)).inDays,
      ChartPeriod.week =>
        (picked
                    .subtract(Duration(days: picked.weekday - 1))
                    .difference(now.subtract(Duration(days: now.weekday - 1)))
                    .inDays /
                7)
            .round(),
      ChartPeriod.month =>
        (picked.year - now.year) * 12 + picked.month - now.month,
      ChartPeriod.year => picked.year - now.year,
    };
    setState(() {
      _offset = math.min(0, offset);
      _touchedLineIndex = -1;
    });
    _runChartValueAnimation();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 1 — Income & Expense Line Chart (fl_chart LineChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeExpenseLineChart(TransactionService ts) {
    final buckets = ts.periodBuckets(_period, offset: _offset);
    final hasData = buckets.any((b) => b.income > 0 || b.expense > 0);

    return _buildChartCard(
      title: AppStrings.choose(
        'Income, Expense & Balance',
        'Thu nhập, chi tiêu và số dư',
      ),
      chartHeight: 230,
      chart: hasData
          ? Column(
              children: [
                Expanded(child: _buildLineChartBody(buckets)),
                SizedBox(height: Responsive.h(context, 14)),
                Row(
                  children: [
                    _legendPill(
                      _balance,
                      AppStrings.choose('Balance', 'Số dư'),
                      selected: true,
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    _legendPill(_income, AppStrings.income),
                    SizedBox(width: Responsive.w(context, 8)),
                    _legendPill(_expense, AppStrings.expense),
                  ],
                ),
              ],
            )
          : _emptyPlaceholder(),
    );
  }

  Widget _legendPill(Color color, String label, {bool selected = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 10),
        vertical: Responsive.h(context, 6),
      ),
      decoration: BoxDecoration(
        color: _isDark
            ? _darkSurface
            : selected
            ? const Color(0xFFD3E3FF)
            : _surfaceContainer.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
        border: _isDark ? Border.all(color: _darkBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 10),
              fontWeight: FontWeight.w600,
              color: _onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartBody(List<PeriodBucket> buckets) {
    if (buckets.isEmpty) return _emptyPlaceholder();

    var cashflowMax = 0.0;
    var balanceMin = buckets.first.balance.toDouble();
    var balanceMax = balanceMin;
    for (final bucket in buckets) {
      cashflowMax = math.max(cashflowMax, bucket.income.toDouble());
      cashflowMax = math.max(cashflowMax, bucket.expense.toDouble());
      balanceMin = math.min(balanceMin, bucket.balance.toDouble());
      balanceMax = math.max(balanceMax, bucket.balance.toDouble());
    }

    final cashflowAxisMax = _niceCeiling(
      cashflowMax <= 0 ? 1000000 : cashflowMax * 1.12,
    );
    final rawBalanceRange = balanceMax - balanceMin;
    final balancePadding = rawBalanceRange > 0
        ? rawBalanceRange * .16
        : math.max(balanceMax.abs() * .04, 500000);
    final balanceAxisMin = balanceMin - balancePadding;
    final balanceAxisMax = balanceMax + balancePadding;
    final balanceAxisRange = math.max(1.0, balanceAxisMax - balanceAxisMin);

    final spotsIncome = <FlSpot>[];
    final spotsExpense = <FlSpot>[];
    final spotsBalance = <FlSpot>[];

    for (int i = 0; i < buckets.length; i++) {
      final x = i.toDouble();
      final incomeY = buckets[i].income / cashflowAxisMax;
      final expenseY = buckets[i].expense / cashflowAxisMax;
      final balanceY = (buckets[i].balance - balanceAxisMin) / balanceAxisRange;
      spotsIncome.add(FlSpot(x, _chartValuesVisible ? incomeY : 0));
      spotsExpense.add(FlSpot(x, _chartValuesVisible ? expenseY : 0));
      spotsBalance.add(FlSpot(x, _chartValuesVisible ? balanceY : 0));
    }

    final selectedIndex = _touchedLineIndex >= 0
        ? _touchedLineIndex.clamp(0, buckets.length - 1)
        : -1;
    final selectedIndicators = selectedIndex >= 0
        ? <int>[selectedIndex]
        : const <int>[];
    final lineBars = [
      _lineBar(
        spotsIncome,
        _income,
        AppStrings.income,
        showingIndicators: selectedIndicators,
      ),
      _lineBar(
        spotsExpense,
        _expense,
        AppStrings.expense,
        showingIndicators: selectedIndicators,
      ),
      _lineBar(
        spotsBalance,
        _balance,
        AppStrings.choose('Balance', 'Số dư'),
        width: 3,
        showingIndicators: selectedIndicators,
      ),
    ];
    final showingTooltips = selectedIndex >= 0
        ? [
            ShowingTooltipIndicators([
              LineBarSpot(lineBars[2], 2, lineBars[2].spots[selectedIndex]),
              LineBarSpot(lineBars[0], 0, lineBars[0].spots[selectedIndex]),
              LineBarSpot(lineBars[1], 1, lineBars[1].spots[selectedIndex]),
            ]),
          ]
        : const <ShowingTooltipIndicators>[];

    return LineChart(
      LineChartData(
        lineBarsData: lineBars,
        showingTooltipIndicators: showingTooltips,
        minX: 0,
        maxX: math.max(1, buckets.length - 1).toDouble(),
        minY: 0,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: .5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: _isDark
                ? _darkBorder.withValues(alpha: .65)
                : _primary.withValues(alpha: .10),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: .5,
              reservedSize: Responsive.w(context, 38),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatAxisVnd(cashflowAxisMax * value),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 10),
                    fontWeight: FontWeight.w600,
                    color: _onSurfaceVariant.withValues(alpha: .86),
                  ),
                ),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: .5,
              reservedSize: Responsive.w(context, 42),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatAxisVnd(balanceAxisMin + balanceAxisRange * value),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 10),
                    fontWeight: FontWeight.w700,
                    color: _isDark ? _darkBalance : const Color(0xFF2878CF),
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: Responsive.h(context, 26),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 ||
                    index >= buckets.length ||
                    !_showLineXAxisLabel(index, buckets.length)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: Responsive.h(context, 6),
                  child: Text(
                    _localizedBucketLabel(buckets[index]),
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 10),
                      fontWeight: FontWeight.w600,
                      color: _onSurfaceVariant.withValues(alpha: .86),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchSpotThreshold: Responsive.w(context, 22),
          touchCallback: (event, response) {
            if (event is! FlTapDownEvent &&
                event is! FlPanUpdateEvent &&
                event is! FlLongPressMoveUpdate) {
              return;
            }
            final spots = response?.lineBarSpots;
            final nextIndex = spots == null || spots.isEmpty
                ? -1
                : spots.first.spotIndex;
            if (nextIndex == _touchedLineIndex || !_mounted) return;
            setState(() => _touchedLineIndex = nextIndex);
          },
          getTouchLineStart: (_, _) => 1,
          getTouchLineEnd: (_, _) => 0,
          getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
              .map(
                (_) => TouchedSpotIndicatorData(
                  FlLine(
                    color: _isDark
                        ? _darkBorder
                        : _primary.withValues(alpha: .18),
                    strokeWidth: 1,
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: _isDark ? _darkSurface : Colors.white,
                          strokeWidth: 2,
                          strokeColor: bar.color ?? _primary,
                        ),
                  ),
                ),
              )
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _isDark ? _darkHeader : _primary,
            tooltipRoundedRadius: 8,
            tooltipMargin: 8,
            maxContentWidth: Responsive.w(context, 132),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final idx = touchedSpots.first.spotIndex.clamp(
                0,
                buckets.length - 1,
              );
              final b = buckets[idx];
              final title = _tooltipBucketTitle(b);
              final balanceText = _formatVNDCompact(b.balance);
              final incomeText = _formatVNDCompact(b.income);
              final expenseText = _formatVNDCompact(b.expense);
              final amountWidth = math.max(
                balanceText.length,
                math.max(incomeText.length, expenseText.length),
              );
              String rightAligned(String value) => value.padLeft(amountWidth);
              final divider = '─' * (amountWidth + 7);
              final items = <LineTooltipItem?>[
                LineTooltipItem(
                  title,
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '\n$divider\n',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .16),
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: AppStrings.choose('Bal:', 'Số dư:'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    TextSpan(
                      text: '   ${rightAligned(balanceText)}\n',
                      style: TextStyle(color: _balance, fontSize: 11),
                    ),
                    TextSpan(
                      text: AppStrings.choose('Inc:', 'Thu:'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    TextSpan(
                      text: '   ${rightAligned(incomeText)}\n',
                      style: TextStyle(color: _income, fontSize: 11),
                    ),
                    TextSpan(
                      text: AppStrings.choose('Exp:', 'Chi:'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    TextSpan(
                      text: '   ${rightAligned(expenseText)}',
                      style: TextStyle(color: _expense, fontSize: 11),
                    ),
                  ],
                ),
              ];
              // Return null entries for remaining touched spots so only 1 tooltip is shown
              for (int i = 1; i < touchedSpots.length; i++) {
                items.add(null);
              }
              return items;
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
    );
  }

  bool _showLineXAxisLabel(int index, int bucketCount) {
    return switch (_period) {
      ChartPeriod.day => index % 4 == 0,
      ChartPeriod.week => true,
      ChartPeriod.month => const {1, 7, 14, 21, 28}.contains(index + 1),
      ChartPeriod.year => true,
    };
  }

  LineChartBarData _lineBar(
    List<FlSpot> spots,
    Color color,
    String label, {
    List<int>? dashArray,
    double width = 2.5,
    List<int> showingIndicators = const [],
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dashArray: dashArray,
      showingIndicators: showingIndicators,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  String _tooltipBucketTitle(PeriodBucket bucket) {
    final start = bucket.start;
    if (start == null) return _localizedBucketLabel(bucket);
    if (_period == ChartPeriod.month) {
      return '${start.day} ${_monthName(start.month)}';
    }
    if (_period == ChartPeriod.week) {
      return '${_localizedBucketLabel(bucket)}, '
          '${start.day} ${_monthName(start.month)}';
    }
    if (_period == ChartPeriod.day) return _localizedBucketLabel(bucket);
    return '${start.day}/${start.month}/${start.year}';
  }

  String _localizedBucketLabel(PeriodBucket bucket) {
    final start = bucket.start;
    if (_period != ChartPeriod.week || start == null) return bucket.label;
    return switch (start.weekday) {
      DateTime.monday => AppStrings.choose('Mon', 'T2'),
      DateTime.tuesday => AppStrings.choose('Tue', 'T3'),
      DateTime.wednesday => AppStrings.choose('Wed', 'T4'),
      DateTime.thursday => AppStrings.choose('Thu', 'T5'),
      DateTime.friday => AppStrings.choose('Fri', 'T6'),
      DateTime.saturday => AppStrings.choose('Sat', 'T7'),
      DateTime.sunday => AppStrings.choose('Sun', 'CN'),
      _ => bucket.label,
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 2 — Tỷ lệ thu nhập theo danh mục (Donut Chart — fl_chart PieChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeDonutChart(TransactionService ts) {
    final catIncome = ts.incomeByCategoryForPeriod(_period, offset: _offset);
    final totalIncome = catIncome.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: AppStrings.choose('Income by Category', 'Thu nhập theo danh mục'),
      chartHeight: _donutChartHeight(catIncome, totalIncome),
      chart: totalIncome > 0
          ? _buildDonutBody(
              catIncome,
              totalIncome,
              _touchedIncomePieIndex,
              (i) => setState(() => _touchedIncomePieIndex = i),
              isIncome: true,
            )
          : _emptyPlaceholder(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 3 — Tỷ lệ chi tiêu theo danh mục (Donut Chart — fl_chart PieChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildExpenseDonutChart(TransactionService ts) {
    final catExpense = ts.expenseByCategoryForPeriod(_period, offset: _offset);
    final totalExpense = catExpense.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: AppStrings.choose('Expense by Category', 'Chi tiêu theo danh mục'),
      chartHeight: _donutChartHeight(catExpense, totalExpense),
      chart: totalExpense > 0
          ? _buildDonutBody(catExpense, totalExpense, _touchedPieIndex, (i) {
              setState(() => _touchedPieIndex = i);
            })
          : _emptyPlaceholder(),
    );
  }

  /// Shared donut builder used by Chart 2 and Chart 4.
  Widget _buildDonutBody(
    Map<String, int> data,
    int total,
    int touchedIndex,
    ValueChanged<int> onTouch, {
    bool isIncome = false,
  }) {
    if (data.isEmpty) return _emptyPlaceholder();

    final breakdown = CategoryDonutBreakdown(data, total);
    final detailEntries = breakdown.detailedEntries;
    final chartEntries = breakdown.chartEntries;
    final palette = isIncome
        ? _isDark
              ? const [
                  _darkIncome,
                  Color(0xFF86C232),
                  Color(0xFF36A2A8),
                  Color(0xFF007A5E),
                  Color(0xFFA3D65C),
                  Color(0xFF5C8D89),
                  Color(0xFF45B97C),
                  Color(0xFFB1C94E),
                  Color(0xFF2E8B78),
                  Color(0xFF78958B),
                  Color(0xFF19A974),
                  Color(0xFF6FAF45),
                  Color(0xFF248F9D),
                  Color(0xFFC1A83B),
                  Color(0xFF577D70),
                ]
              : const [
                  Color(0xFF00C49A),
                  Color(0xFF86C232),
                  Color(0xFF36A2A8),
                  Color(0xFF007A5E),
                  Color(0xFFA3D65C),
                  Color(0xFF5C8D89),
                  Color(0xFF45B97C),
                  Color(0xFFB1C94E),
                  Color(0xFF2E8B78),
                  Color(0xFF8A9690),
                  Color(0xFF19A974),
                  Color(0xFF6FAF45),
                  Color(0xFF248F9D),
                  Color(0xFFC1A83B),
                  Color(0xFF577D70),
                ]
        : _isDark
        ? const [
            _darkExpense,
            _darkBalance,
            Color(0xFFFFBF47),
            Color(0xFFB58CFF),
            Color(0xFFFF9457),
            Color(0xFF36B5A0),
            Color(0xFFEF5DA8),
            Color(0xFF5B6EE1),
            Color(0xFFB8A12E),
            Color(0xFF78958B),
            Color(0xFF26A69A),
            Color(0xFFE76F51),
            Color(0xFF7E57C2),
            Color(0xFF42A5F5),
            Color(0xFFA1887F),
          ]
        : const [
            Color(0xFFFF6B6B),
            Color(0xFF4A90E2),
            Color(0xFFFBBF24),
            Color(0xFF9B72CF),
            Color(0xFFFF8A4C),
            Color(0xFF36B5A0),
            Color(0xFFEF5DA8),
            Color(0xFF5B6EE1),
            Color(0xFFB8A12E),
            Color(0xFF7A8B85),
            Color(0xFF26A69A),
            Color(0xFFE76F51),
            Color(0xFF7E57C2),
            Color(0xFF42A5F5),
            Color(0xFFA1887F),
          ];

    final sections = chartEntries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final isTouched = touchedIndex == i;
      final color = palette[i % palette.length];

      return PieChartSectionData(
        value: _chartValuesVisible ? e.value.toDouble() : e.value * 0.001,
        color: color,
        radius: _chartValuesVisible
            ? Responsive.w(context, isTouched ? 68 : 63)
            : 0,
        title: '',
        borderSide: BorderSide(
          color: _isDark ? _darkSurface : Colors.white,
          width: isTouched ? 2 : 0,
        ),
      );
    }).toList();

    final touchedEntry = touchedIndex >= 0 && touchedIndex < chartEntries.length
        ? chartEntries[touchedIndex]
        : null;
    final centerLabel = touchedEntry == null
        ? AppStrings.choose('Total', 'Tổng')
        : touchedEntry.key == belowOnePercentBucketKey
        ? AppStrings.choose('Below 1%', 'Nhóm dưới 1%')
        : AppStrings.categoryName(touchedEntry.key);
    final centerValue = touchedEntry?.value ?? total;
    final isDenseLegend = detailEntries.length > 5;
    final isVeryDenseLegend = detailEntries.length > 8;

    return Row(
      crossAxisAlignment: detailEntries.length > 5
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: Responsive.w(context, 160),
          child: Column(
            children: [
              SizedBox(
                width: Responsive.w(context, 160),
                height: Responsive.w(context, 160),
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 0,
                    sectionsSpace: 3,
                    startDegreeOffset: _chartValuesVisible ? -90 : -450,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          onTouch(-1);
                          return;
                        }
                        onTouch(response!.touchedSection!.touchedSectionIndex);
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                ),
              ),
              SizedBox(height: Responsive.h(context, 10)),
              Text(
                centerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 11.5),
                  fontWeight: FontWeight.w700,
                  color: _onSurfaceVariant,
                ),
              ),
              SizedBox(height: Responsive.h(context, 2)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: _formatChartCompact(centerValue)),
                      TextSpan(
                        text: ' VND',
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 10),
                          fontWeight: FontWeight.w700,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 18),
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: Responsive.w(context, 16)),
        Expanded(
          child: Column(
            mainAxisAlignment: detailEntries.length > 5
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: detailEntries.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final chartIndex = breakdown.chartIndexForDetailedEntry(e);
              final color = palette[chartIndex % palette.length];
              final category = TransactionCategory.resolve(e.key);
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.h(
                    context,
                    isVeryDenseLegend ? 2.5 : (isDenseLegend ? 4 : 7),
                  ),
                ),
                child: Row(
                  children: [
                    category.buildIcon(
                      size: Responsive.sp(
                        context,
                        isVeryDenseLegend ? 14 : (isDenseLegend ? 16 : 18),
                      ),
                      color: color,
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Expanded(
                      child: Text(
                        AppStrings.categoryName(e.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(
                            context,
                            isVeryDenseLegend
                                ? 10.5
                                : (isDenseLegend ? 12 : 13),
                          ),
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                    ),
                    Text(
                      breakdown.percentageLabel(i),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: Responsive.sp(
                          context,
                          isVeryDenseLegend ? 10.5 : (isDenseLegend ? 12 : 13),
                        ),
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  double _donutChartHeight(Map<String, int> data, int total) {
    if (total <= 0 || data.isEmpty) return 180;
    final count = data.length;
    final rowHeight = count > 8 ? 25.0 : (count > 5 ? 29.0 : 34.0);
    return math.max(225, count * rowHeight);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 4 — Thu/chi theo nguồn tiền (Horizontal Grouped Bar)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSourceGroupedBarChart(TransactionService ts) {
    final income = ts.incomeByWalletTypeForPeriod(_period, offset: _offset);
    final expense = ts.expenseByWalletTypeForPeriod(_period, offset: _offset);
    final sources = [
      'cash',
      'transfer',
    ].where((s) => (income[s] ?? 0) > 0 || (expense[s] ?? 0) > 0).toList();
    final hasData = sources.isNotEmpty;

    return _buildChartCard(
      title: AppStrings.choose(
        'Income & Expense by Source',
        'Thu nhập và chi tiêu theo nguồn',
      ),
      chartHeight: math.max(94, sources.length * 94),
      chart: hasData
          ? _buildSourceGroupedBarBody(sources, income, expense)
          : _emptyPlaceholder(),
    );
  }

  Widget _buildSourceGroupedBarBody(
    List<String> sources,
    Map<String, int> income,
    Map<String, int> expense,
  ) {
    double maxVal = 0;
    for (final source in sources) {
      maxVal = math.max(maxVal, (income[source] ?? 0).toDouble());
      maxVal = math.max(maxVal, (expense[source] ?? 0).toDouble());
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: sources.map((source) {
        final incomeValue = income[source] ?? 0;
        final expenseValue = expense[source] ?? 0;
        return Padding(
          padding: EdgeInsets.only(bottom: Responsive.h(context, 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    source == 'cash'
                        ? Icons.payments_outlined
                        : Icons.account_balance_outlined,
                    size: 19,
                    color: _primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _sourceLabel(source),
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 13),
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(context, 10)),
              _sourceBar(incomeValue, maxVal, _income),
              SizedBox(height: Responsive.h(context, 7)),
              _sourceBar(expenseValue, maxVal, _expense),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sourceBar(int value, double maxValue, Color color) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 11,
            decoration: BoxDecoration(
              color: _surfaceContainer.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              widthFactor: _chartValuesVisible ? ratio : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: Responsive.w(context, 12)),
        SizedBox(
          width: Responsive.w(context, 82),
          child: Text(
            _formatVndFull(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 10),
              fontWeight: FontWeight.w700,
              color: _onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'transfer':
        return AppStrings.choose('Bank Transfer', 'Chuyển khoản ngân hàng');
      case 'cash':
        return AppStrings.choose('Cash', 'Tiền mặt');
      default:
        return source;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 5 — So sánh Thu/Chi theo kỳ (Grouped Bar Chart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeVsExpenseChart(TransactionService ts) {
    final range = ts.dateRangeForPeriod(_period, offset: _offset);
    final income = ts.incomeBetween(range.start, range.end);
    final expense = ts.expenseBetween(range.start, range.end);
    final hasData = income > 0 || expense > 0;

    return _buildChartCard(
      title: AppStrings.choose(
        'Total Income vs Expense',
        'Tổng thu nhập so với chi tiêu',
      ),
      chartHeight: 250,
      chart: hasData
          ? _buildIncomeComparisonBody(income, expense)
          : _emptyPlaceholder(),
    );
  }

  Widget _buildIncomeComparisonBody(int income, int expense) {
    final maxValue = math.max(income, expense);
    final net = income - expense;
    final incomeHeight = maxValue <= 0 ? 0.0 : 110.0 * income / maxValue;
    final expenseHeight = maxValue <= 0 ? 0.0 : 110.0 * expense / maxValue;
    final incomeIsHigher = income >= expense;
    final base = incomeIsHigher ? expense : income;
    final differencePercent = base <= 0
        ? 100
        : ((income - expense).abs() / base * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 10),
            vertical: Responsive.h(context, 5),
          ),
          decoration: BoxDecoration(
            color: _income.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            AppStrings.choose(
              'Net Cash Flow: ${net >= 0 ? '+' : '-'}${_formatVndFull(net.abs())} VND',
              'Dòng tiền ròng: ${net >= 0 ? '+' : '-'}${_formatVndFull(net.abs())} VND',
            ),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 10),
              fontWeight: FontWeight.w700,
              color: net >= 0 ? _income : _expense,
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 14)),
        SizedBox(
          height: Responsive.h(context, 160),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: Responsive.h(context, 34),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => Container(
                      height: 1,
                      color: _isDark
                          ? _darkBorder.withValues(alpha: .55)
                          : _primary.withValues(alpha: .06),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _comparisonBar(
                    value: income,
                    height: incomeHeight,
                    label: AppStrings.income,
                    icon: Icons.payments_outlined,
                    colors: _isDark
                        ? const [_darkIncome, _darkIncome]
                        : const [Color(0xFF006C53), Color(0xFF00CFA6)],
                  ),
                  SizedBox(width: Responsive.w(context, 46)),
                  _comparisonBar(
                    value: expense,
                    height: expenseHeight,
                    label: AppStrings.expense,
                    icon: Icons.shopping_cart_outlined,
                    colors: _isDark
                        ? const [_darkExpense, _darkExpense]
                        : const [Color(0xFFD83B3B), Color(0xFFFF7A70)],
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: Responsive.h(context, 18),
          color: _isDark ? _darkBorder : const Color(0x1600513E),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              incomeIsHigher
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 19,
              color: incomeIsHigher ? _income : _expense,
            ),
            const SizedBox(width: 7),
            Text.rich(
              TextSpan(
                text: incomeIsHigher
                    ? AppStrings.choose('Income is ', 'Thu nhập ')
                    : AppStrings.choose('Expense is ', 'Chi tiêu '),
                children: [
                  TextSpan(
                    text: AppStrings.choose(
                      '$differencePercent% higher',
                      'cao hơn $differencePercent%',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: incomeIsHigher ? _income : _expense,
                    ),
                  ),
                  TextSpan(
                    text: incomeIsHigher
                        ? AppStrings.choose(' than expense', ' so với chi tiêu')
                        : AppStrings.choose(' than income', ' so với thu nhập'),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 11),
                color: _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _comparisonBar({
    required int value,
    required double height,
    required String label,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${_formatVndFull(value)} VND',
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 9),
            fontWeight: FontWeight.w700,
            color: colors.first,
          ),
        ),
        SizedBox(height: Responsive.h(context, 6)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          width: Responsive.w(context, 64),
          height: Responsive.h(context, _chartValuesVisible ? height : 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: colors,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
              bottom: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(context, 9)),
        Row(
          children: [
            Icon(icon, size: 17, color: _outlineVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 10),
                color: _outlineVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Formatting helpers
  // ════════════════════════════════════════════════════════════════════════════

  static double _niceCeiling(double value) {
    if (value <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(value) / math.ln10).floor())
        .toDouble();
    final normalized = value / magnitude;
    final step = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return step * magnitude;
  }

  static String _formatAxisVnd(double value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    if (absolute >= 1000000000) {
      return '$sign${_axisNumber(absolute / 1000000000)}B';
    }
    if (absolute >= 1000000) {
      return '$sign${_axisNumber(absolute / 1000000)}M';
    }
    if (absolute >= 1000) {
      return '$sign${_axisNumber(absolute / 1000)}K';
    }
    return '$sign${absolute.round()}';
  }

  static String _axisNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static String _formatVNDCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B₫';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K₫';
    }
    return '$amount₫';
  }

  static String _formatChartCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '$amount';
  }

  static String _formatVndFull(int amount) =>
      amount.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}
