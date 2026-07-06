import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
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
  static const _pageBg = Color(0xFFF9F9FC);
  static const _headerBg = Color(0xFFF9F9FC);
  static const _surfaceContainer = Color(0xFFEEEEF0);
  static const _outlineVariant = Color(0xFFBBCAC2);
  static const _onSurface = Color(0xFF1A1C1E);
  static const _onSurfaceVariant = Color(0xFF3C4A44);
  static const _primary = Color(0xFF00C49A);
  static const _segmentBg = _surfaceContainer;
  static const _segmentBorder = _outlineVariant;

  bool _dataLoaded = false;
  bool _mounted = false;

  ChartPeriod _period = ChartPeriod.month;
  int _offset = 0;
  Timer? _refreshTimer;
  DateTime _lastRefreshDate = DateTime.now();
  bool _chartValuesVisible = false;

  // ── Toggles ──
  // ── Touch state ──
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
    final items = <Widget>[SizedBox(height: Responsive.h(context, 16))];
    if (_period != ChartPeriod.day) {
      items.addAll([
        // ── Chart 1: Income, Expense & Balance Line ──
        RepaintBoundary(child: _buildIncomeExpenseLineChart(ts)),
        SizedBox(height: Responsive.h(context, 14)),
      ]);
    }
    items.addAll([
      // ── Chart 2: Income Donut ──
      RepaintBoundary(child: _buildIncomeDonutChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 3: Expense Donut ──
      RepaintBoundary(child: _buildExpenseDonutChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 4: Income & Expense by Source ──
      RepaintBoundary(child: _buildSourceGroupedBarChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 5: Income vs Expense Grouped Bar ──
      RepaintBoundary(child: _buildIncomeVsExpenseChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      SizedBox(height: Responsive.h(context, 40)),
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
    Widget? trailing,
    double chartHeight = 200,
    double? chartWidth,
    bool scrollable = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 12),
        Responsive.w(context, 16),
        Responsive.h(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 18,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 15),
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                color: _offset < 0
                    ? _onSurface
                    : AppColors.mutedGray.withValues(alpha: 0.4),
                onPressed: _offset > -12
                    ? () {
                        setState(() => _offset--);
                        _runChartValueAnimation();
                      }
                    : null,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Text(
                _periodLabel(_period, _offset),
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: _onSurfaceVariant,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                color: _offset < 0
                    ? _onSurface
                    : AppColors.mutedGray.withValues(alpha: 0.4),
                onPressed: _offset < 0
                    ? () {
                        setState(() => _offset++);
                        _runChartValueAnimation();
                      }
                    : null,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 12)),
          SizedBox(
            height: Responsive.h(context, chartHeight),
            child: scrollable
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth ?? _chartWidth(context, _period),
                      child: chart,
                    ),
                  )
                : chart,
          ),
        ],
      ),
    );
  }

  String _periodLabel(ChartPeriod period, int offset) {
    final now = DateTime.now();
    switch (period) {
      case ChartPeriod.day:
        final d = now.subtract(Duration(days: -offset));
        return offset == 0 ? 'Today' : '${d.day}/${d.month}/${d.year}';
      case ChartPeriod.week:
        final weekStart = now.subtract(
          Duration(days: now.weekday - 1 + (-offset * 7)),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        return offset == 0
            ? 'This week'
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
    const names = [
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
    return names[month - 1];
  }

  double _chartWidth(BuildContext context, ChartPeriod period) {
    switch (period) {
      case ChartPeriod.day:
        return Responsive.w(context, 360);
      case ChartPeriod.week:
        return Responsive.w(context, 360);
      case ChartPeriod.month:
        return Responsive.w(context, 660);
      case ChartPeriod.year:
        return Responsive.w(context, 400);
    }
  }

  Widget _emptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: Responsive.sp(context, 40),
            color: AppColors.mutedGray.withValues(alpha: 0.5),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Text(
            'No data',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.sp(context, 13),
              color: AppColors.mutedGray,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. Header (unchanged)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        topInset + Responsive.h(context, 16),
        Responsive.w(context, 20),
        Responsive.h(context, 16),
      ),
      decoration: const BoxDecoration(color: _headerBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: _onSurface,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: Responsive.w(context, 4)),
              Text(
                'Dashboard',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 20),
                  color: _onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 14)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.w(context, 4)),
            decoration: BoxDecoration(
              color: _segmentBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _segmentBorder.withValues(alpha: 0.55)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labels = ['Day', 'Week', 'Month'];
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
                            color: _primary,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.18),
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
                                });
                                _runChartValueAnimation();
                              },
                              child: Center(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: Responsive.sp(context, 14),
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
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
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 1 — Income & Expense Line Chart (fl_chart LineChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeExpenseLineChart(TransactionService ts) {
    final buckets = ts.periodBuckets(_period, offset: _offset);
    final hasData = buckets.any((b) => b.income > 0 || b.expense > 0);

    return _buildChartCard(
      title: 'Income, Expense & Balance',
      scrollable: true,
      chart: hasData ? _buildLineChartBody(buckets) : _emptyPlaceholder(),
    );
  }

  Widget _buildLineChartBody(List<PeriodBucket> buckets) {
    final spotsIncome = <FlSpot>[];
    final spotsExpense = <FlSpot>[];
    final spotsBalance = <FlSpot>[];

    for (int i = 0; i < buckets.length; i++) {
      final x = i.toDouble();
      spotsIncome.add(FlSpot(x, _animatedMillions(buckets[i].income)));
      spotsExpense.add(FlSpot(x, _animatedMillions(buckets[i].expense)));
      spotsBalance.add(FlSpot(x, _animatedMillions(buckets[i].balance)));
    }

    // Compute Y range
    double dataMin = 0;
    double dataMax = 0;
    for (final b in buckets) {
      final income = _toMillions(b.income);
      final expense = _toMillions(b.expense);
      final balance = _toMillions(b.balance);
      dataMax = math.max(dataMax, income);
      dataMax = math.max(dataMax, expense);
      dataMax = math.max(dataMax, balance);
      dataMin = math.min(dataMin, balance);
    }
    final range = dataMax - dataMin;
    final pad = range > 0 ? range * 0.15 : (dataMax > 0 ? dataMax * 0.3 : 1);
    final adjMin = (dataMin - pad).clamp(0.0, double.infinity);
    final adjMax = _safeMax(dataMax + pad, adjMin);
    if (adjMin == 0 && adjMax == 0) return _emptyPlaceholder();
    final yAxisInterval = _niceAxisInterval(adjMax - adjMin, 4);

    return LineChart(
      LineChartData(
        lineBarsData: [
          _lineBar(spotsIncome, AppColors.primaryGreen, 'Income'),
          _lineBar(spotsExpense, AppColors.coral, 'Expense'),
          _lineBar(
            spotsBalance,
            AppColors.chartBlueBorder,
            'Balance',
            dashArray: const [6, 4],
          ),
        ],
        minX: 0,
        maxX: (buckets.length - 1).toDouble(),
        minY: adjMin,
        maxY: adjMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yAxisInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yAxisInterval,
              reservedSize: 44,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox();
                if (v >= adjMax - yAxisInterval * 0.35) {
                  return const SizedBox();
                }
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.w(context, 4)),
                  child: Text(
                    '${_formatDecimal(v)}M',
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox();
                if (!_shouldShowLineXLabel(i, buckets.length)) {
                  return const SizedBox();
                }
                return Padding(
                  padding: EdgeInsets.only(top: Responsive.h(context, 4)),
                  child: Text(
                    buckets[i].label,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.darkGray.withValues(alpha: 0.92),
            tooltipRoundedRadius: 8,
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final idx = touchedSpots.first.spotIndex;
              final b = buckets[idx];
              final title = _tooltipBucketTitle(b);
              final items = <LineTooltipItem?>[
                LineTooltipItem(
                  title,
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '\nIncome: ${_formatVNDCompact(b.income)}',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: '\nExpense: ${_formatVNDCompact(b.expense)}',
                      style: TextStyle(color: AppColors.coral, fontSize: 11),
                    ),
                    TextSpan(
                      text: '\nBalance: ${_formatVNDCompact(b.balance)}',
                      style: TextStyle(
                        color: AppColors.chartBlueBorder,
                        fontSize: 11,
                      ),
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

  LineChartBarData _lineBar(
    List<FlSpot> spots,
    Color color,
    String label, {
    List<int>? dashArray,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dashArray: dashArray,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: spots.length > 12 ? 2 : 3,
            color: Colors.white,
            strokeWidth: 2,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  bool _shouldShowLineXLabel(int index, int bucketCount) {
    if (_period == ChartPeriod.week) return true;
    if (_period == ChartPeriod.month) {
      final day = index + 1;
      return day == 1 ||
          day == 7 ||
          day == 14 ||
          day == 21 ||
          day == 28 ||
          day == bucketCount;
    }
    return true;
  }

  String _tooltipBucketTitle(PeriodBucket bucket) {
    final start = bucket.start;
    if (start == null) return bucket.label;
    if (_period == ChartPeriod.month) {
      return '${start.day} ${_monthName(start.month)}';
    }
    if (_period == ChartPeriod.week) {
      return '${bucket.label}, ${start.day} ${_monthName(start.month)}';
    }
    return '${start.day}/${start.month}/${start.year}';
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 2 — Tỷ lệ thu nhập theo danh mục (Donut Chart — fl_chart PieChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeDonutChart(TransactionService ts) {
    final catIncome = ts.incomeByCategoryForPeriod(_period, offset: _offset);
    final totalIncome = catIncome.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: 'Income by Category',
      chartHeight: _donutChartHeight(catIncome, totalIncome),
      chart: totalIncome > 0
          ? _buildDonutBody(
              catIncome,
              totalIncome,
              _touchedIncomePieIndex,
              (i) => setState(() => _touchedIncomePieIndex = i),
              Colors.transparent,
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
      title: 'Expense by Category',
      chartHeight: _donutChartHeight(catExpense, totalExpense),
      chart: totalExpense > 0
          ? _buildDonutBody(catExpense, totalExpense, _touchedPieIndex, (i) {
              setState(() => _touchedPieIndex = i);
            }, Colors.transparent)
          : _emptyPlaceholder(),
    );
  }

  /// Shared donut builder used by Chart 2 and Chart 4.
  Widget _buildDonutBody(
    Map<String, int> data,
    int total,
    int touchedIndex,
    ValueChanged<int> onTouch,
    Color centerColor, {
    bool useCategoryColors = true,
    bool isIncome = false,
  }) {
    if (data.isEmpty) return _emptyPlaceholder();

    final mainEntries = _donutEntries(data, total);
    final donutRadius = Responsive.w(context, 48);
    final touchedDonutRadius = Responsive.w(context, 54);
    final centerSpaceRadius = Responsive.w(context, 40);
    final legendRows = _donutLegendRows(mainEntries.length);
    final legendHeight = _donutLegendHeight(legendRows);

    final sections = mainEntries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final isTouched = touchedIndex == i;
      final pct = (e.value / total * 100);
      Color color;
      if (useCategoryColors) {
        color = e.key == 'Other'
            ? Colors.grey
            : TransactionCategory.fromKey(e.key).color;
      } else {
        // Wallet type colors
        color = _walletTypeColor(e.key);
      }

      return PieChartSectionData(
        value: _chartValuesVisible ? e.value.toDouble() : e.value * 0.001,
        color: color,
        radius: _chartValuesVisible
            ? (isTouched ? touchedDonutRadius : donutRadius)
            : 0,
        title: _chartValuesVisible && isTouched
            ? '${pct.toStringAsFixed(1)}%'
            : '',
        titleStyle: TextStyle(
          fontSize: Responsive.sp(context, 11),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
        borderSide: isTouched
            ? BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: Responsive.h(context, 210),
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: centerSpaceRadius,
                  sectionsSpace: 2,
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
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatVNDCompact(total),
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 16),
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 10),
                        color: AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(context, 10)),
        SizedBox(
          height: Responsive.h(context, legendHeight),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = Responsive.w(context, 10);
              final itemWidth = math.max(
                (constraints.maxWidth - spacing) / 2,
                Responsive.w(context, 120),
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: Responsive.h(context, 8),
                  children: mainEntries.map((e) {
                    Color color;
                    if (useCategoryColors) {
                      color = e.key == 'Other'
                          ? Colors.grey
                          : TransactionCategory.fromKey(e.key).color;
                    } else {
                      color = _walletTypeColor(e.key);
                    }
                    final pct = (e.value / total * 100);
                    return SizedBox(
                      width: itemWidth,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: Responsive.w(context, 8),
                            height: Responsive.w(context, 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: Responsive.w(context, 6)),
                          Expanded(
                            child: Text(
                              '${e.key} ${pct.toStringAsFixed(1)}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Responsive.sp(context, 10),
                                color: AppColors.mutedGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, int>> _donutEntries(Map<String, int> data, int total) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final threshold = total * 0.05;
    final mainEntries = <MapEntry<String, int>>[];
    int otherSum = 0;

    for (final e in entries) {
      if (e.value < threshold && mainEntries.length >= 6) {
        otherSum += e.value;
      } else {
        mainEntries.add(e);
      }
    }
    if (otherSum > 0) {
      mainEntries.add(MapEntry('Other', otherSum));
    }
    return mainEntries;
  }

  int _donutLegendRows(int itemCount) => math.max(1, (itemCount / 2).ceil());

  double _donutLegendHeight(int rows) {
    const rowHeight = 18.0;
    const rowGap = 8.0;
    return rows * rowHeight + math.max(0, rows - 1) * rowGap;
  }

  double _donutChartHeight(Map<String, int> data, int total) {
    if (total <= 0 || data.isEmpty) return 200;
    final rows = _donutLegendRows(_donutEntries(data, total).length);
    return 210 + 10 + _donutLegendHeight(rows);
  }

  Color _walletTypeColor(String type) {
    switch (type) {
      case 'bank':
        return AppColors.ingBlue;
      case 'ewallet':
        return AppColors.primaryGreen;
      case 'cash':
        return AppColors.chartOrangeBorder;
      default:
        return AppColors.mutedGray;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 4 — Thu/chi theo nguồn tiền (Horizontal Grouped Bar)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSourceGroupedBarChart(TransactionService ts) {
    final income = ts.incomeByWalletTypeForPeriod(_period, offset: _offset);
    final expense = ts.expenseByWalletTypeForPeriod(_period, offset: _offset);
    final sources = [
      'bank',
      'ewallet',
      'cash',
    ].where((s) => (income[s] ?? 0) > 0 || (expense[s] ?? 0) > 0).toList();
    final hasData = sources.isNotEmpty;

    return _buildChartCard(
      title: 'Income & Expense by Source',
      chartHeight: 360,
      chartWidth: math.max(
        Responsive.w(context, 760),
        sources.length * Responsive.w(context, 220),
      ),
      scrollable: true,
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
    final maxY = _safeMax(maxVal * 1.2, 0);
    final axisInterval = _niceAxisInterval(maxY, 4);

    return BarChart(
      BarChartData(
        rotationQuarterTurns: 1,
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: sources.asMap().entries.map((entry) {
          final i = entry.key;
          final source = entry.value;
          return BarChartGroupData(
            x: i,
            barsSpace: 0,
            barRods: [
              BarChartRodData(
                toY: _animatedAmount(income[source] ?? 0),
                color: AppColors.primaryGreen,
                width: Responsive.w(context, 34),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              BarChartRodData(
                toY: _animatedAmount(expense[source] ?? 0),
                color: AppColors.coral,
                width: Responsive.w(context, 34),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: axisInterval,
              reservedSize: 44,
              getTitlesWidget: (v, meta) {
                if (v <= 0) return const SizedBox();
                if ((maxY - v).abs() < axisInterval * 0.35) {
                  return const SizedBox();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatCompact(v.toInt()),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 9),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: Responsive.w(context, 64),
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= sources.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _sourceLabel(sources[i]),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.darkGray.withValues(alpha: 0.92),
            tooltipRoundedRadius: 8,
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final source = sources[group.x];
              final label = rodIndex == 0 ? 'Income' : 'Expense';
              final value = rod.toY.toInt();
              return BarTooltipItem(
                '${_sourceLabel(source)}\n$label: ${_formatVNDCompact(value)}',
                TextStyle(
                  color: rod.color ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'bank':
        return 'Bank';
      case 'ewallet':
        return 'E-Wallet';
      case 'cash':
        return 'Cash';
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
      title: 'Total Income vs Expense',
      chartHeight: 260,
      chart: hasData
          ? _buildGroupedBarBody([
              PeriodBucket(
                label: _periodLabel(_period, _offset),
                income: income,
                expense: expense,
              ),
            ])
          : _emptyPlaceholder(),
    );
  }

  Widget _buildGroupedBarBody(List<PeriodBucket> buckets) {
    double maxVal = 0;
    for (final b in buckets) {
      maxVal = math.max(maxVal, b.income.toDouble());
      maxVal = math.max(maxVal, b.expense.toDouble());
    }
    final adjMax = _safeMax(maxVal * 1.2, 0);

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: adjMax,
              minY: 0,
              groupsSpace: Responsive.w(context, 8),
              barGroups: buckets.asMap().entries.map((entry) {
                final i = entry.key;
                final b = entry.value;
                return BarChartGroupData(
                  x: i,
                  barsSpace: Responsive.w(context, 8),
                  barRods: [
                    BarChartRodData(
                      toY: _animatedAmount(b.income),
                      color: AppColors.primaryGreen,
                      width: Responsive.w(context, 34),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    BarChartRodData(
                      toY: _animatedAmount(b.expense),
                      color: AppColors.coral,
                      width: Responsive.w(context, 34),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) {
                      if (v <= 0) return const SizedBox();
                      return Padding(
                        padding: EdgeInsets.only(
                          right: Responsive.w(context, 4),
                        ),
                        child: Text(
                          _formatCompact(v.toInt()),
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 10),
                            color: AppColors.mutedGray,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= buckets.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: Responsive.h(context, 4)),
                        child: Text(
                          buckets[i].label,
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 10),
                            color: AppColors.mutedGray,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.darkGray.withValues(alpha: 0.92),
                  tooltipRoundedRadius: 8,
                  tooltipMargin: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final b = buckets[group.x];
                    final inc = group.barRods[0].toY;
                    final exp = group.barRods[1].toY;
                    final diff = inc - exp;
                    final isSurplus = diff >= 0;
                    return BarTooltipItem(
                      b.label,
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: '\n● Income: ${_formatVNDCompact(inc.toInt())}',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text:
                              '\n● Expense: ${_formatVNDCompact(exp.toInt())}',
                          style: TextStyle(
                            color: AppColors.coral,
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text:
                              '\n${isSurplus ? "✅ Surplus" : "⚠️ Deficit"}: ${_formatVNDCompact(diff.abs().toInt())}',
                          style: TextStyle(
                            color: isSurplus
                                ? AppColors.primaryGreen
                                : AppColors.coral,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutBack,
          ),
        ),
        SizedBox(height: Responsive.h(context, 8)),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            legendDot(AppColors.primaryGreen, 'Income'),
            SizedBox(width: Responsive.w(context, 20)),
            legendDot(AppColors.coral, 'Expense'),
          ],
        ),
      ],
    );
  }

  Widget legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Responsive.w(context, 8),
          height: Responsive.w(context, 8),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: Responsive.w(context, 4)),
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.sp(context, 11),
            color: AppColors.mutedGray,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Formatting helpers
  // ════════════════════════════════════════════════════════════════════════════

  /// Ensure maxY > minY so fl_chart never gets zero-range that crashes the engine.
  static double _safeMax(double val, double min) {
    if (val > min) return val;
    return min + 1000; // fallback range
  }

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

  static String _formatCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  static double _toMillions(int amount) => amount / 1000000;

  double _animatedAmount(int amount) =>
      _chartValuesVisible ? amount.toDouble() : 0;

  double _animatedMillions(int amount) =>
      _chartValuesVisible ? _toMillions(amount) : 0;

  static String _formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static double _niceAxisInterval(double range, int targetSteps) {
    if (range <= 0) return 1;
    final roughStep = range / targetSteps;
    final magnitude = math
        .pow(10, (math.log(roughStep) / math.ln10).floor())
        .toDouble();
    final residual = roughStep / magnitude;
    double niceStep;
    if (residual <= 1.5) {
      niceStep = 1;
    } else if (residual <= 3) {
      niceStep = 2;
    } else if (residual <= 7) {
      niceStep = 5;
    } else {
      niceStep = 10;
    }
    return niceStep * magnitude;
  }
}
