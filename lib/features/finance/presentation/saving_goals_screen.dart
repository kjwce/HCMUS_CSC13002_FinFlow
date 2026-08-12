import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../models/goal_model.dart';
import '../models/transaction_category.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/goal_service.dart';
import 'goal_sheets.dart';
import 'widgets/goal_ui.dart';

const _pageMint = Color(0xFFE4F4ED);
const _appBarMint = Color(0xFFF3FAF7);
const _secondaryText = Color(0xFF3C4A44);
const _goalsDarkBackground = Color(0xFF081C18);
const _goalsDarkSurface = Color(0xFF16352E);
const _goalsDarkRaisedSurface = Color(0xFF112622);
const _goalsDarkBorder = Color(0xFF29483F);
const _goalsDarkText = Color(0xFFF4FBF8);
const _goalsDarkSecondaryText = Color(0xFFA9C1B9);
const _goalsDarkMutedText = Color(0xFF708D84);
const _goalsDarkAccent = Color(0xFF38D6AC);

class SavingGoalsScreen extends ConsumerStatefulWidget {
  const SavingGoalsScreen({super.key});

  @override
  ConsumerState<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends ConsumerState<SavingGoalsScreen> {
  var _filter = 'All';

  @override
  void initState() {
    super.initState();
    GoalService.instance.addListener(_refresh);
    Future.microtask(() => ref.read(goalServiceProvider).fetchGoals());
  }

  @override
  void dispose() {
    GoalService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = ref.watch(goalServiceProvider);
    final balance = ref.watch(transactionServiceProvider).totalBalance;
    final goals = service.goals
        .where((goal) {
          if (_filter == 'Automatic') {
            return goal.fundingMethod == GoalFundingMethod.automatic;
          }
          if (_filter == 'Manual') {
            return goal.fundingMethod == GoalFundingMethod.manual;
          }
          if (_filter == 'Completed') return goal.isCompleted;
          return goal.status != GoalStatus.archived;
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: isDark ? _goalsDarkBackground : _pageMint,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: isDark ? _goalsDarkBackground : _appBarMint,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? _goalsDarkText : goalPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? _goalsDarkBorder : const Color(0x14006C53),
          ),
        ),
        title: Text(
          AppStrings.choose('Savings Goals', 'Mục tiêu tiết kiệm'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? _goalsDarkText : goalPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppStrings.choose(
              'Goal withdrawal settings',
              'Cài đặt rút tiền mục tiêu',
            ),
            onPressed: () => GoalWithdrawalSettingsSheet.show(context),
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? _goalsDarkText : goalPrimary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: service.goals.isEmpty
            ? _EmptyGoals(onCreate: _createGoal)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: _BalanceHeader(
                      balance: balance,
                      allocated: service.totalAllocated,
                      available: service.availableForGoals(balance),
                      onAllocate: () => AllocateMoneySheet.show(
                        context,
                        allowGoalSelection: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children:
                          [
                                ('All', AppStrings.choose('All', 'Tất cả')),
                                (
                                  'Automatic',
                                  AppStrings.choose('Automatic', 'Tự động'),
                                ),
                                (
                                  'Manual',
                                  AppStrings.choose('Manual', 'Thủ công'),
                                ),
                                (
                                  'Completed',
                                  AppStrings.choose('Completed', 'Hoàn thành'),
                                ),
                              ]
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _GoalFilterChip(
                                    label: Text(filter.$2),
                                    selected: _filter == filter.$1,
                                    onTap: () =>
                                        setState(() => _filter = filter.$1),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: goals.isEmpty
                        ? const _NoFilteredGoals()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                            itemCount: goals.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, index) {
                              if (index == goals.length) {
                                return const _EndOfGoals();
                              }
                              return _GoalListCard(
                                goal: goals[index],
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.goalDetails,
                                  arguments: goals[index].id,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: service.goals.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: ColoredBox(
                color: isDark ? _goalsDarkBackground : _pageMint,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    style: goalFilledButtonStyle(),
                    onPressed: _createGoal,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(
                      AppStrings.choose('Create New Goal', 'Tạo mục tiêu mới'),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _createGoal() => Navigator.of(context).pushNamed(AppRoutes.createGoal);
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.balance,
    required this.allocated,
    required this.available,
    required this.onAllocate,
  });

  final int balance;
  final int allocated;
  final int available;
  final VoidCallback onAllocate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00765D), Color(0xFF005C49)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _goalsDarkBorder) : null,
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x1A006C53),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BalanceLabel(
                      AppStrings.choose('Total Balance', 'Tổng số dư'),
                    ),
                    const SizedBox(height: 4),
                    _InlineMoney(
                      amount: balance,
                      amountSize: 24,
                      currencySize: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 148,
                height: 48,
                child: FilledButton(
                  onPressed: onAllocate,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? goalPrimary : goalDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.choose('Allocate Money', 'Phân bổ tiền'),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0x33FFFFFF), height: 34),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BalanceLabel(
                      AppStrings.choose(
                        'Available for Goals',
                        'Có thể phân bổ',
                      ),
                    ),
                    const SizedBox(height: 4),
                    _InlineMoney(
                      amount: available,
                      amountSize: 17,
                      currencySize: 11,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _BalanceLabel(
                      AppStrings.choose(
                        'Allocated to Goals',
                        'Đã phân bổ cho mục tiêu',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    _InlineMoney(
                      amount: allocated,
                      amountSize: 17,
                      currencySize: 11,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceLabel extends StatelessWidget {
  const _BalanceLabel(this.text, {this.textAlign = TextAlign.left});

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: 1,
    textAlign: textAlign,
    style: const TextStyle(
      color: Color(0xBFFFFFFF),
      fontFamily: 'Hanken Grotesk',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .55,
    ),
  );
}

class _InlineMoney extends StatelessWidget {
  const _InlineMoney({
    required this.amount,
    required this.amountSize,
    required this.currencySize,
    this.alignment = Alignment.centerLeft,
  });

  final int amount;
  final double amountSize;
  final double currencySize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: formatVnd(amount),
              style: TextStyle(
                fontSize: amountSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: '  VND',
              style: TextStyle(
                fontSize: currencySize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Manrope',
          height: 1,
        ),
      ),
    ),
  );
}

class _GoalListCard extends StatelessWidget {
  const _GoalListCard({required this.goal, required this.onTap});

  final GoalModel goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = TransactionCategory.resolve(goal.category);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? _goalsDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _goalsDarkBorder : Colors.white),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x1A006C53),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x14006C53),
          highlightColor: const Color(0x0D006C53),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GoalIconTile(category: goal.category, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    height: 1.2,
                                    color: isDark ? _goalsDarkText : goalText,
                                  ),
                                ),
                              ),
                              if (goal.isProtected) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.lock_rounded,
                                  size: 22,
                                  color: isDark
                                      ? _goalsDarkSecondaryText
                                      : _secondaryText,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.categoryName(category.label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? _goalsDarkSecondaryText
                                  : category.color.withValues(alpha: .72),
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${(goal.progress * 100).round()}%',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _goalsDarkAccent : goalPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.choose('achieved', 'đã đạt'),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? _goalsDarkSecondaryText
                            : _secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GoalProgressBar(value: goal.progress),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatVnd(goal.allocatedAmount),
                        style: TextStyle(
                          color: isDark ? _goalsDarkAccent : goalPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${formatVnd(goal.targetAmount)}',
                        style: TextStyle(
                          color: isDark
                              ? _goalsDarkSecondaryText
                              : _secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: '  VND',
                        style: TextStyle(
                          color: isDark
                              ? _goalsDarkSecondaryText
                              : _secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Manrope', fontSize: 14),
                ),
                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  color: isDark ? _goalsDarkBorder : const Color(0xFFE7ECE9),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 58,
                      child: _GoalMeta(
                        icon: goal.fundingMethod == GoalFundingMethod.automatic
                            ? Icons.sync_rounded
                            : Icons.touch_app_outlined,
                        iconColor: isDark
                            ? _goalsDarkSecondaryText
                            : (goal.fundingMethod == GoalFundingMethod.automatic
                                  ? goalPrimary
                                  : _secondaryText),
                        text: goal.fundingMethod == GoalFundingMethod.automatic
                            ? AppStrings.choose(
                                'Automatic · ${goal.autoAllocationPercent.round()}% of income',
                                'Tự động · ${goal.autoAllocationPercent.round()}% thu nhập',
                              )
                            : AppStrings.choose(
                                'Manual allocation',
                                'Phân bổ thủ công',
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 42,
                      child: _GoalMeta(
                        icon: Icons.event_outlined,
                        iconColor: _secondaryText,
                        text: formatGoalDate(goal.targetDate),
                        alignment: MainAxisAlignment.end,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: goal.isPrimary ? 14 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          goal.isPrimary
              ? _AnimatedPrimaryGoalBorder(borderRadius: 16, child: card)
              : card,
          if (goal.isPrimary)
            const Positioned(top: -14, right: 20, child: _PrimaryGoalBadge()),
        ],
      ),
    );
  }
}

class _GoalMeta extends StatelessWidget {
  const _GoalMeta({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.alignment = MainAxisAlignment.start,
    this.textAlign = TextAlign.left,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final MainAxisAlignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? _goalsDarkSecondaryText : iconColor,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? _goalsDarkSecondaryText : _secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryGoalBadge extends StatelessWidget {
  const _PrimaryGoalBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF9C74F),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xFFD99A00)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFF4A3500)),
        const SizedBox(width: 3),
        Text(
          AppStrings.choose('Primary', 'Ưu tiên'),
          style: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A3500),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => RepaintBoundary(
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
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
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
  bool shouldRepaint(covariant _RunningGoldBorderPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      borderRadius != oldDelegate.borderRadius ||
      showTracer != oldDelegate.showTracer;
}

class _GoalFilterChip extends StatelessWidget {
  const _GoalFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? goalPrimary
          : (isDark ? _goalsDarkSurface : Colors.white),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? goalPrimary
              : (isDark ? _goalsDarkBorder : const Color(0x33006C53)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: selected
            ? const Color(0x24FFFFFF)
            : (isDark ? _goalsDarkRaisedSurface : const Color(0x14006C53)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? _goalsDarkSecondaryText : _secondaryText),
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoFilteredGoals extends StatelessWidget {
  const _NoFilteredGoals();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        AppStrings.choose(
          'No goals match this filter.',
          'Không có mục tiêu nào phù hợp với bộ lọc.',
        ),
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? _goalsDarkSecondaryText : _secondaryText,
        ),
      ),
    );
  }
}

class _EndOfGoals extends StatelessWidget {
  const _EndOfGoals();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            child: Divider(
              thickness: 4,
              color: isDark ? _goalsDarkBorder : const Color(0x4D006C53),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.choose(
              'End of Active Goals',
              'Đã hiển thị hết mục tiêu đang hoạt động',
            ),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? _goalsDarkMutedText : _secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF07513F), goalPrimary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.choose(
                        'Total Savings Balance',
                        'Tổng số dư tiết kiệm',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      '0 VND',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Manrope',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppStrings.choose('Allocated', 'Đã phân bổ'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      '0 VND',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: goalMint,
                ),
              ],
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: isDark ? _goalsDarkSurface : Colors.white,
                  shape: BoxShape.circle,
                  border: isDark ? Border.all(color: _goalsDarkBorder) : null,
                ),
                child: Icon(
                  Icons.savings_outlined,
                  size: 82,
                  color: isDark ? _goalsDarkAccent : goalPrimary,
                ),
              ),
              Positioned(
                right: -4,
                top: 0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF86C232),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            AppStrings.choose(
              'You don’t have any savings\ngoals yet',
              'Bạn chưa có mục tiêu\ntiết kiệm nào',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? _goalsDarkText : goalText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.choose(
              'Start planning for your future by setting\nyour first financial milestone.',
              'Hãy lập kế hoạch tương lai bằng cách đặt\ncột mốc tài chính đầu tiên.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? _goalsDarkSecondaryText : goalMuted,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: goalFilledButtonStyle(),
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              AppStrings.choose(
                'Create Your First Goal',
                'Tạo mục tiêu đầu tiên',
              ),
            ),
          ),
          const Spacer(),
          Text(
            AppStrings.choose(
              '💡 Goals help you track progress effortlessly.',
              '💡 Mục tiêu giúp bạn dễ dàng theo dõi tiến độ.',
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? _goalsDarkMutedText : goalMuted,
            ),
          ),
        ],
      ),
    );
  }
}
