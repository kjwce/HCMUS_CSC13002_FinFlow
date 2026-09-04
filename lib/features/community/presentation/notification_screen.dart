import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/screens/community_post_detail_screen.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/finflow_action_icon.dart';
import '../../finance/models/transaction_category.dart';
import '../../finance/services/recurring_service.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/community_date_format.dart';
import 'widgets/community_comment_icon.dart';

const _darkBackground = Color(0xFF081C18);
const _darkSurface = Color(0xFF112622);
const _darkCard = Color(0xFF16352E);
const _darkBorder = Color(0xFF29483F);
const _darkText = Color(0xFFF4FBF8);
const _darkSecondary = Color(0xFFA9C1B9);
const _darkMuted = Color(0xFF78958B);
const _darkAccent = Color(0xFF38D6AC);
const _emerald = Color(0xFF007C61);
const _coral = Color(0xFFE86B5D);
const _amber = Color(0xFFE39A16);
const _violet = Color(0xFF7558CB);
const _blue = Color(0xFF3976B8);

enum _NotificationFilter {
  all,
  actionRequired,
  transaction,
  budget,
  goal,
  recurring,
  community,
  system,
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  var _filter = _NotificationFilter.all;
  var _loaded = false;
  var _summaryDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).fetchNotifications();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(notificationServiceProvider);
    final source = _filtered(service.notifications);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark
          ? _darkBackground
          : context.finFlowColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _header(service.unreadCount),
            _filters(service.notifications),
            Expanded(
              child: !_loaded && service.isLoading
                  ? _skeleton()
                  : RefreshIndicator(
                      color: _emerald,
                      onRefresh: service.fetchNotifications,
                      child: source.isEmpty
                          ? _emptyState()
                          : _feed(source, service),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(int unreadCount) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: Responsive.h(context, 62),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: dark ? _darkSurface : const Color(0xFFEAF8F3),
        border: Border(
          bottom: BorderSide(
            color: dark ? _darkBorder : const Color(0xFFD6E9E1),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: Responsive.w(context, 2)),
          Expanded(
            child: Text(
              AppStrings.choose('Notifications', 'Thông báo'),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 20),
                fontWeight: FontWeight.w700,
                color: dark ? _darkText : const Color(0xFF073B30),
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: AppStrings.choose('More options', 'Tùy chọn khác'),
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'read') {
                ref.read(notificationServiceProvider).markAllAsRead();
              } else if (value == 'settings') {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.notificationPreferences);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'read',
                child: Text(
                  AppStrings.choose(
                    'Mark all as read',
                    'Đánh dấu tất cả đã đọc',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(
                  AppStrings.choose(
                    'Notification settings',
                    'Cài đặt thông báo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(List<NotificationModel> notifications) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? _darkBackground : context.finFlowColors.pageBackground,
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
        child: Row(
          children: [
            for (final filter in _NotificationFilter.values) ...[
              _filterChip(filter, _filterCount(filter, notifications)),
              SizedBox(width: Responsive.w(context, 8)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(_NotificationFilter filter, int count) {
    final selected = _filter == filter;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('notification-filter-${filter.name}'),
        onTap: () => setState(() => _filter = filter),
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (dark ? _darkAccent : _emerald)
                : (dark ? _darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (dark ? _darkBorder : const Color(0xFFCFE1DA)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _filterLabel(filter),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 12.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? (dark ? const Color(0xFF06271F) : Colors.white)
                      : (dark ? _darkSecondary : const Color(0xFF40534C)),
                ),
              ),
              if (count > 0 && filter != _NotificationFilter.all) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .2)
                        : const Color(0xFFE3F4EE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (dark ? const Color(0xFF06271F) : Colors.white)
                          : _emerald,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _filterLabel(_NotificationFilter filter) => switch (filter) {
    _NotificationFilter.all => AppStrings.choose('All', 'Tất cả'),
    _NotificationFilter.actionRequired => AppStrings.choose(
      'Needs action',
      'Cần xử lý',
    ),
    _NotificationFilter.transaction => AppStrings.choose(
      'Transactions',
      'Giao dịch',
    ),
    _NotificationFilter.budget => AppStrings.choose('Budgets', 'Ngân sách'),
    _NotificationFilter.goal => AppStrings.choose('Goals', 'Mục tiêu'),
    _NotificationFilter.recurring => AppStrings.choose('Recurring', 'Định kỳ'),
    _NotificationFilter.community => AppStrings.choose(
      'Community',
      'Cộng đồng',
    ),
    _NotificationFilter.system => AppStrings.choose('System', 'Hệ thống'),
  };

  int _filterCount(
    _NotificationFilter filter,
    List<NotificationModel> notifications,
  ) {
    if (filter == _NotificationFilter.all) return notifications.length;
    if (filter == _NotificationFilter.actionRequired) {
      return notifications.where((item) => item.actionRequired).length;
    }
    final category = _categoryFor(filter);
    return notifications.where((item) => item.category == category).length;
  }

  List<NotificationModel> _filtered(List<NotificationModel> notifications) {
    if (_filter == _NotificationFilter.all) return notifications;
    if (_filter == _NotificationFilter.actionRequired) {
      return notifications
          .where((item) => item.actionRequired)
          .toList(growable: false);
    }
    final category = _categoryFor(_filter);
    return notifications
        .where((item) => item.category == category)
        .toList(growable: false);
  }

  NotificationCategory? _categoryFor(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.transaction => NotificationCategory.transaction,
      _NotificationFilter.budget => NotificationCategory.budget,
      _NotificationFilter.goal => NotificationCategory.goal,
      _NotificationFilter.recurring => NotificationCategory.recurring,
      _NotificationFilter.community => NotificationCategory.community,
      _NotificationFilter.system => NotificationCategory.system,
      _ => null,
    };
  }

  Widget _feed(List<NotificationModel> notifications, dynamic service) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayItems = notifications
        .where((item) => item.createdAt.isAfter(today))
        .toList();
    final yesterdayItems = notifications
        .where(
          (item) =>
              !item.createdAt.isBefore(yesterday) &&
              item.createdAt.isBefore(today),
        )
        .toList();
    final earlier = notifications
        .where((item) => item.createdAt.isBefore(yesterday))
        .toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        2,
        Responsive.w(context, 16),
        Responsive.h(context, 28),
      ),
      children: [
        if (_filter == _NotificationFilter.all &&
            !_summaryDismissed &&
            service.actionRequiredCount > 0)
          _smartSummary(service.actionRequiredCount),
        if (todayItems.isNotEmpty)
          _section(AppStrings.choose('Today', 'Hôm nay'), todayItems),
        if (yesterdayItems.isNotEmpty)
          _section(AppStrings.choose('Yesterday', 'Hôm qua'), yesterdayItems),
        if (earlier.isNotEmpty)
          _section(AppStrings.choose('Earlier', 'Trước đó'), earlier),
      ],
    );
  }

  Widget _smartSummary(int count) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(context, 18)),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? _darkBorder : const Color(0xFFBFDCD1),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x66000000) : const Color(0x3300523C),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (!dark)
            const BoxShadow(
              color: Color(0x14007C61),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _circleIcon(
            Icons.auto_graph_rounded,
            _emerald,
            dark ? const Color(0xFF1A443A) : const Color(0xFFCFF0E4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choose(
                    'You have $count notification${count == 1 ? '' : 's'} that need action',
                    'Bạn có $count thông báo cần xử lý',
                  ),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: dark ? _darkText : const Color(0xFF0C3329),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppStrings.choose(
                    'Review important recurring and budget updates.',
                    'Xem lại các cập nhật quan trọng về định kỳ và ngân sách.',
                  ),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: dark ? _darkSecondary : const Color(0xFF425E55),
                  ),
                ),
                const SizedBox(height: 9),
                TextButton(
                  onPressed: () => setState(
                    () => _filter = _NotificationFilter.actionRequired,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: dark ? _darkAccent : _emerald,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    AppStrings.choose('View now', 'Xem ngay'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _summaryDismissed = true),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<NotificationModel> items) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = items.where((item) => !item.isRead).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: dark ? _darkText : const Color(0xFF0C3329),
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE3DF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    AppStrings.choose('$unread new', '$unread mới'),
                    style: const TextStyle(
                      color: _coral,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(context, 17)),
            child: _NotificationCard(
              notification: item,
              onTap: () => _open(item),
              onPrimaryAction: () => _open(item),
              onSecondaryAction: item.actionRequired ? () => _skip(item) : null,
              onReadToggle: () => ref
                  .read(notificationServiceProvider)
                  .markAsRead(item.id, value: item.isRead ? false : true),
              onArchive: () => _archiveWithUndo(item),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _archiveWithUndo(NotificationModel notification) async {
    final service = ref.read(notificationServiceProvider);
    final archiveRequest = service.archive(notification);
    if (!mounted) return;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('notification-deleted-snackbar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark ? _darkCard : const Color(0xFFE7EBE9),
          elevation: 8,
          margin: EdgeInsets.fromLTRB(
            Responsive.w(context, 12),
            0,
            Responsive.w(context, 12),
            Responsive.h(context, 10),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Container(
                width: Responsive.w(context, 28),
                height: Responsive.w(context, 28),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E0),
                  shape: BoxShape.circle,
                ),
                child: FinFlowTrashIcon(
                  size: Responsive.w(context, 16),
                  color: const Color(0xFFBA1A1A),
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              Expanded(
                child: Text(
                  AppStrings.choose('Notification deleted', 'Đã xóa thông báo'),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 13.5),
                    fontWeight: FontWeight.w600,
                    color: dark ? _darkText : const Color(0xFF263B34),
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            key: const Key('notification-undo-delete-button'),
            label: AppStrings.choose('Undo', 'Hoàn tác'),
            textColor: dark ? _darkAccent : const Color(0xFF006C53),
            onPressed: () =>
                _restoreNotification(notification, after: archiveRequest),
          ),
        ),
      );

    try {
      await archiveRequest;
    } catch (error) {
      if (!mounted) return;
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.choose(
                'Unable to delete notification: $error',
                'Không thể xóa thông báo: $error',
              ),
            ),
          ),
        );
    }
  }

  Future<void> _restoreNotification(
    NotificationModel notification, {
    required Future<void> after,
  }) async {
    try {
      await after;
      await ref.read(notificationServiceProvider).restore(notification);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppStrings.choose(
              'Notification restored',
              'Đã khôi phục thông báo',
            ),
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
              'Unable to restore notification: $error',
              'Không thể khôi phục thông báo: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _open(NotificationModel notification) async {
    if (!notification.isRead) {
      await ref.read(notificationServiceProvider).markAsRead(notification.id);
    }
    if (!mounted) return;
    switch (notification.category) {
      case NotificationCategory.recurring:
        if (notification.scheduleId != null) {
          await Navigator.of(context).pushNamed(
            AppRoutes.recurringDetails,
            arguments: notification.scheduleId,
          );
        }
        break;
      case NotificationCategory.community:
        if (notification.postId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CommunityPostDetailScreen(postId: notification.postId!),
            ),
          );
        }
        break;
      case NotificationCategory.budget:
        await Navigator.of(context).pushNamed(AppRoutes.categoryBudgets);
        break;
      case NotificationCategory.goal:
        final goalId =
            notification.entityId ??
            notification.payload['goal_id']?.toString();
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.goalDetails, arguments: goalId);
        break;
      case NotificationCategory.transaction:
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.dashboard, arguments: 0);
        break;
      case NotificationCategory.system:
        break;
    }
  }

  Future<void> _skip(NotificationModel notification) async {
    if (notification.isRecurring && notification.scheduleId != null) {
      final schedule = RecurringService.instance.findById(
        notification.scheduleId!,
      );
      if (schedule != null) {
        await RecurringService.instance.skipOccurrence(schedule);
      }
    }
    await ref
        .read(notificationServiceProvider)
        .resolve(notification.id, status: 'dismissed');
  }

  Widget _emptyState() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = _filter == _NotificationFilter.all;
    final label = _filterLabel(_filter);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 26)),
      children: [
        SizedBox(height: Responsive.h(context, 70)),
        Center(
          child: Container(
            width: Responsive.w(context, 94),
            height: Responsive.w(context, 94),
            decoration: BoxDecoration(
              color: dark ? _darkSurface : const Color(0xFFDDF2EA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              all ? Icons.notifications_off_outlined : _emptyIcon(_filter),
              size: Responsive.w(context, 43),
              color: dark ? _darkMuted : const Color(0xFF7DA99A),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 22)),
        Text(
          all
              ? AppStrings.choose("You're all caught up", 'Bạn đã cập nhật hết')
              : AppStrings.choose(
                  'No $label notifications',
                  'Không có thông báo $label',
                ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 19),
            fontWeight: FontWeight.w700,
            color: dark ? _darkText : const Color(0xFF14382F),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          all
              ? AppStrings.choose(
                  'There are no new notifications right now.',
                  'Hiện không có thông báo mới.',
                )
              : AppStrings.choose(
                  'New notifications will appear here.',
                  'Các thông báo mới sẽ xuất hiện tại đây.',
                ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14),
            color: dark ? _darkSecondary : const Color(0xFF60736C),
          ),
        ),
        SizedBox(height: Responsive.h(context, 20)),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.notificationPreferences),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(
              AppStrings.choose(
                'Notification settings',
                'Xem cài đặt thông báo',
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _emptyIcon(_NotificationFilter filter) => switch (filter) {
    _NotificationFilter.actionRequired => Icons.task_alt_rounded,
    _NotificationFilter.transaction => Icons.receipt_long_outlined,
    _NotificationFilter.budget => Icons.account_balance_wallet_outlined,
    _NotificationFilter.goal => Icons.track_changes_rounded,
    _NotificationFilter.recurring => Icons.event_repeat_rounded,
    _NotificationFilter.community => Icons.groups_outlined,
    _NotificationFilter.system => Icons.info_outline_rounded,
    _ => Icons.notifications_off_outlined,
  };

  Widget _skeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      itemCount: 4,
      itemBuilder: (_, index) => Container(
        height: Responsive.h(context, index == 0 ? 92 : 116),
        margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? _darkSurface
              : const Color(0xFFE6F1ED),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  static Widget _circleIcon(IconData icon, Color color, Color background) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onPrimaryAction,
    required this.onReadToggle,
    required this.onArchive,
    this.onSecondaryAction,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback onReadToggle;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _semanticColor;
    return _SwipeRevealDelete(
      key: Key('notification-${notification.id}'),
      onDelete: onArchive,
      child: Material(
        color: notification.isRead
            ? (dark ? _darkCard.withValues(alpha: .9) : Colors.white)
            : (dark ? _darkCard : const Color(0xFFFAFFFD)),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 16, 13, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: notification.isRead
                    ? (dark ? _darkBorder : const Color(0xFFC9DDD5))
                    : (dark
                          ? _darkAccent.withValues(alpha: .45)
                          : const Color(0xFF8FCBB8)),
                width: notification.isRead ? 1.1 : 1.35,
              ),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? const Color(0x70000000)
                      : notification.isRead
                      ? const Color(0x2B00523C)
                      : const Color(0x3D007C61),
                  blurRadius: notification.isRead ? 20 : 24,
                  spreadRadius: notification.isRead ? 0 : .5,
                  offset: const Offset(0, 9),
                ),
                if (!dark)
                  const BoxShadow(
                    color: Color(0x12007C61),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leading(context, color),
                const SizedBox(width: 12),
                Expanded(child: _content(context, color)),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeLabel(notification.createdAt),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? _darkSecondary
                                : const Color(0xFF526A61),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: dark ? _darkMuted : const Color(0xFF6E7F79),
                      ),
                      onSelected: (value) {
                        if (value == 'read') onReadToggle();
                        if (value == 'archive') onArchive();
                        if (value == 'settings') {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.notificationPreferences);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'read',
                          child: Text(
                            notification.isRead
                                ? AppStrings.choose(
                                    'Mark as unread',
                                    'Đánh dấu chưa đọc',
                                  )
                                : AppStrings.choose(
                                    'Mark as read',
                                    'Đánh dấu đã đọc',
                                  ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            AppStrings.choose(
                              'Hide notification',
                              'Ẩn thông báo',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(AppStrings.choose('Settings', 'Cài đặt')),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = notification.isCommunity
        ? '${notification.actorDisplayName} ${notification.message}'
        : notification.message;
    final percent = (notification.payload['percent'] as num?)?.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.localizedTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: dark ? _darkText : const Color(0xFF0B3027),
          ),
        ),
        if (notification.actionRequired) ...[
          const SizedBox(height: 5),
          _statusPill(
            context,
            notification.type.contains('budget')
                ? AppStrings.choose('Over limit', 'Vượt hạn mức')
                : AppStrings.choose('Needs action', 'Cần xử lý'),
            notification.type.contains('budget') ? _amber : _coral,
          ),
        ],
        if (body.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            body,
            maxLines: notification.isCommunity ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: dark ? _darkSecondary : const Color(0xFF405B52),
            ),
          ),
        ],
        if (percent != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: .16),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
        if (notification.actionRequired || _showsViewAction) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onPrimaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(_primaryLabel),
              ),
              if (onSecondaryAction != null)
                TextButton(
                  onPressed: onSecondaryAction,
                  style: TextButton.styleFrom(
                    foregroundColor: dark ? _darkAccent : _emerald,
                    backgroundColor: dark
                        ? _darkSurface
                        : const Color(0xFFE0F3EC),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(AppStrings.choose('Skip', 'Bỏ qua')),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _leading(BuildContext context, Color color) {
    if (notification.isCommunity) {
      final avatar = notification.actorAvatarUrl;
      return SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withValues(alpha: .14),
              backgroundImage: avatar == null || avatar.isEmpty
                  ? null
                  : NetworkImage(avatar),
              child: avatar == null || avatar.isEmpty
                  ? Text(
                      notification.actorDisplayName.characters.firstOrNull ??
                          'F',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child:
                    notification.type == 'comment' ||
                        notification.type == 'comment_reply'
                    ? const CommunityCommentIcon(size: 10, color: Colors.white)
                    : Icon(_icon, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    final category = notification.payload['category']?.toString();
    final transactionCategory = category == null
        ? null
        : TransactionCategory.resolve(category);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child:
          (notification.category == NotificationCategory.budget ||
                  notification.category == NotificationCategory.transaction) &&
              transactionCategory != null
          ? transactionCategory.buildIcon(size: 21, color: color)
          : Icon(_icon, color: color, size: 21),
    );
  }

  IconData get _icon => switch (notification.category) {
    NotificationCategory.recurring =>
      notification.type.contains('fail') ||
              notification.type.contains('insufficient')
          ? Icons.event_busy_outlined
          : notification.actionRequired
          ? Icons.event_repeat_rounded
          : Icons.event_available_outlined,
    NotificationCategory.budget => Icons.account_balance_wallet_outlined,
    NotificationCategory.goal => Icons.track_changes_rounded,
    NotificationCategory.transaction => Icons.receipt_long_outlined,
    NotificationCategory.community => switch (notification.type) {
      'like' || 'comment_like' => Icons.favorite_rounded,
      'post' => Icons.share_rounded,
      _ => Icons.chat_bubble_rounded,
    },
    NotificationCategory.system => Icons.info_outline_rounded,
  };

  Color get _semanticColor => switch (notification.category) {
    NotificationCategory.recurring =>
      notification.type.contains('fail') ||
              notification.type.contains('insufficient')
          ? _coral
          : notification.actionRequired
          ? _violet
          : _emerald,
    NotificationCategory.budget =>
      notification.type.contains('exceeded') ? _coral : _amber,
    NotificationCategory.goal => _violet,
    NotificationCategory.transaction => _blue,
    NotificationCategory.community => switch (notification.type) {
      'like' || 'comment_like' => _coral,
      'comment' || 'comment_reply' => const Color(0xFF3799D2),
      _ => const Color(0xFF44BF99),
    },
    NotificationCategory.system => _blue,
  };

  bool get _showsViewAction =>
      notification.category == NotificationCategory.budget ||
      notification.category == NotificationCategory.goal ||
      notification.type.contains('automatic');

  String get _primaryLabel => switch (notification.category) {
    NotificationCategory.recurring => AppStrings.choose('Review', 'Xem lại'),
    NotificationCategory.budget => AppStrings.choose(
      'View budget',
      'Xem ngân sách',
    ),
    NotificationCategory.goal => AppStrings.choose('View goal', 'Xem mục tiêu'),
    NotificationCategory.community => AppStrings.choose(
      'View post',
      'Xem bài viết',
    ),
    NotificationCategory.transaction => AppStrings.choose(
      'View transaction',
      'Xem giao dịch',
    ),
    NotificationCategory.system => AppStrings.choose('View', 'Xem'),
  };

  static Widget _statusPill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return AppStrings.choose('Now', 'Bây giờ');
    if (diff.inMinutes < 60) {
      return AppStrings.choose('${diff.inMinutes}m', '${diff.inMinutes} phút');
    }
    if (diff.inHours < 24) {
      return AppStrings.choose('${diff.inHours}h', '${diff.inHours} giờ');
    }
    if (diff.inDays == 1) return AppStrings.choose('Yesterday', 'Hôm qua');
    return formatCommunityDate(value);
  }
}

class _SwipeRevealDelete extends StatefulWidget {
  const _SwipeRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeRevealDelete> createState() => _SwipeRevealDeleteState();
}

class _SwipeRevealDeleteState extends State<_SwipeRevealDelete>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 78.0;
  static const _cornerOverlap = 22.0;
  static const _deleteDuration = Duration(milliseconds: 220);
  double _offset = 0;
  bool _dragging = false;
  bool _deleting = false;
  late final AnimationController _deleteController;
  late final Animation<Offset> _deleteSlide;
  late final Animation<double> _deleteFade;

  @override
  void initState() {
    super.initState();
    _deleteController = AnimationController(
      vsync: this,
      duration: _deleteDuration,
    );
    final curved = CurvedAnimation(
      parent: _deleteController,
      curve: Curves.easeInCubic,
    );
    _deleteSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.08, 0),
    ).animate(curved);
    _deleteFade = Tween<double>(begin: 1, end: 0).animate(curved);
  }

  @override
  void dispose() {
    _deleteController.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_deleting) return;
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0);
    });
  }

  void _dragEnd(DragEndDetails details) {
    if (_deleting) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen = velocity < -220 || _offset < -(_actionWidth * .42);
    setState(() {
      _dragging = false;
      _offset = shouldOpen ? -_actionWidth : 0;
    });
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _dragging = false;
    });
    await _deleteController.forward();
    if (!mounted) return;
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: ReverseAnimation(_deleteController),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _deleteFade,
        child: SlideTransition(
          position: _deleteSlide,
          child: IgnorePointer(
            ignoring: _deleting,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: const Color(0xFFC91D22),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(20),
                      ),
                      child: InkWell(
                        key: const Key('notification-delete-action'),
                        onTap: _delete,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(20),
                        ),
                        child: SizedBox(
                          width: _actionWidth + _cornerOverlap,
                          height: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _cornerOverlap,
                            ),
                            child: Center(
                              child: Semantics(
                                label: AppStrings.choose(
                                  'Delete notification',
                                  'Xóa thông báo',
                                ),
                                button: true,
                                child: const FinFlowTrashIcon(
                                  color: Colors.white,
                                  size: 27,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: _dragUpdate,
                  onHorizontalDragEnd: _dragEnd,
                  child: AnimatedContainer(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(_offset, 0, 0),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
