import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../app/screens/community_post_detail_screen.dart';
import '../../../app/shell/finflow_app.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/community_date_format.dart';
import '../utils/rich_text_formatter.dart';
import 'widgets/community_comment_icon.dart';

const _notificationDarkBackground = Color(0xFF081C18);
const _notificationDarkSurface = Color(0xFF112622);
const _notificationDarkCard = Color(0xFF16352E);
const _notificationDarkBorder = Color(0xFF29483F);
const _notificationDarkPrimary = Color(0xFFF4FBF8);
const _notificationDarkSecondary = Color(0xFFA9C1B9);
const _notificationDarkMuted = Color(0xFF708D84);
const _notificationDarkAccent = Color(0xFF38D6AC);

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(notificationServiceProvider);
      await service.fetchNotifications();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(notificationServiceProvider);
    final notifs = service.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? _notificationDarkBackground
          : const Color(0xFFF9FBF8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(service.unreadCount),
            const SizedBox(height: 16),
            Expanded(
              child: !_loaded && service.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : notifs.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationList(notifs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _notificationDarkSurface : const Color(0xFFD4F4E4),
        border: isDark
            ? const Border(bottom: BorderSide(color: _notificationDarkBorder))
            : null,
      ),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(context, 14),
        horizontal: Responsive.w(context, 16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: Responsive.w(context, 18),
              color: isDark
                  ? _notificationDarkPrimary
                  : const Color(0xFF002117),
            ),
          ),
          const Spacer(),
          Text(
            AppStrings.choose('Notifications', 'Thông báo'),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: Responsive.sp(context, 20),
              color: isDark
                  ? _notificationDarkPrimary
                  : const Color(0xFF002117),
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            GestureDetector(
              onTap: () async {
                await ref.read(notificationServiceProvider).markAllAsRead();
              },
              child: Text(
                AppStrings.choose('Mark all as read', 'Đánh dấu đã đọc'),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 12),
                  color: isDark
                      ? _notificationDarkAccent
                      : AppColors.primaryGreen,
                ),
              ),
            )
          else
            SizedBox(width: Responsive.w(context, 80)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: Responsive.w(context, 48),
            color: isDark ? _notificationDarkMuted : const Color(0xFF8E918F),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Text(
            AppStrings.choose(
              "You're all caught up!",
              'Bạn đã xem hết thông báo!',
            ),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 14),
              color: isDark
                  ? _notificationDarkSecondary
                  : const Color(0xFF8E918F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> notifs) {
    // Group by Today / Earlier
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final today = notifs.where((n) => n.createdAt.isAfter(todayStart)).toList();
    final earlier = notifs
        .where((n) => !n.createdAt.isAfter(todayStart))
        .toList();

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      children: [
        if (today.isNotEmpty) ...[
          _buildSectionHeader(
            AppStrings.choose('Today', 'Hôm nay'),
            today.where((n) => !n.isRead).length,
          ),
          ...today.map(
            (n) => _NotificationTile(
              notification: n,
              onTap: () => _onTapNotification(n),
            ),
          ),
        ],
        if (earlier.isNotEmpty) ...[
          _buildSectionHeader(AppStrings.choose('Earlier', 'Trước đó'), null),
          ...earlier.map(
            (n) => _NotificationTile(
              notification: n,
              onTap: () => _onTapNotification(n),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String label, int? newCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 12)),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: Responsive.sp(context, 14),
              color: isDark
                  ? _notificationDarkSecondary
                  : const Color(0xFF002117),
            ),
          ),
          if (newCount != null && newCount > 0) ...[
            SizedBox(width: Responsive.w(context, 8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 8),
                vertical: Responsive.h(context, 2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE86B5D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppStrings.choose('$newCount New', '$newCount mới'),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 10),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onTapNotification(NotificationModel notif) async {
    // Mark as read
    if (!notif.isRead) {
      await ref.read(notificationServiceProvider).markAsRead(notif.id);
    }
    if (notif.isRecurring && notif.scheduleId != null && mounted) {
      await Navigator.of(
        context,
      ).pushNamed(AppRoutes.recurringDetails, arguments: notif.scheduleId);
      return;
    }
    // Navigate to post detail if there's a post
    if (notif.postId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityPostDetailScreen(postId: notif.postId!),
        ),
      );
    }
  }
}

// Required for navigation — import this where you register routes
// Navigator.of(context).pushNamed('/notifications');

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  IconData get _icon {
    if (notification.isRecurring) return Icons.event_repeat_rounded;
    switch (notification.type) {
      case 'post':
        return Icons.share_rounded;
      case 'like':
      case 'comment_like':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    if (notification.isRecurring) {
      return notification.postingMode == 'review'
          ? const Color(0xFF6555D9)
          : const Color(0xFF00866A);
    }
    switch (notification.type) {
      case 'post':
        return const Color(0xFF44BF99);
      case 'like':
      case 'comment_like':
        return const Color(0xFFE86B5D);
      case 'comment':
      case 'comment_reply':
        return const Color(0xFF3799D2);
      default:
        return const Color(0xFF44BF99);
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return AppStrings.choose('Just now', 'Vừa xong');
    if (diff.inMinutes < 60) {
      return AppStrings.choose(
        '${diff.inMinutes}m ago',
        '${diff.inMinutes} phút trước',
      );
    }
    if (diff.inHours < 24) {
      return AppStrings.choose(
        '${diff.inHours}h ago',
        '${diff.inHours} giờ trước',
      );
    }
    if (diff.inDays < 2) return AppStrings.choose('Yesterday', 'Hôm qua');
    if (diff.inDays < 7) {
      return AppStrings.choose(
        '${diff.inDays}d ago',
        '${diff.inDays} ngày trước',
      );
    }
    return formatCommunityDate(notification.createdAt);
  }

  String get _displayMessage =>
      stripFormattingForNotificationPreview(notification.message);

  String get _initials {
    final words = notification.actorDisplayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'F';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 10)),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 14),
            vertical: Responsive.h(context, 13),
          ),
          decoration: BoxDecoration(
            color: isDark
                ? notification.isRead
                      ? _notificationDarkCard.withValues(alpha: .82)
                      : _notificationDarkCard
                : notification.isRead
                ? Colors.white
                : const Color(0xFFF0F8F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? notification.isRead
                        ? _notificationDarkBorder
                        : _notificationDarkAccent.withValues(alpha: .5)
                  : notification.isRead
                  ? const Color(0x1A006C46)
                  : const Color(0x4000A77A),
            ),
            boxShadow: isDark
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x2600523C),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: Responsive.w(context, 46),
                height: Responsive.w(context, 46),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 0, top: 0, child: _buildAvatar(context)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: Responsive.w(context, 18),
                        height: Responsive.w(context, 18),
                        decoration: BoxDecoration(
                          color: _iconColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? _notificationDarkCard
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child:
                            notification.type == 'comment' ||
                                notification.type == 'comment_reply'
                            ? CommunityCommentIcon(
                                size: Responsive.w(context, 10),
                                color: Colors.white,
                              )
                            : Icon(
                                _icon,
                                size: Responsive.w(context, 9),
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 13.5),
                          color: isDark
                              ? _notificationDarkSecondary
                              : const Color(0xFF404944),
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: notification.actorDisplayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? _notificationDarkPrimary : null,
                            ),
                          ),
                          TextSpan(text: ' $_displayMessage'),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 4)),
                    Text(
                      _timeAgo,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 11),
                        color: isDark
                            ? _notificationDarkMuted
                            : const Color(0xFF8E918F),
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

  Widget _buildAvatar(BuildContext context) {
    final size = Responsive.w(context, 40);
    final avatarUrl = notification.actorAvatarUrl?.trim();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _iconColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: notification.isRecurring
          ? Icon(
              Icons.calendar_month_rounded,
              color: _iconColor,
              size: Responsive.w(context, 21),
            )
          : Text(
              _initials,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 12),
                fontWeight: FontWeight.w700,
                color: _iconColor,
              ),
            ),
    );
    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
