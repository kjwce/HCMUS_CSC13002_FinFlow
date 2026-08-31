import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../finance/models/recurring_model.dart';
import '../../finance/services/recurring_reminder_service.dart';
import '../../finance/services/recurring_service.dart';
import '../services/notification_preferences_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const _masterKey = 'finflow_push_notifications';
  static const _inAppBannersKey = 'finflow_in_app_notification_banners';
  static const _dailyBudgetKey = 'finflow_notify_daily_budget';
  static const _dailyThresholdKey = 'finflow_notify_daily_threshold';
  static const _weeklyBudgetKey = 'finflow_notify_weekly_budget';
  static const _weeklyThresholdKey = 'finflow_notify_weekly_threshold';
  static const _monthlyBudgetKey = 'finflow_notify_monthly_budget';
  static const _monthlyThresholdKey = 'finflow_notify_monthly_threshold';
  static const _savingGoalUpdatesKey = 'finflow_notify_saving_goal_updates';
  static const _recurringExpensesKey = 'finflow_notify_recurring_expenses';
  static const _recurringIncomeKey = 'finflow_notify_recurring_income';
  static const _recurringTimingKey = 'finflow_notify_recurring_timing_days';
  static const _recurringFailureKey = 'finflow_notify_recurring_failures';
  static const _communityLikesKey = 'finflow_notify_community_likes';
  static const _communityRepliesKey = 'finflow_notify_community_replies';
  static const _communityHighlightsKey = 'finflow_notify_community_highlights';

  static const _emerald = Color(0xFF00785D);
  static const _mint = Color(0xFFE8F7F1);
  static const _blue = Color(0xFF397BD8);
  static const _lime = Color(0xFF7CA62A);
  static const _coral = Color(0xFFE86B5D);
  static const _violet = Color(0xFF7B61D1);

  final _preferences = SharedPreferencesAsync();
  var _loaded = false;
  var _savingMaster = false;

  var _master = true;
  var _inAppBanners = true;
  var _dailyBudget = true;
  var _dailyThreshold = 90;
  var _weeklyBudget = true;
  var _weeklyThreshold = 80;
  var _monthlyBudget = true;
  var _monthlyThreshold = 85;
  var _savingGoalUpdates = true;
  var _recurringExpenses = true;
  var _recurringIncome = true;
  var _recurringTimingDays = 1;
  var _recurringFailures = true;
  var _communityLikes = true;
  var _communityReplies = true;
  var _communityHighlights = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final recurringTiming = await _preferences.getInt(_recurringTimingKey);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await NotificationPreferencesService.instance.startForUser(userId);
      }
      final cloud = NotificationPreferencesService.instance.value;
      if (!mounted) return;
      setState(() {
        _master = cloud.masterEnabled;
        _inAppBanners = cloud.inAppBannerEnabled;
        _dailyBudget = cloud.dailyBudgetEnabled;
        _dailyThreshold = cloud.dailyBudgetThreshold;
        _weeklyBudget = cloud.weeklyBudgetEnabled;
        _weeklyThreshold = cloud.weeklyBudgetThreshold;
        _monthlyBudget = cloud.monthlyBudgetEnabled;
        _monthlyThreshold = cloud.monthlyBudgetThreshold;
        _savingGoalUpdates = cloud.savingGoalUpdatesEnabled;
        _recurringExpenses = cloud.recurringExpenseEnabled;
        _recurringIncome = cloud.recurringIncomeEnabled;
        _recurringTimingDays = recurringTiming ?? 1;
        _recurringFailures = cloud.recurringFailureEnabled;
        _communityLikes = cloud.communityLikesEnabled;
        _communityReplies = cloud.communityRepliesEnabled;
        _communityHighlights = cloud.communityPostsEnabled;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Iterable<RecurringSchedule> get _enabledRecurringSchedules =>
      RecurringService.instance.schedules.where((schedule) {
        if (schedule.amount < 0) return _recurringExpenses;
        return _recurringIncome;
      });

  Future<void> _setMaster(bool enabled) async {
    if (_savingMaster) return;
    setState(() => _savingMaster = true);
    final accepted = await RecurringReminderService.instance.setEnabled(
      enabled,
      schedules: _enabledRecurringSchedules,
    );
    if (!mounted) return;
    final actualValue = enabled ? accepted : false;
    setState(() {
      _master = actualValue;
      _savingMaster = false;
    });
    await _preferences.setBool(_masterKey, actualValue);
    await _saveCloud();
    if (enabled && !accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Notification permission was denied. Enable it in system settings.',
              'Quyền thông báo đã bị từ chối. Hãy bật trong cài đặt hệ thống.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _setBool(
    String key,
    bool value,
    ValueSetter<bool> update, {
    bool resyncRecurring = false,
  }) async {
    setState(() => update(value));
    await _preferences.setBool(key, value);
    await _saveCloud();
    if (resyncRecurring && _master) {
      await RecurringReminderService.instance.syncAll(
        _enabledRecurringSchedules,
      );
    }
  }

  Future<void> _chooseThreshold({
    required int current,
    required ValueSetter<int> update,
    required String key,
  }) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.choose('Alert threshold', 'Ngưỡng cảnh báo'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in const [70, 80, 85, 90, 100])
                    ChoiceChip(
                      label: Text('$value%'),
                      selected: value == current,
                      onSelected: (_) => Navigator.pop(context, value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => update(selected));
    await _preferences.setInt(key, selected);
    await _saveCloud();
  }

  Future<void> _saveCloud() {
    final current = NotificationPreferencesService.instance.value;
    return NotificationPreferencesService.instance.update(
      current.copyWith(
        masterEnabled: _master,
        inAppBannerEnabled: _inAppBanners,
        dailyBudgetEnabled: _dailyBudget,
        dailyBudgetThreshold: _dailyThreshold,
        weeklyBudgetEnabled: _weeklyBudget,
        weeklyBudgetThreshold: _weeklyThreshold,
        monthlyBudgetEnabled: _monthlyBudget,
        monthlyBudgetThreshold: _monthlyThreshold,
        savingGoalUpdatesEnabled: _savingGoalUpdates,
        recurringExpenseEnabled: _recurringExpenses,
        recurringIncomeEnabled: _recurringIncome,
        recurringFailureEnabled: _recurringFailures,
        communityLikesEnabled: _communityLikes,
        communityRepliesEnabled: _communityReplies,
        communityPostsEnabled: _communityHighlights,
      ),
    );
  }

  Future<void> _chooseReminderTiming() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _ReminderTimingDialog(
        selectedDays: _recurringTimingDays,
        labelFor: _reminderTimingLabel,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _recurringTimingDays = selected);
    await _preferences.setInt(_recurringTimingKey, selected);
  }

  String _reminderTimingLabel(int days) {
    if (days == 0) {
      return AppStrings.choose('On the due date', 'Vào ngày đến hạn');
    }
    return AppStrings.choose(
      '$days day${days == 1 ? '' : 's'} before',
      'Trước $days ngày',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.primaryText,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          AppStrings.choose('Notification Preferences', 'Tùy chọn thông báo'),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                Responsive.w(context, 16),
                Responsive.h(context, 6),
                Responsive.w(context, 16),
                Responsive.h(context, 28),
              ),
              children: [
                _buildMasterCard(),
                SizedBox(height: Responsive.h(context, 12)),
                _PreferenceCard(
                  enabled: _master,
                  children: [
                    _PreferenceRow(
                      key: const Key('in-app-notification-banners-row'),
                      icon: Icons.view_agenda_outlined,
                      iconColor: _emerald,
                      iconBackground: _mint,
                      title: AppStrings.choose(
                        'In-app notification banners',
                        'Thông báo nổi trong app',
                      ),
                      subtitle: AppStrings.choose(
                        'Show a floating banner while you use FinFlow',
                        'Hiện banner nổi khi bạn đang sử dụng FinFlow',
                      ),
                      value: _inAppBanners,
                      onChanged: (value) => _setBool(
                        _inAppBannersKey,
                        value,
                        (next) => _inAppBanners = next,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 22)),
                _SectionTitle(
                  AppStrings.choose(
                    'SPENDING & BUDGETS',
                    'CHI TIÊU & NGÂN SÁCH',
                  ),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                _PreferenceCard(
                  enabled: _master,
                  children: [
                    _PreferenceRow(
                      icon: Icons.today_outlined,
                      iconColor: _blue,
                      iconBackground: const Color(0xFFEAF2FD),
                      title: AppStrings.choose(
                        "Approaching today's limit",
                        'Sắp chạm hạn mức hôm nay',
                      ),
                      subtitle: AppStrings.choose(
                        'Get an alert before daily spending reaches the limit',
                        'Nhận cảnh báo trước khi chi tiêu ngày chạm hạn mức',
                      ),
                      value: _dailyBudget,
                      onChanged: (value) => _setBool(
                        _dailyBudgetKey,
                        value,
                        (next) => _dailyBudget = next,
                      ),
                      badge: '$_dailyThreshold%',
                      onBadgeTap: () => _chooseThreshold(
                        current: _dailyThreshold,
                        update: (value) => _dailyThreshold = value,
                        key: _dailyThresholdKey,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.date_range_outlined,
                      iconColor: _lime,
                      iconBackground: const Color(0xFFF0F6E4),
                      title: AppStrings.choose(
                        "This week's spending limit",
                        'Hạn mức chi tiêu tuần này',
                      ),
                      subtitle: AppStrings.choose(
                        'Track progress against your weekly budget',
                        'Theo dõi tiến độ so với ngân sách tuần',
                      ),
                      value: _weeklyBudget,
                      onChanged: (value) => _setBool(
                        _weeklyBudgetKey,
                        value,
                        (next) => _weeklyBudget = next,
                      ),
                      badge: '$_weeklyThreshold%',
                      onBadgeTap: () => _chooseThreshold(
                        current: _weeklyThreshold,
                        update: (value) => _weeklyThreshold = value,
                        key: _weeklyThresholdKey,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFF28A88A),
                      iconBackground: const Color(0xFFE7F6F1),
                      title: AppStrings.choose(
                        'Monthly budget alerts',
                        'Cảnh báo ngân sách tháng',
                      ),
                      subtitle: AppStrings.choose(
                        'Stay within your monthly budget',
                        'Giữ chi tiêu trong ngân sách tháng',
                      ),
                      value: _monthlyBudget,
                      onChanged: (value) => _setBool(
                        _monthlyBudgetKey,
                        value,
                        (next) => _monthlyBudget = next,
                      ),
                      badge: '$_monthlyThreshold%',
                      onBadgeTap: () => _chooseThreshold(
                        current: _monthlyThreshold,
                        update: (value) => _monthlyThreshold = value,
                        key: _monthlyThresholdKey,
                      ),
                    ),
                    _PreferenceRow(
                      key: const Key('saving-goal-notifications-row'),
                      icon: Icons.track_changes_rounded,
                      iconColor: _violet,
                      iconBackground: const Color(0xFFF0ECFC),
                      title: AppStrings.choose(
                        'Saving goal updates',
                        'Cập nhật mục tiêu tiết kiệm',
                      ),
                      subtitle: AppStrings.choose(
                        'Milestones, deadlines and automatic allocations',
                        'Cột mốc, hạn chót và phân bổ tự động',
                      ),
                      value: _savingGoalUpdates,
                      onChanged: (value) => _setBool(
                        _savingGoalUpdatesKey,
                        value,
                        (next) => _savingGoalUpdates = next,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 22)),
                _SectionTitle(
                  AppStrings.choose('RECURRING REMINDERS', 'NHẮC NHỞ ĐỊNH KỲ'),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                _PreferenceCard(
                  enabled: _master,
                  children: [
                    _PreferenceRow(
                      icon: Icons.receipt_long_outlined,
                      iconColor: _coral,
                      iconBackground: const Color(0xFFFDEBE8),
                      title: AppStrings.choose(
                        'Bills, rent and subscriptions',
                        'Hóa đơn, tiền thuê và đăng ký',
                      ),
                      subtitle: AppStrings.choose(
                        'Remind me about recurring expenses',
                        'Nhắc tôi về các khoản chi định kỳ',
                      ),
                      value: _recurringExpenses,
                      onChanged: (value) => _setBool(
                        _recurringExpensesKey,
                        value,
                        (next) => _recurringExpenses = next,
                        resyncRecurring: true,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.payments_outlined,
                      iconColor: _emerald,
                      iconBackground: _mint,
                      title: AppStrings.choose(
                        'Salary and regular income',
                        'Lương và thu nhập định kỳ',
                      ),
                      subtitle: AppStrings.choose(
                        'Notify me when income is expected',
                        'Thông báo khi sắp nhận thu nhập',
                      ),
                      value: _recurringIncome,
                      onChanged: (value) => _setBool(
                        _recurringIncomeKey,
                        value,
                        (next) => _recurringIncome = next,
                        resyncRecurring: true,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.schedule_outlined,
                      iconColor: _violet,
                      iconBackground: const Color(0xFFF0ECFC),
                      title: AppStrings.choose(
                        'Reminder timing',
                        'Thời điểm nhắc nhở',
                      ),
                      subtitle: _reminderTimingLabel(_recurringTimingDays),
                      onTap: _chooseReminderTiming,
                      actionLabel: AppStrings.choose('Change', 'Đổi'),
                      onActionTap: _chooseReminderTiming,
                    ),
                    _PreferenceRow(
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFC18400),
                      iconBackground: const Color(0xFFFFF4D8),
                      title: AppStrings.choose(
                        'Failed or skipped transactions',
                        'Giao dịch lỗi hoặc bị bỏ qua',
                      ),
                      subtitle: AppStrings.choose(
                        'Notify me when a recurring transaction needs attention',
                        'Thông báo khi giao dịch định kỳ cần xử lý',
                      ),
                      value: _recurringFailures,
                      onChanged: (value) => _setBool(
                        _recurringFailureKey,
                        value,
                        (next) => _recurringFailures = next,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 22)),
                _SectionTitle(
                  AppStrings.choose(
                    'COMMUNITY ACTIVITY',
                    'HOẠT ĐỘNG CỘNG ĐỒNG',
                  ),
                ),
                SizedBox(height: Responsive.h(context, 8)),
                _PreferenceCard(
                  enabled: _master,
                  children: [
                    _PreferenceRow(
                      icon: Icons.favorite_border_rounded,
                      iconColor: const Color(0xFFE45F7A),
                      iconBackground: const Color(0xFFFCEAF0),
                      title: AppStrings.choose(
                        'Likes on my content',
                        'Lượt thích nội dung của tôi',
                      ),
                      subtitle: AppStrings.choose(
                        'When someone likes my post or comment',
                        'Khi ai đó thích bài viết hoặc bình luận của tôi',
                      ),
                      value: _communityLikes,
                      onChanged: (value) => _setBool(
                        _communityLikesKey,
                        value,
                        (next) => _communityLikes = next,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: _blue,
                      iconBackground: const Color(0xFFEAF2FD),
                      title: AppStrings.choose(
                        'Comments and replies',
                        'Bình luận và phản hồi',
                      ),
                      subtitle: AppStrings.choose(
                        'New comments and replies to my content',
                        'Bình luận và phản hồi mới cho nội dung của tôi',
                      ),
                      value: _communityReplies,
                      onChanged: (value) => _setBool(
                        _communityRepliesKey,
                        value,
                        (next) => _communityReplies = next,
                      ),
                    ),
                    _PreferenceRow(
                      icon: Icons.auto_awesome_outlined,
                      iconColor: _violet,
                      iconBackground: const Color(0xFFF0ECFC),
                      title: AppStrings.choose(
                        'Community highlights',
                        'Điểm nổi bật cộng đồng',
                      ),
                      subtitle: AppStrings.choose(
                        'Occasional highlights from the FinFlow community',
                        'Nội dung nổi bật định kỳ từ cộng đồng FinFlow',
                      ),
                      value: _communityHighlights,
                      onChanged: (value) => _setBool(
                        _communityHighlightsKey,
                        value,
                        (next) => _communityHighlights = next,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildMasterCard() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 16),
        vertical: Responsive.h(context, 14),
      ),
      decoration: BoxDecoration(
        color: _emerald,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2900513E),
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
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
            ),
          ),
          SizedBox(width: Responsive.w(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choose('Notifications', 'Thông báo'),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 17),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  AppStrings.choose(
                    'Stay informed about your money',
                    'Luôn nắm rõ tình hình tài chính',
                  ),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 13),
                    color: Colors.white.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
          if (_savingMaster)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          else
            Switch.adaptive(
              key: const Key('master-notifications-switch'),
              value: _master,
              onChanged: _setMaster,
              activeTrackColor: Colors.white,
              activeThumbColor: _emerald,
              inactiveTrackColor: Colors.white.withValues(alpha: .25),
            ),
        ],
      ),
    );
  }
}

class _ReminderTimingDialog extends StatelessWidget {
  const _ReminderTimingDialog({
    required this.selectedDays,
    required this.labelFor,
  });

  final int selectedDays;
  final String Function(int days) labelFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      key: const Key('reminder-timing-dialog'),
      insetPadding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 24)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Container(
          padding: EdgeInsets.all(Responsive.w(context, 20)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2B002D22),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: Responsive.w(context, 44),
                    height: Responsive.w(context, 44),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.elevatedSurface
                          : const Color(0xFFF0ECFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: _NotificationPreferencesScreenState._violet,
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.choose(
                            'Reminder timing',
                            'Thời điểm nhắc nhở',
                          ),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: Responsive.sp(context, 20),
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 3)),
                        Text(
                          AppStrings.choose(
                            'Choose when FinFlow should remind you',
                            'Chọn thời điểm FinFlow sẽ nhắc bạn',
                          ),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: Responsive.sp(context, 13),
                            height: 1.3,
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close-reminder-timing-dialog'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.elevatedSurface,
                      foregroundColor: colors.secondaryText,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(context, 18)),
              for (final days in const [0, 1, 2, 3, 7]) ...[
                _ReminderTimingOption(
                  days: days,
                  label: labelFor(days),
                  selected: selectedDays == days,
                ),
                if (days != 7) SizedBox(height: Responsive.h(context, 8)),
              ],
              SizedBox(height: Responsive.h(context, 14)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 12),
                  vertical: Responsive.h(context, 10),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.elevatedSurface
                      : _NotificationPreferencesScreenState._mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: _NotificationPreferencesScreenState._emerald,
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Expanded(
                      child: Text(
                        AppStrings.choose(
                          'Applies to all recurring reminders',
                          'Áp dụng cho tất cả lời nhắc định kỳ',
                        ),
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 12.5),
                          fontWeight: FontWeight.w500,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTimingOption extends StatelessWidget {
  const _ReminderTimingOption({
    required this.days,
    required this.label,
    required this.selected,
  });

  final int days;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('reminder-timing-option-$days'),
        onTap: () => Navigator.pop(context, days),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(minHeight: Responsive.h(context, 52)),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 14),
            vertical: Responsive.h(context, 12),
          ),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? colors.elevatedSurface
                      : _NotificationPreferencesScreenState._mint)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _NotificationPreferencesScreenState._emerald
                  : colors.divider,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? _NotificationPreferencesScreenState._emerald
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? _NotificationPreferencesScreenState._emerald
                        : colors.secondaryText,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 15),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: colors.primaryText,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: Responsive.w(context, 4)),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Hanken Grotesk',
        fontSize: Responsive.sp(context, 12),
        fontWeight: FontWeight.w700,
        letterSpacing: .45,
        color: context.finFlowColors.secondaryText,
      ),
    ),
  );
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.children, required this.enabled});

  final List<Widget> children;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : .48,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 15)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F00513E),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  Divider(height: 1, color: colors.divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.value,
    this.onChanged,
    this.badge,
    this.onBadgeTap,
    this.actionLabel,
    this.onActionTap,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final String? badge;
  final VoidCallback? onBadgeTap;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: Responsive.w(context, 40),
              height: Responsive.w(context, 40),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? colors.elevatedSurface
                    : iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: Responsive.w(context, 20),
                color: iconColor,
              ),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 15),
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12.5),
                      height: 1.3,
                      color: colors.secondaryText,
                    ),
                  ),
                  if (badge != null) ...[
                    SizedBox(height: Responsive.h(context, 6)),
                    InkWell(
                      onTap: onBadgeTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(context, 8),
                          vertical: Responsive.h(context, 3),
                        ),
                        decoration: BoxDecoration(
                          color: _NotificationPreferencesScreenState._mint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppStrings.choose(
                            '$badge threshold',
                            'Ngưỡng $badge',
                          ),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: Responsive.sp(context, 11),
                            fontWeight: FontWeight.w600,
                            color: _NotificationPreferencesScreenState._emerald,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            if (actionLabel != null)
              TextButton.icon(
                onPressed: onActionTap,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                label: Text(actionLabel!),
                style: TextButton.styleFrom(
                  foregroundColor: colors.secondaryText,
                  textStyle: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              )
            else if (value != null)
              Transform.scale(
                scale: .82,
                child: Switch.adaptive(
                  value: value!,
                  onChanged: onChanged,
                  activeTrackColor:
                      _NotificationPreferencesScreenState._emerald,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
