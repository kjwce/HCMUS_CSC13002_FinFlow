import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shell/finflow_app.dart';
import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/notification_bell.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Profile screen shown inside [MainShell] bottom navigation.
///
/// Layout (from Figma node 1:838 "profile"):
///   - Green-gradient cover image (full width, top)
///   - Back arrow (left) + "Profile" title (center) + notification bell (right)
///   - Circle avatar (128x128) overlapping cover bottom edge
///   - Username (Poppins Bold 20px) and ID (Poppins SemiBold 13px)
///   - Menu items: Edit Profile, Security, Setting, Help, Logout
///     each with a rounded icon container (57x53, r22) and label
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.onTabChanged});

  /// Called when a pushed screen (Settings / EditProfile) pops with a tab
  /// index — forwards it to MainShell so the bottom-nav tab switches.
  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final displayName = user?.fullName ?? AppStrings.noActiveUser;
    final userId = user?.id ?? '-';

    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Cover ảnh ──────────────────────────────
              _ProfileCover(displayName: displayName),

              // ── White card ────────────────────────────
              Container(
                margin: EdgeInsets.only(top: Responsive.h(context, 160)),
                decoration: BoxDecoration(
                  color: context.finFlowColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: Responsive.h(context, 76),
                    ), // chỗ cho avatar
                    Text(
                      displayName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(context, 20),
                        color: _profileText,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 4)),
                    Text(
                      'ID: $userId',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.sp(context, 13),
                        color: _profileText,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 32)),
                    _MenuItems(onTabChanged: onTabChanged),
                    SizedBox(height: Responsive.h(context, 40)),
                  ],
                ),
              ),

              // ── Avatar nằm TRÊN CÙNG trong Stack chính ──
              Positioned(
                top: Responsive.h(context, 160 - 64),
                left: 0,
                right: 0,
                child: Center(
                  child: CircleAvatar(
                    radius: Responsive.w(context, 64),
                    backgroundColor: AppColors.lightGreen,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            displayName.trim().isEmpty
                                ? '?'
                                : displayName
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: Responsive.sp(context, 40),
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _profileText = Color(0xFF093030);

// ---------------------------------------------------------------------------
// Cover - gradient + header bar + avatar
// ---------------------------------------------------------------------------

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cover image
        Image.asset(
          'assets/profile_cover.png',
          width: double.infinity,
          height: Responsive.h(context, 200),
          fit: BoxFit.cover,
        ),
        // Top bar
        Positioned(
          top: Responsive.h(context, 12),
          left: Responsive.w(context, 20),
          right: Responsive.w(context, 20),
          child: Row(
            children: [
              const Spacer(),
              Text(
                AppStrings.profileTitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.sp(context, 20),
                  color: _profileText,
                ),
              ),
              const Spacer(),
              const NotificationBell(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu items list
// ---------------------------------------------------------------------------

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.bgColor,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final Color bgColor;
  final String label;
  final VoidCallback onTap;
}

class _MenuItems extends ConsumerWidget {
  const _MenuItems({this.onTabChanged});

  /// Forwards tab‑change results popped from pushed screens
  /// (Settings / EditProfile) so the bottom‑nav tab switches.
  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_MenuItemData>[
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_profile.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: const Color(0xFF6DB6FE),
        label: AppStrings.editProfileMenuItem,
        onTap: () async {
          final result = await Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed(AppRoutes.editProfile);
          if (result is int && context.mounted) {
            onTabChanged?.call(result);
          }
        },
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_security.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: const Color(0xFF3299FF),
        label: AppStrings.security,
        onTap: () {
          // TODO: navigate to security screen
        },
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_setting.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: AppColors.blueAccent,
        label: AppStrings.settingMenu,
        onTap: () async {
          final result = await Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed(AppRoutes.settings);
          if (result is int && context.mounted) {
            onTabChanged?.call(result);
          }
        },
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_help.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: const Color(0xFF6DB6FE),
        label: AppStrings.help,
        onTap: () {
          // TODO: navigate to help screen
        },
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_logout.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: const Color(0xFF3299FF),
        label: AppStrings.logout,
        onTap: () async {
          await ref.read(authServiceProvider).signOut();
          if (!context.mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
        },
      ),
    ];

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        return Column(
          children: [
            _MenuRow(data: item),
            if (i < items.length - 1)
              SizedBox(height: Responsive.h(context, 34)),
          ],
        );
      }),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.data});

  final _MenuItemData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 24)),
      child: GestureDetector(
        onTap: data.onTap,
        child: Row(
          children: [
            // Rounded icon container
            Container(
              width: Responsive.w(context, 57),
              height: Responsive.h(context, 53),
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: SizedBox(
                  width: Responsive.w(context, 24),
                  height: Responsive.h(context, 24),
                  child: data.icon,
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 16)),
            // Label
            Text(
              data.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 15),
                color: _profileText,
              ),
            ),
            const Spacer(),
            // Chevron
            const Icon(Icons.chevron_right, color: _profileText),
          ],
        ),
      ),
    );
  }
}
