import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/community/providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Shared notification bell with a live unread-count badge.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(notificationServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final unreadCount = service.unreadCount;
        return GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/notifications'),
          child: Container(
            width: Responsive.w(context, 36),
            height: Responsive.h(context, 36),
            decoration: BoxDecoration(
              color: isDark ? Colors.transparent : AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: SizedBox(
                    width: Responsive.w(context, 16),
                    height: Responsive.h(context, 20),
                    child: SvgPicture.asset(
                      'assets/icons/icon_notification.svg',
                      colorFilter: ColorFilter.mode(
                        isDark
                            ? const Color(0xFFF4FBF8)
                            : const Color(0xFF093030),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: Responsive.w(context, 18),
                      height: Responsive.w(context, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 9),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
