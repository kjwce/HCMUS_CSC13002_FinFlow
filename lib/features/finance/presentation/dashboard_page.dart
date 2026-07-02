import 'dart:math' as math;

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

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  var _selectedPeriodFilter = 0;

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    final ws = ref.watch(walletServiceProvider);
    final wallets = ws.currentUserWallets;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: Responsive.h(context, 16)),
                _buildAccountBalanceCard(ts, wallets),
                SizedBox(height: Responsive.h(context, 14)),
                _buildEarningsSpentRow(ts, wallets),
                SizedBox(height: Responsive.h(context, 14)),
                _buildBarChart(ts, wallets),
                SizedBox(height: Responsive.h(context, 14)),
                _buildLineChart(ts),
                SizedBox(height: Responsive.h(context, 14)),
                _buildComparingPeriods(ts, wallets),
                SizedBox(height: Responsive.h(context, 40)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 1. Header Dashboard
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // 2. Account Balance Card (dynamic)
  // --------------------------------------------------------------------------
  Widget _buildAccountBalanceCard(TransactionService ts, List<WalletModel> wallets) {
    final balance = ts.totalBalance;
    final segments = wallets.map((w) => ts.balanceByWallet(w.id).toDouble()).toList();
    final colors = wallets.map((w) => w.brandColor).toList();
    final segSum = segments.fold(0.0, (a, b) => a + b);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      padding: EdgeInsets.all(Responsive.w(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total balance',
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedGray,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 4)),
                Text(
                  _formatCompact(balance),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 32),
                    color: AppColors.darkGray,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 14)),
                ...List.generate(wallets.length, (i) {
                  final w = wallets[i];
                  return Padding(
                    padding: EdgeInsets.only(bottom: Responsive.h(context, 8)),
                    child: _accountRow(w.shortName, _formatCompact(ts.balanceByWallet(w.id)), w.brandColor),
                  );
                }),
              ],
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          SizedBox(
            width: Responsive.w(context, 110),
            height: Responsive.w(context, 110),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (segSum > 0)
                  CustomPaint(
                    painter: _DonutPainter(
                      segments: segments,
                      segmentColors: colors,
                      holeRadiusRatio: 0.58,
                    ),
                  ),
                Text(
                  _formatCompact(balance),
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(String name, String value, Color color) {
    return Row(
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
        Text(
          '$name account: $value',
          style: TextStyle(
            fontSize: Responsive.sp(context, 14),
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 3. Earnings / Spent row (dynamic)
  // --------------------------------------------------------------------------
  Widget _buildEarningsSpentRow(TransactionService ts, List<WalletModel> wallets) {
    // Earnings: segment by wallet income this month
    final earningsSegments = wallets.map((w) => ts.monthlyIncomeByWallet(w.id).toDouble()).toList();
    final earningsColors = wallets.map((w) => w.brandColor).toList();
    final earningsLabels = wallets.map((w) => w.shortName).toList();

    // Spent: segment by top 3 categories this month
    final spentByCat = <String, int>{};
    for (final t in ts.currentUserTransactions.where((t) => t.amount < 0)) {
      spentByCat.update(t.category, (v) => v + t.amount.abs(), ifAbsent: () => t.amount.abs());
    }
    final sortedCats = spentByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(3).toList();
    final spentSegments = topCats.map((e) => e.value.toDouble()).toList();
    final spentColors = topCats.map((e) => TransactionCategory.fromKey(e.key).color).toList();
    final spentLabels = topCats.map((e) => e.key).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      child: Row(
        children: [
          Expanded(child: _buildMiniCard(
            title: 'Earnings this month',
            amount: _formatCompact(ts.monthlyIncome),
            segments: earningsSegments,
            segmentColors: earningsColors,
            labels: earningsLabels,
            labelColors: earningsColors,
          )),
          SizedBox(width: Responsive.w(context, 14)),
          Expanded(child: _buildMiniCard(
            title: 'Spent this month',
            amount: '-${_formatCompact(ts.monthlyExpense)}',
            segments: spentSegments.isEmpty ? [1] : spentSegments,
            segmentColors: spentColors.isEmpty ? [AppColors.accentTeal] : spentColors,
            labels: spentLabels.isEmpty ? ['None'] : spentLabels,
            labelColors: spentColors.isEmpty ? [AppColors.accentTeal] : spentColors,
          )),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String amount,
    required List<double> segments,
    required List<Color> segmentColors,
    required List<String> labels,
    required List<Color> labelColors,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
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
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.sp(context, 13),
              fontWeight: FontWeight.w500,
              color: AppColors.mutedGray,
            ),
          ),
          SizedBox(height: Responsive.h(context, 4)),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.sp(context, 18),
              color: AppColors.darkGray,
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          SizedBox(
            width: Responsive.w(context, 72),
            height: Responsive.w(context, 72),
            child: CustomPaint(
              painter: _DonutPainter(
                segments: segments,
                segmentColors: segmentColors,
                holeRadiusRatio: 0.55,
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 10)),
          ...List.generate(labels.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(context, 4)),
              child: Row(
                children: [
                  Container(
                    width: Responsive.w(context, 6),
                    height: Responsive.w(context, 6),
                    decoration: BoxDecoration(
                      color: labelColors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 4)),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 11),
                      fontWeight: FontWeight.w500,
                      color: labelColors[i],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. Balance Bar Chart (dynamic by wallet)
  // --------------------------------------------------------------------------
  Widget _buildBarChart(TransactionService ts, List<WalletModel> wallets) {
    final bars = wallets.map((w) {
      final bal = ts.balanceByWallet(w.id);
      return _BarItem(
        label: w.shortName,
        value: bal.abs().toDouble(),
        fill: w.brandColor.withValues(alpha: 0.18),
        border: w.brandColor,
      );
    }).toList();

    final maxVal = bars.isEmpty
        ? 100.0
        : bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 16),
        Responsive.w(context, 16),
        Responsive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
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
          Text(
            'Balance',
            style: TextStyle(
              fontSize: Responsive.sp(context, 15),
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 16)),
          SizedBox(
            height: Responsive.h(context, 180),
            child: bars.isEmpty
                ? const Center(child: Text('No wallets'))
                : CustomPaint(
                    painter: _BarChartPainter(bars: bars, maxValue: maxVal),
                  ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. This Month Balance Line Chart (real data)
  // --------------------------------------------------------------------------
  Widget _buildLineChart(TransactionService ts) {
    final now = DateTime.now();
    final dayCount = now.day;

    // 4 milestones: day 1, 10, 20, today
    final milestones = {1, 10, 20, dayCount}.toList()..sort();
    final points = milestones.map((d) {
      final date = DateTime(now.year, now.month, d, 23, 59, 59);
      return ts.balanceAtDate(date).toDouble();
    }).toList();

    final xLabels = milestones.map((d) => '$d ${_months[now.month - 1]}').toList();
    xLabels[xLabels.length - 1] = 'Today';

    final minY = points.isEmpty ? 0.0 : points.reduce((a, b) => a < b ? a : b);
    final maxY = points.isEmpty ? 100.0 : points.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(1.0, double.infinity);
    final adjustedMin = minY - padding;
    final adjustedMax = maxY + padding;
    final step = _niceStep(adjustedMax - adjustedMin, 4);

    final List<double> yLabels = [];
    for (double y = adjustedMin; y <= adjustedMax + 0.01; y += step) {
      yLabels.add(y);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 16),
        Responsive.w(context, 16),
        Responsive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
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
          Text(
            'This month balance',
            style: TextStyle(
              fontSize: Responsive.sp(context, 15),
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 16)),
          SizedBox(
            height: Responsive.h(context, 180),
            child: CustomPaint(
              painter: _LineChartPainter(
                points: points,
                xLabels: xLabels,
                yLabels: yLabels,
                lineColor: AppColors.primaryGreen,
                fillColor: AppColors.primaryGreen.withValues(alpha: 0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 6. Comparing Between Periods (dynamic)
  // --------------------------------------------------------------------------
  Widget _buildComparingPeriods(TransactionService ts, List<WalletModel> wallets) {
    final filterLabels = wallets.map((w) => w.shortName).toList();
    if (filterLabels.isEmpty) filterLabels.add('Cash');

    if (_selectedPeriodFilter >= filterLabels.length) {
      _selectedPeriodFilter = 0;
    }

    final now = DateTime.now();
    final selectedWalletId = _selectedPeriodFilter < wallets.length
        ? wallets[_selectedPeriodFilter].id
        : null;

    // Compute cumulative balance at N equally spaced points this year
    const dataPointCount = 8;
    final List<double> presentPoints = [];
    final List<double> oneYearAgoPoints = [];
    final List<double> twoYearsAgoPoints = [];

    for (int i = 0; i < dataPointCount; i++) {
      final frac = (i + 1) / dataPointCount;
      final dayOfYear = (frac * 365).round().clamp(1, 365);
      final presentDate = DateTime(now.year, 1, 1).add(Duration(days: dayOfYear - 1));
      final oneYearDate = DateTime(now.year - 1, 1, 1).add(Duration(days: dayOfYear - 1));
      final twoYearDate = DateTime(now.year - 2, 1, 1).add(Duration(days: dayOfYear - 1));

      if (presentDate.isBefore(now) || presentDate.day == now.day) {
        presentPoints.add(_balanceAtDateForWallet(ts, presentDate, selectedWalletId).toDouble());
      }
      oneYearAgoPoints.add(_balanceAtDateForWallet(ts, oneYearDate, selectedWalletId).toDouble());
      twoYearsAgoPoints.add(_balanceAtDateForWallet(ts, twoYearDate, selectedWalletId).toDouble());
    }

    // Pad to same length
    while (presentPoints.length < dataPointCount) {
      presentPoints.add(presentPoints.isEmpty ? 0 : presentPoints.last);
    }

    final allValues = [...presentPoints, ...oneYearAgoPoints, ...twoYearsAgoPoints];
    final minY = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(1.0, double.infinity);
    final adjustedMin = minY - padding;
    final adjustedMax = maxY + padding;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 16),
        Responsive.w(context, 16),
        Responsive.h(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
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
          Text(
            'Comparing between periods',
            style: TextStyle(
              fontSize: Responsive.sp(context, 15),
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          Container(
            padding: EdgeInsets.all(Responsive.w(context, 4)),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(filterLabels.length, (i) {
                final isSelected = _selectedPeriodFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPeriodFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 16),
                      vertical: Responsive.h(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      filterLabels[i],
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 12),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          SizedBox(
            height: Responsive.h(context, 180),
            child: CustomPaint(
              painter: _MultiLineChartPainter(
                presentPoints: presentPoints,
                oneYearAgoPoints: oneYearAgoPoints,
                twoYearsAgoPoints: twoYearsAgoPoints,
                minY: adjustedMin,
                maxY: adjustedMax,
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.chartBlueBorder, 'One year ago'),
              SizedBox(width: Responsive.w(context, 20)),
              _legendDot(AppColors.chartOrangeBorder, 'Two years ago'),
              SizedBox(width: Responsive.w(context, 20)),
              _legendDot(AppColors.primaryGreen, 'Present'),
            ],
          ),
        ],
      ),
    );
  }

  int _balanceAtDateForWallet(TransactionService ts, DateTime date, String? walletId) {
    final w = walletId != null ? WalletService.instance.byId(walletId) : null;
    final initial = w?.initialBalance ?? 0;
    int income = 0, expense = 0;
    for (final t in ts.currentUserTransactions.where((t) =>
        !t.date.isAfter(date) && (walletId == null || t.walletId == walletId))) {
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    return initial + income - expense;
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Responsive.w(context, 8),
          height: Responsive.w(context, 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static double _niceStep(double range, int targetSteps) {
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
}

// =============================================================================
// Data classes
// =============================================================================

class _BarItem {
  const _BarItem({
    required this.label,
    required this.value,
    required this.fill,
    required this.border,
  });
  final String label;
  final double value;
  final Color fill;
  final Color border;
}

// =============================================================================
// Custom painters
// =============================================================================

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.segmentColors,
    this.holeRadiusRatio = 0.6,
  });

  final List<double> segments;
  final List<Color> segmentColors;
  final double holeRadiusRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = segments.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final sweepAngle = (segments[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segmentColors[i]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    canvas.drawCircle(
      center,
      radius * holeRadiusRatio,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.segmentColors != segmentColors;
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    this.maxValue = 100,
  });

  final List<_BarItem> bars;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 28.0;
    const topMargin = 8.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    const yLabelValues = [0.0, 50.0, 100.0];
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final label in yLabelValues) {
      final y = topMargin + chartHeight * (1 - label / (maxValue > 0 ? maxValue : 100));

      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width, y),
        gridPaint,
      );

      _drawText(
        canvas,
        label.toInt().toString(),
        Offset(leftMargin - 6, y),
        Colors.grey.shade600,
        10,
        anchorRight: true,
        anchorCenterY: true,
      );
    }

    final barCount = bars.length;
    if (barCount == 0) return;
    final totalBarAreaWidth = chartWidth;
    final barSpacing = totalBarAreaWidth / (barCount * 2 + 1);
    final barWidth = barSpacing;

    for (int i = 0; i < barCount; i++) {
      final bar = bars[i];
      final barHeight = chartHeight * (bar.value / (maxValue > 0 ? maxValue : 1));
      final x = leftMargin + barSpacing * (2 * i + 1) - barWidth / 2;
      final y = topMargin + chartHeight - barHeight;

      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );

      canvas.drawRRect(barRect, Paint()..color = bar.fill);

      canvas.drawRRect(
        barRect,
        Paint()
          ..color = bar.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      _drawText(
        canvas,
        bar.label,
        Offset(x + barWidth / 2, size.height - 2),
        Colors.grey.shade600,
        10,
        anchorCenterX: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize, {
    bool anchorRight = false,
    bool anchorCenterX = false,
    bool anchorCenterY = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    double dx = position.dx;
    double dy = position.dy;
    if (anchorRight) dx -= tp.width;
    if (anchorCenterX) dx -= tp.width / 2;
    if (anchorCenterY) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.bars != bars;
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.xLabels,
    required this.yLabels,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> points;
  final List<String> xLabels;
  final List<double> yLabels;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 28.0;
    const topMargin = 8.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (yLabels.isEmpty) return;
    final maxY = yLabels.last;
    final minY = yLabels.first;
    final yRange = maxY - minY;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final label in yLabels) {
      final y = topMargin + chartHeight * (1 - (label - minY) / (yRange > 0 ? yRange : 1));

      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width, y),
        gridPaint,
      );

      _drawText(
        canvas,
        _formatLabel(label),
        Offset(leftMargin - 6, y),
        Colors.grey.shade600,
        10,
        anchorRight: true,
        anchorCenterY: true,
      );
    }

    final dataPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = leftMargin + chartWidth * (i / ((points.length - 1).clamp(1, points.length - 1)));
      final y = topMargin + chartHeight * (1 - (points[i] - minY) / (yRange > 0 ? yRange : 1));
      dataPoints.add(Offset(x, y));
    }

    if (dataPoints.isEmpty) return;

    final fillPath = Path();
    fillPath.moveTo(dataPoints.first.dx, topMargin + chartHeight);
    for (final pt in dataPoints) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(dataPoints.last.dx, topMargin + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);

    final linePath = Path();
    linePath.moveTo(dataPoints.first.dx, dataPoints.first.dy);
    for (int i = 1; i < dataPoints.length; i++) {
      linePath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final pt in dataPoints) {
      canvas.drawCircle(pt, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        pt,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (int i = 0; i < xLabels.length; i++) {
      _drawText(
        canvas,
        xLabels[i],
        Offset(dataPoints[i].dx, size.height - 2),
        Colors.grey.shade600,
        10,
        anchorCenterX: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize, {
    bool anchorRight = false,
    bool anchorCenterX = false,
    bool anchorCenterY = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    double dx = position.dx;
    double dy = position.dy;
    if (anchorRight) dx -= tp.width;
    if (anchorCenterX) dx -= tp.width / 2;
    if (anchorCenterY) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  static String _formatLabel(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MultiLineChartPainter extends CustomPainter {
  _MultiLineChartPainter({
    required this.presentPoints,
    required this.oneYearAgoPoints,
    required this.twoYearsAgoPoints,
    required this.minY,
    required this.maxY,
  });

  final List<double> presentPoints;
  final List<double> oneYearAgoPoints;
  final List<double> twoYearsAgoPoints;
  final double minY;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 28.0;
    const topMargin = 8.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - topMargin - bottomMargin;
    final yRange = maxY - minY;

    // Y-axis grid
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Create ~5 evenly spaced Y labels
    final int ySteps = 5;
    for (int i = 0; i <= ySteps; i++) {
      final label = minY + (yRange * i / ySteps);
      final y = topMargin + chartHeight * (1 - (label - minY) / (yRange > 0 ? yRange : 1));

      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width, y),
        gridPaint,
      );
      _drawText(
        canvas,
        _formatLabel(label),
        Offset(leftMargin - 6, y),
        Colors.grey.shade600,
        10,
        anchorRight: true,
        anchorCenterY: true,
      );
    }

    // X labels
    const xLabels = ['May', 'Jun'];

    // Three lines
    final lines = <_LineData>[
      _LineData(
        points: oneYearAgoPoints,
        color: AppColors.chartBlueBorder,
        areaColor: AppColors.chartBlueBorder.withValues(alpha: 0.08),
      ),
      _LineData(
        points: twoYearsAgoPoints,
        color: AppColors.chartOrangeBorder,
        areaColor: AppColors.chartOrangeBorder.withValues(alpha: 0.08),
      ),
      _LineData(
        points: presentPoints,
        color: AppColors.primaryGreen,
        areaColor: AppColors.primaryGreen.withValues(alpha: 0.08),
      ),
    ];

    const dataPointCount = 8;

    for (final line in lines) {
      final dataPoints = <Offset>[];
      for (int i = 0; i < line.points.length; i++) {
        final x = leftMargin + chartWidth * (i / (dataPointCount - 1));
        final y = topMargin + chartHeight * (1 - (line.points[i] - minY) / (yRange > 0 ? yRange : 1));
        dataPoints.add(Offset(x, y));
      }

      if (dataPoints.isEmpty) continue;

      final fillPath = Path();
      fillPath.moveTo(dataPoints.first.dx, topMargin + chartHeight);
      for (final pt in dataPoints) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(dataPoints.last.dx, topMargin + chartHeight);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = line.areaColor);

      final linePath = Path();
      linePath.moveTo(dataPoints.first.dx, dataPoints.first.dy);
      for (int i = 1; i < dataPoints.length; i++) {
        linePath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = line.color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    _drawText(canvas, xLabels[0], Offset(leftMargin, size.height - 2), Colors.grey.shade600, 10, anchorCenterX: true);
    _drawText(canvas, xLabels[1], Offset(size.width - 2, size.height - 2), Colors.grey.shade600, 10, anchorRight: true);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize, {
    bool anchorRight = false,
    bool anchorCenterX = false,
    bool anchorCenterY = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    double dx = position.dx;
    double dy = position.dy;
    if (anchorRight) dx -= tp.width;
    if (anchorCenterX) dx -= tp.width / 2;
    if (anchorCenterY) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  static String _formatLabel(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) => false;
}

class _LineData {
  const _LineData({
    required this.points,
    required this.color,
    required this.areaColor,
  });
  final List<double> points;
  final Color color;
  final Color areaColor;
}
