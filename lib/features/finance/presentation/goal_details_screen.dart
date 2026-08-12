import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../services/goal_service.dart';
import 'goal_sheets.dart';
import 'widgets/goal_ui.dart';

const _detailsDarkBackground = Color(0xFF081C18);
const _detailsDarkSurface = Color(0xFF16352E);
const _detailsDarkRaisedSurface = Color(0xFF112622);
const _detailsDarkBorder = Color(0xFF29483F);
const _detailsDarkText = Color(0xFFF4FBF8);
const _detailsDarkSecondaryText = Color(0xFFA9C1B9);
const _detailsDarkAccent = Color(0xFF38D6AC);
const _detailsDarkDanger = Color(0xFFFF6B70);
const _detailsDarkDangerSurface = Color(0xFF301314);

class GoalDetailsScreen extends ConsumerStatefulWidget {
  const GoalDetailsScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends ConsumerState<GoalDetailsScreen> {
  @override
  void initState() {
    super.initState();
    GoalService.instance.addListener(_refresh);
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
    final goal = service.byId(widget.goalId);
    if (goal == null) {
      return Scaffold(
        backgroundColor: isDark ? _detailsDarkBackground : null,
        body: Center(
          child: Text(
            AppStrings.choose('Goal not found', 'Không tìm thấy mục tiêu'),
            style: TextStyle(color: isDark ? _detailsDarkText : null),
          ),
        ),
      );
    }
    final entries = service.entriesFor(goal.id);

    return Scaffold(
      backgroundColor: isDark
          ? _detailsDarkBackground
          : const Color(0xFFE4F4ED),
      appBar: AppBar(
        backgroundColor: isDark
            ? _detailsDarkBackground
            : const Color(0xFFF3FAF7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? _detailsDarkBorder : const Color(0x1A006C53),
          ),
        ),
        foregroundColor: isDark ? _detailsDarkText : goalPrimary,
        title: Text(
          AppStrings.choose('Goal Details', 'Chi tiết mục tiêu'),
          style: TextStyle(
            fontFamily: 'Manrope',
            color: isDark ? _detailsDarkText : goalText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppStrings.choose('Edit goal', 'Sửa mục tiêu'),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.editGoal, arguments: goal.id),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'primary') service.activateGoal(goal.id);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'primary',
                child: Text(
                  AppStrings.choose('Set as primary', 'Đặt làm ưu tiên'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          _GoalOverview(goal: goal),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: goalFilledButtonStyle(),
                  onPressed: goal.isCompleted
                      ? null
                      : () =>
                            AllocateMoneySheet.show(context, initialGoal: goal),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(AppStrings.choose('Add Money', 'Thêm tiền')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: isDark ? _detailsDarkAccent : goalPrimary,
                    side: BorderSide(
                      color: isDark ? _detailsDarkAccent : goalPrimary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: goal.allocatedAmount == 0
                      ? null
                      : () => WithdrawMoneySheet.show(context, goal: goal),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: Text(AppStrings.choose('Withdraw', 'Rút tiền')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FundingSettings(goal: goal),
          const SizedBox(height: 8),
          _ActivityCard(entries: entries),
        ],
      ),
    );
  }
}

class _GoalOverview extends StatelessWidget {
  const _GoalOverview({required this.goal});
  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _detailsDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: _detailsDarkBorder) : null,
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x14006C53),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? _detailsDarkRaisedSurface
                  : const Color(0xFFE4F4ED),
              shape: BoxShape.circle,
              border: isDark ? Border.all(color: _detailsDarkBorder) : null,
            ),
            child: goalIconWidgetFor(
              goal.category,
              color: isDark ? _detailsDarkAccent : goalPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            goal.name,
            style: TextStyle(
              fontFamily: 'Manrope',
              color: isDark ? _detailsDarkText : goalText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            AppStrings.categoryName(goal.category),
            style: TextStyle(
              color: isDark ? _detailsDarkSecondaryText : goalMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              if (goal.isPrimary)
                _Badge(
                  label: AppStrings.choose('Primary Goal', 'Mục tiêu ưu tiên'),
                  icon: Icons.star_rounded,
                  color: isDark ? _detailsDarkAccent : goalPrimary,
                ),
              if (goal.isProtected)
                _Badge(
                  label: AppStrings.choose('Protected', 'Được bảo vệ'),
                  icon: Icons.lock_rounded,
                  color: isDark ? _detailsDarkSecondaryText : goalMuted,
                ),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: formatVnd(goal.allocatedAmount)),
                  TextSpan(
                    text: '  VND',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: isDark ? _detailsDarkAccent : goalPrimary,
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${(goal.progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: isDark ? _detailsDarkAccent : goalPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.choose('achieved', 'đã đạt'),
                style: TextStyle(
                  color: isDark ? _detailsDarkSecondaryText : goalMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GoalProgressBar(value: goal.progress),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: AppStrings.choose('of ', 'trên ')),
                TextSpan(
                  text: formatVnd(goal.targetAmount),
                  style: const TextStyle(fontFamily: 'Manrope'),
                ),
                const TextSpan(
                  text: ' VND',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 10),
                ),
                TextSpan(
                  text: AppStrings.choose(' total goal', ' tổng mục tiêu'),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? _detailsDarkSecondaryText : goalMuted,
              fontSize: 13,
            ),
          ),
          Divider(
            height: 34,
            color: isDark ? _detailsDarkBorder : goalSurfaceLow,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SmallMetric(
                label: AppStrings.choose('TARGET DATE', 'NGÀY MỤC TIÊU'),
                value: formatGoalDate(goal.targetDate),
              ),
              _SmallMetric(
                label: AppStrings.choose('MONTHLY EST.', 'ƯỚC TÍNH/THÁNG'),
                value: goal.targetDate == null
                    ? '—'
                    : '${formatVnd(_monthlyEstimate(goal))} VND',
                right: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _monthlyEstimate(GoalModel goal) {
    final date = goal.targetDate;
    if (date == null) return 0;
    final now = DateTime.now();
    final months = ((date.year - now.year) * 12 + date.month - now.month).clamp(
      1,
      1200,
    );
    return (goal.remainingAmount / months).ceil();
  }
}

class _FundingSettings extends StatelessWidget {
  const _FundingSettings({required this.goal});
  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _detailsDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: _detailsDarkBorder) : null,
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x14006C53),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.choose('Funding Settings', 'Cài đặt nguồn tiền'),
            style: TextStyle(
              fontFamily: 'Manrope',
              color: isDark ? _detailsDarkText : goalText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? _detailsDarkRaisedSurface
                  : const Color(0xFFF5FBF8),
              borderRadius: BorderRadius.circular(8),
              border: isDark ? Border.all(color: _detailsDarkBorder) : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sync_rounded,
                  color: isDark ? _detailsDarkAccent : const Color(0xFF007A5E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.fundingMethod == GoalFundingMethod.automatic
                        ? AppStrings.choose(
                            'Automatically receives ${goal.autoAllocationPercent.round()}% of each income',
                            'Tự động nhận ${goal.autoAllocationPercent.round()}% từ mỗi khoản thu nhập',
                          )
                        : AppStrings.choose(
                            'Money is added manually',
                            'Tiền được thêm thủ công',
                          ),
                    style: TextStyle(
                      color: isDark ? _detailsDarkSecondaryText : goalMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _SettingLine(
            label: AppStrings.choose('Withdrawal priority', 'Ưu tiên rút tiền'),
            value: switch (goal.withdrawalPriority) {
              1 => AppStrings.choose('High', 'Cao'),
              3 => AppStrings.choose('Low', 'Thấp'),
              _ => AppStrings.choose('Medium', 'Trung bình'),
            },
          ),
          _SettingLine(
            label: AppStrings.choose('Protected status', 'Trạng thái bảo vệ'),
            value: goal.isProtected
                ? AppStrings.choose('Active', 'Đang bật')
                : AppStrings.choose('Off', 'Tắt'),
          ),
          _SettingLine(
            label: AppStrings.choose(
              'Completion behavior',
              'Xử lý khi hoàn thành',
            ),
            value: goal.completionBehavior == GoalCompletionBehavior.redirect
                ? AppStrings.choose(
                    'Redirect to next goal',
                    'Chuyển sang mục tiêu tiếp theo',
                  )
                : AppStrings.choose('Keep available', 'Giữ ở số dư khả dụng'),
          ),
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? _detailsDarkBorder : goalSurfaceLow,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? _detailsDarkSecondaryText : goalMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Manrope',
                color:
                    label ==
                            AppStrings.choose(
                              'Protected status',
                              'Trạng thái bảo vệ',
                            ) &&
                        value == AppStrings.choose('Active', 'Đang bật')
                    ? (isDark ? _detailsDarkAccent : goalPrimary)
                    : (isDark ? _detailsDarkText : goalText),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entries});

  final List<GoalFundEntry> entries;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _detailsDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: _detailsDarkBorder) : null,
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x14006C53),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.choose('Activity', 'Hoạt động'),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: isDark ? _detailsDarkText : goalText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? _detailsDarkAccent : goalPrimary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppStrings.choose('View All', 'Xem tất cả'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                AppStrings.choose(
                  'No goal activity yet',
                  'Chưa có hoạt động mục tiêu',
                ),
                style: TextStyle(
                  color: isDark ? _detailsDarkSecondaryText : goalMuted,
                  fontSize: 14,
                ),
              ),
            )
          else
            ...entries
                .take(5)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _ActivityRow(entry: entry),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final GoalFundEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positive = entry.amount > 0;
    final icon = switch (entry.entryType) {
      'automatic_allocation' => Icons.sync_rounded,
      'manual_withdrawal' ||
      'expense_withdrawal' => Icons.arrow_downward_rounded,
      _ => Icons.arrow_upward_rounded,
    };
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? (positive
                      ? _detailsDarkRaisedSurface
                      : _detailsDarkDangerSurface)
                : (positive
                      ? const Color(0xFFE4F4ED)
                      : const Color(0xFFFFDAD6)),
            shape: BoxShape.circle,
            border: isDark ? Border.all(color: _detailsDarkBorder) : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: positive
                ? (isDark ? _detailsDarkAccent : goalPrimary)
                : (isDark ? _detailsDarkDanger : goalError),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _entryLabel(entry.entryType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? _detailsDarkText : goalText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatGoalDate(entry.createdAt),
                style: TextStyle(
                  color: isDark ? _detailsDarkSecondaryText : goalMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${positive ? '+' : '-'}${formatVnd(entry.amount.abs())}',
                  ),
                  const TextSpan(
                    text: ' VND',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: positive
                    ? (isDark ? _detailsDarkAccent : goalPrimary)
                    : (isDark ? _detailsDarkDanger : goalError),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _entryLabel(String type) => switch (type) {
    'automatic_allocation' => AppStrings.choose(
      'Automatic allocation from income',
      'Phân bổ tự động từ thu nhập',
    ),
    'manual_withdrawal' => AppStrings.choose(
      'Withdrawn to available balance',
      'Đã rút về số dư khả dụng',
    ),
    'expense_withdrawal' => AppStrings.choose(
      'Withdrawal for expense',
      'Rút tiền cho chi tiêu',
    ),
    'initial' => AppStrings.choose('Initial allocation', 'Phân bổ ban đầu'),
    _ => AppStrings.choose('Manual allocation', 'Phân bổ thủ công'),
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? .16 : .12),
        borderRadius: BorderRadius.circular(99),
        border: isDark ? Border.all(color: color.withValues(alpha: .28)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    this.right = false,
  });
  final String label;
  final String value;
  final bool right;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? _detailsDarkSecondaryText : goalMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: right ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: isDark ? _detailsDarkText : goalText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
