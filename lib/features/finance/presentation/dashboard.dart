import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/transaction_provider.dart';
import '../services/transaction_service.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  var _selectedPeriodFilter = 0; // 0=ING, 1=BRD, 2=Cash

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);

    return Column(
      children: [
        // =====================================================================
        // 1. HEADER FIXED — không cuộn
        // =====================================================================
        _buildHeader(),

        // =====================================================================
        // 2. NỘI DUNG CUỘN — các card dashboard
        // =====================================================================
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: Responsive.h(context, 16)),
                _buildAccountBalanceCard(ts),
                SizedBox(height: Responsive.h(context, 14)),
                _buildEarningsSpentRow(ts),
                SizedBox(height: Responsive.h(context, 14)),
                _buildBarChart(),
                SizedBox(height: Responsive.h(context, 14)),
                _buildLineChart(),
                SizedBox(height: Responsive.h(context, 14)),
                _buildComparingPeriods(),
                SizedBox(height: Responsive.h(context, 40)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 1. Header Dashboard (cố định)
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
          // Back button
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
  // 2. Account Balance Card
  // --------------------------------------------------------------------------
  Widget _buildAccountBalanceCard(TransactionService ts) {
    const ingValue = 423.55;
    const brdValue = 577.45;
    const totalBalance = 60.28;

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
          // Left side: text
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
                  totalBalance.toString(),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.sp(context, 32),
                    color: AppColors.darkGray,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 14)),
                _accountRow('ING', '423,55', AppColors.ingTextBlue),
                SizedBox(height: Responsive.h(context, 8)),
                _accountRow('BRD', '577,45', AppColors.brdTextGreen),
                SizedBox(height: Responsive.h(context, 8)),
                Text(
                  'Cash: 0',
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 14),
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedGray,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          // Right side: donut chart
          SizedBox(
            width: Responsive.w(context, 110),
            height: Responsive.w(context, 110),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(Responsive.w(context, 110), Responsive.w(context, 110)),
                  painter: _DonutPainter(
                    segments: [ingValue, brdValue],
                    segmentColors: [
                      AppColors.ingBlue,
                      AppColors.brdTeal,
                    ],
                    holeRadiusRatio: 0.58,
                  ),
                ),
                Text(
                  (ingValue + brdValue).toStringAsFixed(0),
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
  // 3. Earnings / Spent row
  // --------------------------------------------------------------------------
  Widget _buildEarningsSpentRow(TransactionService ts) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      child: Row(
        children: [
          Expanded(child: _buildMiniCard(
            title: 'Earnings this month',
            amount: _formatCompact(ts.monthlyIncome),
            segments: [423.55, 577.45],
            segmentColors: [AppColors.ingBlue, AppColors.brdTeal],
            labels: const ['ING', 'BRD'],
            labelColors: [AppColors.ingBlue, AppColors.brdTeal],
          )),
          SizedBox(width: Responsive.w(context, 14)),
          Expanded(child: _buildMiniCard(
            title: 'Spent this month',
            amount: '-${_formatCompact(ts.monthlyExpense)}',
            segments: [45, 30, 25],
            segmentColors: [
              AppColors.ingBlue,
              AppColors.brdTeal,
              AppColors.accentTeal,
            ],
            labels: const ['Rent', 'Food', 'Other'],
            labelColors: [
              AppColors.ingBlue,
              AppColors.brdTeal,
              AppColors.accentTeal,
            ],
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
              size: Size(Responsive.w(context, 72), Responsive.w(context, 72)),
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
  // 4. Balance Bar Chart
  // --------------------------------------------------------------------------
  Widget _buildBarChart() {
    const bars = <_BarItem>[
      _BarItem(label: 'ING', value: 40, fill: Color(0xFFD4EAFE), border: Color(0xFF2A96FA)),
      _BarItem(label: 'BRD', value: 88, fill: Color(0xFFCCF1E5), border: Color(0xFF63DBB6)),
      _BarItem(label: 'Cash1', value: 60, fill: Color(0xFFFFE0D0), border: Color(0xFFFF897A)),
      _BarItem(label: 'Revolut', value: 35, fill: Color(0xFFD4EAFE), border: Color(0xFF2A96FA)),
      _BarItem(label: 'BT', value: 70, fill: Color(0xFFCCF1E5), border: Color(0xFF63DBB6)),
    ];

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
            child: CustomPaint(
              size: Size(double.infinity, Responsive.h(context, 180)),
              painter: _BarChartPainter(bars: bars, maxValue: 100),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. This Month Balance Line Chart
  // --------------------------------------------------------------------------
  Widget _buildLineChart() {
    const points = [10.0, 35.0, 55.0, 68.0];
    const xLabels = ['10 May', '20 May', '30 May', 'Today'];
    const yLabels = [0.0, 20.0, 40.0, 60.0, 80.0];

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
              size: Size(double.infinity, Responsive.h(context, 180)),
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
  // 6. Comparing Between Periods
  // --------------------------------------------------------------------------
  Widget _buildComparingPeriods() {
    const filterLabels = ['ING', 'BRD', 'Cash'];

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
          // Filter tabs
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
          // Chart
          SizedBox(
            height: Responsive.h(context, 180),
            child: CustomPaint(
              size: Size(double.infinity, Responsive.h(context, 180)),
              painter: _MultiLineChartPainter(),
            ),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          // Legend
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

    // Donut hole
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

    // Y-axis labels & grid lines
    const yLabelValues = [0.0, 50.0, 100.0];
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final label in yLabelValues) {
      final y = topMargin + chartHeight * (1 - label / maxValue);

      // Grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Label
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

    // Bars
    final barCount = bars.length;
    final totalBarAreaWidth = chartWidth;
    final barSpacing = totalBarAreaWidth / (barCount * 2 + 1);
    final barWidth = barSpacing;

    for (int i = 0; i < barCount; i++) {
      final bar = bars[i];
      final barHeight = chartHeight * (bar.value / maxValue);
      final x = leftMargin + barSpacing * (2 * i + 1) - barWidth / 2;
      final y = topMargin + chartHeight - barHeight;

      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );

      // Fill
      canvas.drawRRect(barRect, Paint()..color = bar.fill);

      // Border
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = bar.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // X-axis label
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

    final maxY = yLabels.last;
    final minY = yLabels.first;
    final yRange = maxY - minY;

    // Y-axis labels & grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final label in yLabels) {
      final y = topMargin + chartHeight * (1 - (label - minY) / yRange);

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

    // Compute data point positions
    final dataPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = leftMargin + chartWidth * (i / (points.length - 1));
      final y = topMargin + chartHeight * (1 - (points[i] - minY) / yRange);
      dataPoints.add(Offset(x, y));
    }

    if (dataPoints.isEmpty) return;

    // Area fill
    final fillPath = Path();
    fillPath.moveTo(dataPoints.first.dx, topMargin + chartHeight);
    for (final pt in dataPoints) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(dataPoints.last.dx, topMargin + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Line
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

    // Points
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

    // X-axis labels
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

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MultiLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 28.0;
    const topMargin = 8.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    // Y-axis grid
    const yLabels = [0.0, 20.0, 40.0, 60.0, 80.0];
    const maxY = 80.0;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final label in yLabels) {
      final y = topMargin + chartHeight * (1 - label / maxY);
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

    // X labels
    const xLabels = ['May', 'Jun'];

    // Three lines: One year ago, Two years ago, Present
    final lines = <_LineData>[
      _LineData(
        points: [10.0, 18.0, 25.0, 30.0, 35.0, 42.0, 48.0, 50.0],
        color: AppColors.chartBlueBorder,
        areaColor: AppColors.chartBlueBorder.withValues(alpha: 0.08),
      ),
      _LineData(
        points: [15.0, 22.0, 28.0, 32.0, 40.0, 45.0, 52.0, 55.0],
        color: AppColors.chartOrangeBorder,
        areaColor: AppColors.chartOrangeBorder.withValues(alpha: 0.08),
      ),
      _LineData(
        points: [20.0, 30.0, 38.0, 45.0, 55.0, 60.0, 65.0, 70.0],
        color: AppColors.primaryGreen,
        areaColor: AppColors.primaryGreen.withValues(alpha: 0.08),
      ),
    ];

    const dataPointCount = 8;

    for (final line in lines) {
      final dataPoints = <Offset>[];
      for (int i = 0; i < line.points.length; i++) {
        final x = leftMargin + chartWidth * (i / (dataPointCount - 1));
        final y = topMargin + chartHeight * (1 - line.points[i] / maxY);
        dataPoints.add(Offset(x, y));
      }

      if (dataPoints.isEmpty) continue;

      // Area fill
      final fillPath = Path();
      fillPath.moveTo(dataPoints.first.dx, topMargin + chartHeight);
      for (final pt in dataPoints) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(dataPoints.last.dx, topMargin + chartHeight);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = line.areaColor);

      // Line
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

    // X-axis labels
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
