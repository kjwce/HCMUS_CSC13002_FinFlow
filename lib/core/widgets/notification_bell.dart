import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/community/providers/notification_provider.dart';
import '../i18n/app_language.dart';
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
        final tooltip = AppStrings.choose('Notifications', 'Thông báo');
        return Semantics(
          button: true,
          label: tooltip,
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              key: const Key('notification-bell'),
              onTap: () => Navigator.of(context).pushNamed('/notifications'),
              customBorder: const CircleBorder(),
              child: Container(
                key: const Key('notification-bell-circle'),
                width: Responsive.w(context, 40),
                height: Responsive.w(context, 40),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0A241F)
                      : const Color(0xFFD7F5EA),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF29483F)
                        : const Color(0xFFD3EFE5),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: Responsive.w(context, 22),
                        child: SvgPicture.asset(
                          'assets/icons/phosphor-bell-ringing-regular.svg',
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            isDark
                                ? const Color(0xFF38D6AC)
                                : const Color(0xFF006C53),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: Responsive.h(context, -5),
                        right: Responsive.w(context, -5),
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: Responsive.w(context, 19),
                            minHeight: Responsive.w(context, 19),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6524A),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF00251E)
                                  : const Color(0xFFF5FCF9),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: Responsive.sp(context, 9.5),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
