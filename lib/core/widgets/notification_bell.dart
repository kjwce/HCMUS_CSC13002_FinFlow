import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/responsive.dart';
import '../theme/app_colors.dart';

/// Notification bell icon with a circular green background,
/// matching the Figma design.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.w(context, 36),
      height: Responsive.h(context, 36),
      decoration: const BoxDecoration(
        color: AppColors.lightGreen,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: Responsive.w(context, 16),
          height: Responsive.h(context, 20),
          child: SvgPicture.asset(
            'assets/icons/icon_notification.svg',
            colorFilter: const ColorFilter.mode(
              Color(0xFF093030),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
