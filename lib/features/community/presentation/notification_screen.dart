import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../app/screens/community_post_detail_screen.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/community_date_format.dart';
import '../utils/rich_text_formatter.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF8),
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
    return Container(
      color: const Color(0xFFD4F4E4),
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
              color: const Color(0xFF002117),
            ),
          ),
          const Spacer(),
          Text(
            'Notifications',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: Responsive.sp(context, 20),
              color: const Color(0xFF002117),
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            GestureDetector(
              onTap: () async {
                await ref.read(notificationServiceProvider).markAllAsRead();
              },
              child: Text(
                'Mark all as read',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 12),
                  color: AppColors.primaryGreen,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: Responsive.w(context, 48),
            color: const Color(0xFF8E918F),
          ),
          SizedBox(height: Responsive.h(context, 12)),
          Text(
            "You're all caught up!",
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 14),
              color: const Color(0xFF8E918F),
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
          _buildSectionHeader('Today', today.where((n) => !n.isRead).length),
          ...today.map(
            (n) => _NotificationTile(
              notification: n,
              onTap: () => _onTapNotification(n),
            ),
          ),
        ],
        if (earlier.isNotEmpty) ...[
          _buildSectionHeader('Earlier', null),
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
              color: const Color(0xFF002117),
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
                '$newCount New',
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
    switch (notification.type) {
      case 'post':
        return Icons.share_rounded;
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case 'post':
        return const Color(0xFF44BF99);
      case 'like':
        return const Color(0xFFE86B5D);
      case 'comment':
        return const Color(0xFF3799D2);
      default:
        return const Color(0xFF44BF99);
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
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
            color: notification.isRead ? Colors.white : const Color(0xFFF0F8F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0x1A006C46)
                  : const Color(0x4000A77A),
            ),
            boxShadow: const [
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
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
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
                          color: const Color(0xFF404944),
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: notification.actorDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                        color: const Color(0xFF8E918F),
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
      child: Text(
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
