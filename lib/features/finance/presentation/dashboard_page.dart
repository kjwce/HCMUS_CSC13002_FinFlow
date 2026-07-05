import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/transaction_category.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DashboardPage
// ══════════════════════════════════════════════════════════════════════════════

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _dataLoaded = false;
  bool _mounted = false;

  // ── Per‑chart period filters ──
  ChartPeriod _p1 = ChartPeriod.month; // Chart 1: Income/Expense line
  ChartPeriod _p2 = ChartPeriod.month; // Chart 2: Expense donut
  ChartPeriod _p3 = ChartPeriod.month; // Chart 3: Expense bar
  ChartPeriod _p4 = ChartPeriod.month; // Chart 4: Income source
  ChartPeriod _p5 = ChartPeriod.month; // Chart 5: Grouped bar

  // ── Toggles ──
  bool _showBalance = false; // Chart 1: show balance line
  bool _incomeDetailView = false; // Chart 4: bar vs donut

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
        if (_mounted) setState(() => _dataLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      // Show a compact loading indicator instead of partial render
      return Material(
        color: Colors.transparent,
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
    final ws = ref.watch(walletServiceProvider);
    final wallets = ws.currentUserWallets;

    // ── Danh sách items trong scroll view (dùng ListView.builder để lazy render) ──
    final items = <Widget>[
      SizedBox(height: Responsive.h(context, 16)),
      // ── Chart 1: Income & Expense Line ──
      RepaintBoundary(child: _buildIncomeExpenseLineChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 2: Expense Donut ──
      RepaintBoundary(child: _buildExpenseDonutChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 3: Expense Bar ──
      RepaintBoundary(child: _buildExpenseBarChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 4: Income by Source ──
      RepaintBoundary(child: _buildIncomeSourceChart(ts, wallets)),
      SizedBox(height: Responsive.h(context, 14)),
      // ── Chart 5: Income vs Expense Grouped Bar ──
      RepaintBoundary(child: _buildIncomeVsExpenseChart(ts)),
      SizedBox(height: Responsive.h(context, 14)),
      SizedBox(height: Responsive.h(context, 40)),
    ];

    return Material(
      color: Colors.transparent,
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
    required ChartPeriod period,
    required ValueChanged<ChartPeriod> onPeriodChanged,
    required Widget chart,
    Widget? trailing,
    double chartHeight = 200,
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
              if (trailing case final t?) t,
            ],
          ),
          SizedBox(height: Responsive.h(context, 8)),
          _PeriodFilter(period: period, onChanged: onPeriodChanged),
          SizedBox(height: Responsive.h(context, 12)),
          SizedBox(
            height: Responsive.h(context, chartHeight),
            child: scrollable
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: _chartWidth(context, period),
                      child: chart,
                    ),
                  )
                : chart,
          ),
        ],
      ),
    );
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 4),
        vertical: Responsive.h(context, 12),
      ),
      decoration: const BoxDecoration(
        color: AppColors.dashboardHeaderBg,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.darkGreenText,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
          ),
          Text(
            'Dashboard',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
              fontSize: Responsive.sp(context, 18),
              color: AppColors.darkGreenText,
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
    final buckets = ts.periodBuckets(_p1);
    final hasData = buckets.any((b) => b.income > 0 || b.expense > 0);

    return _buildChartCard(
      title: 'Income & Expense',
      scrollable: true,
      period: _p1,
      onPeriodChanged: (v) => setState(() => _p1 = v),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Balance',
            style: TextStyle(
              fontSize: Responsive.sp(context, 11),
              color: AppColors.mutedGray,
            ),
          ),
          SizedBox(width: Responsive.w(context, 4)),
          Material(
            type: MaterialType.transparency,
            child: _CustomToggle(
              value: _showBalance,
              onChanged: (v) => setState(() => _showBalance = v),
            ),
          ),
        ],
      ),
      chart: hasData ? _buildLineChartBody(buckets) : _emptyPlaceholder(),
    );
  }

  Widget _buildLineChartBody(List<PeriodBucket> buckets) {
    final spotsIncome = <FlSpot>[];
    final spotsExpense = <FlSpot>[];
    final spotsBalance = <FlSpot>[];

    for (int i = 0; i < buckets.length; i++) {
      final x = i.toDouble();
      spotsIncome.add(FlSpot(x, buckets[i].income.toDouble()));
      spotsExpense.add(FlSpot(x, buckets[i].expense.toDouble()));
      spotsBalance.add(FlSpot(x, buckets[i].balance.toDouble()));
    }

    // Compute Y range
    double dataMin = 0;
    double dataMax = 0;
    for (final b in buckets) {
      dataMax = math.max(dataMax, b.income.toDouble());
      dataMax = math.max(dataMax, b.expense.toDouble());
      if (_showBalance) {
        dataMax = math.max(dataMax, b.balance.toDouble());
        dataMin = math.min(dataMin, b.balance.toDouble());
      }
    }
    final range = dataMax - dataMin;
    final pad = range > 0 ? range * 0.15 : (dataMax > 0 ? dataMax * 0.3 : 1000);
    final adjMin = (dataMin - pad).clamp(0.0, double.infinity);
    final adjMax = _safeMax(dataMax + pad, adjMin);
    if (adjMin == 0 && adjMax == 0) return _emptyPlaceholder();

    return LineChart(
      LineChartData(
        lineBarsData: [
          _lineBar(spotsIncome, AppColors.primaryGreen, 'Income'),
          _lineBar(spotsExpense, AppColors.coral, 'Expense'),
          if (_showBalance)
            _lineBar(spotsBalance, AppColors.chartBlueBorder, 'Balance',
                dashArray: const [6, 4]),
        ],
        minX: 0,
        maxX: (buckets.length - 1).toDouble(),
        minY: adjMin,
        maxY: adjMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceAxisInterval(adjMax - adjMin, 4),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox();
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.w(context, 4)),
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
                if (i < 0 || i >= buckets.length) return const SizedBox();
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
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final idx = touchedSpots.first.spotIndex;
              final b = buckets[idx];
              final items = <LineTooltipItem?>[
                LineTooltipItem(
                  b.label,
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
                      style: TextStyle(
                        color: AppColors.coral,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: '\nBalance: ${_formatVNDCompact(b.balance)}',
                      style: TextStyle(
                        color: _showBalance ? AppColors.chartBlueBorder : AppColors.mutedGray,
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
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
        show: spots.length <= 8,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
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

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 2 — Tỷ lệ chi tiêu theo danh mục (Donut Chart — fl_chart PieChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildExpenseDonutChart(TransactionService ts) {
    final catExpense = ts.expenseByCategoryForPeriod(_p2);
    final totalExpense = catExpense.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: 'Expense by Category',
      period: _p2,
      onPeriodChanged: (v) => setState(() => _p2 = v),
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

    // Sort descending
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Merge small slices < 5% into "Khác"
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
        value: e.value.toDouble(),
        color: color,
        radius: isTouched ? 65 : 55,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
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
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: Responsive.w(context, 50),
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
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
        // Legend
        Padding(
          padding: EdgeInsets.only(top: Responsive.h(context, 8)),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: Responsive.w(context, 12),
            runSpacing: Responsive.h(context, 4),
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
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: Responsive.w(context, 8),
                    height: Responsive.w(context, 8),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  SizedBox(width: Responsive.w(context, 4)),
                  Flexible(
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
              );
            }).toList(),
          ),
        ),
      ],
    );
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
  // CHART 3 — Chi tiêu từng danh mục (Horizontal Bar Chart — fl_chart BarChart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildExpenseBarChart(TransactionService ts) {
    final catExpense = ts.expenseByCategoryForPeriod(_p3);
    final totalExpense = catExpense.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: 'Expense Breakdown',
      period: _p3,
      onPeriodChanged: (v) => setState(() => _p3 = v),
      chartHeight: 280,
      chart: totalExpense > 0
          ? _buildHorizBarBody(catExpense, totalExpense)
          : _emptyPlaceholder(),
    );
  }

  Widget _buildHorizBarBody(Map<String, int> catExpense, int total) {
    // Sort descending, take top 8
    final sorted = catExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();

    final maxVal = top.isEmpty ? 100.0 : top.first.value.toDouble();
    final adjMax = _safeMax(maxVal * 1.2, 0);

    return BarChart(
      BarChartData(
        rotationQuarterTurns: 1,
        alignment: BarChartAlignment.spaceAround,
        maxY: adjMax,
        minY: 0,
        barGroups: top.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final cat = TransactionCategory.fromKey(e.key);
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                color: cat.color,
                width: Responsive.w(context, 16),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        // rotationQuarterTurns = 1 → which side maps where:
        //   topTitles   → LEFT   (category names)
        //   rightTitles → BOTTOM (value labels)
        //   leftTitles  → TOP    (hidden)
        //   bottomTitles→ RIGHT  (hidden)
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: Responsive.w(context, 60),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= top.length) return const SizedBox();
                final cat = TransactionCategory.fromKey(top[i].key);
                final label = cat.label;
                final display = label.length > 10
                    ? '${label.substring(0, 9)}..'
                    : label;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    display,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value <= 0) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatCompact(value.toInt()),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 9),
                      color: AppColors.mutedGray,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.darkGray.withValues(alpha: 0.92),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = top[group.x];
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              return BarTooltipItem(
                '${TransactionCategory.fromKey(e.key).label}\n'
                '${_formatVNDCompact(e.value)}  (${pct.toStringAsFixed(1)}%)',
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 4 — Thu nhập theo nguồn (Donut + Bar toggle)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeSourceChart(TransactionService ts, List<WalletModel> wallets) {
    // Compute by-type grouping from wallet-level data for accuracy
    final byWallet = ts.incomeByWalletForPeriod(_p4);
    final byType = <String, int>{'bank': 0, 'ewallet': 0, 'cash': 0};
    for (final e in byWallet.entries) {
      final wallet = WalletService.instance.byId(e.key);
      final type = wallet?.type.name ?? 'bank';
      byType.update(type, (v) => v + e.value, ifAbsent: () => e.value);
    }
    byType.removeWhere((_, v) => v == 0);
    final totalIncome = byType.values.fold(0, (a, b) => a + b);

    return _buildChartCard(
      title: 'Income by Source',
      period: _p4,
      onPeriodChanged: (v) => setState(() => _p4 = v),
      chart: totalIncome > 0
          ? _buildDonutBody(
              byType,
              totalIncome,
              _touchedIncomePieIndex,
              (i) => setState(() => _touchedIncomePieIndex = i),
              Colors.transparent,
              useCategoryColors: false,
              isIncome: true,
            )
          : _emptyPlaceholder(),
    );
  }

  Widget _buildIncomeBarBody(TransactionService ts, List<WalletModel> wallets, ChartPeriod period) {
    final byWallet = ts.incomeByWalletForPeriod(period);
    if (byWallet.isEmpty) return _emptyPlaceholder();

    final sorted = byWallet.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = _safeMax(sorted.first.value.toDouble() * 1.2, 0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal,
        minY: 0,
        barGroups: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final wallet = WalletService.instance.byId(e.key);
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                color: wallet?.brandColor ?? AppColors.primaryGreen,
                width: Responsive.w(context, 18),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) {
                if (v <= 0) return const SizedBox();
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.w(context, 4)),
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
                if (i < 0 || i >= sorted.length) return const SizedBox();
                final wallet = WalletService.instance.byId(sorted[i].key);
                final label = wallet?.shortName ?? sorted[i].key;
                return Padding(
                  padding: EdgeInsets.only(top: Responsive.h(context, 4)),
                  child: Text(
                    label.length > 6 ? '${label.substring(0, 5)}..' : label,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 9),
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
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = sorted[group.x];
              final wallet = WalletService.instance.byId(e.key);
              return BarTooltipItem(
                '${wallet?.name ?? e.key}\n${_formatVNDCompact(e.value)}',
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART 5 — So sánh Thu/Chi theo kỳ (Grouped Bar Chart)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeVsExpenseChart(TransactionService ts) {
    final buckets = ts.periodBuckets(_p5);
    final hasData = buckets.any((b) => b.income > 0 || b.expense > 0);

    return _buildChartCard(
      title: 'Income vs Expense',
      scrollable: true,
      period: _p5,
      onPeriodChanged: (v) => setState(() => _p5 = v),
      chart: hasData ? _buildGroupedBarBody(buckets) : _emptyPlaceholder(),
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
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: b.income.toDouble(),
                      color: AppColors.primaryGreen,
                      width: Responsive.w(context, 12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: b.expense.toDouble(),
                      color: AppColors.coral,
                      width: Responsive.w(context, 12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) {
                      if (v <= 0) return const SizedBox();
                      return Padding(
                        padding: EdgeInsets.only(right: Responsive.w(context, 4)),
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
                  getTooltipColor: (_) => AppColors.darkGray.withValues(alpha: 0.92),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          style: TextStyle(color: AppColors.primaryGreen, fontSize: 11),
                        ),
                        TextSpan(
                          text: '\n● Expense: ${_formatVNDCompact(exp.toInt())}',
                          style: TextStyle(color: AppColors.coral, fontSize: 11),
                        ),
                        TextSpan(
                          text: '\n${isSurplus ? "✅ Surplus" : "⚠️ Deficit"}: ${_formatVNDCompact(diff.abs().toInt())}',
                          style: TextStyle(
                            color: isSurplus ? AppColors.primaryGreen : AppColors.coral,
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
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
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

  static double _niceAxisInterval(double range, int targetSteps) {
    if (range <= 0) return 1;
    final roughStep = range / targetSteps;
    final magnitude = math.pow(10, (math.log(roughStep) / math.ln10).floor()).toDouble();
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

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// _PeriodFilter — reusable widget
// ══════════════════════════════════════════════════════════════════════════════

class _CustomToggle extends StatelessWidget {
  const _CustomToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppColors.primaryGreen : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({
    required this.period,
    required this.onChanged,
  });

  final ChartPeriod period;
  final ValueChanged<ChartPeriod> onChanged;

  static const _labels = ['Day', 'Week', 'Month', 'Year'];
  static const _values = [
    ChartPeriod.day,
    ChartPeriod.week,
    ChartPeriod.month,
    ChartPeriod.year,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 4)),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final isSelected = period == _values[i];
            return GestureDetector(
              onTap: () => onChanged(_values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 14),
                  vertical: Responsive.h(context, 6),
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : AppColors.darkText,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
