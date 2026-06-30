import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shell/finflow_app.dart';
import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
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
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final displayName = user?.fullName ?? AppStrings.noActiveUser;
    final userId = user?.id ?? '-';

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Cover ảnh ──────────────────────────────
              _ProfileCover(displayName: displayName),

              // ── White card ────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 160),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 76), // chỗ cho avatar
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _profileText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $userId',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _profileText,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _MenuItems(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // ── Avatar nằm TRÊN CÙNG trong Stack chính ──
              Positioned(
                top: 160 - 64,
                left: 0,
                right: 0,
                child: Center(
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: AppColors.lightGreen,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            displayName.trim().isEmpty
                                ? '?'
                                : displayName.trim().substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 40,
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
          height: 200,
          fit: BoxFit.cover,
        ),
        // Top bar
        Positioned(
          top: 12,
          left: 20,
          right: 20,
          child: Row(
            children: [
              const Spacer(),
              Text(
                AppStrings.profileTitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
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
  const _MenuItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_MenuItemData>[
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_profile.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: const Color(0xFF6DB6FE),
        label: AppStrings.editProfileMenuItem,
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(AppRoutes.editProfile),
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_security.svg',
          width: 24,
          height: 24,
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
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        bgColor: AppColors.blueAccent,
        label: AppStrings.settingMenu,
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(AppRoutes.settings),
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_help.svg',
          width: 24,
          height: 24,
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
          width: 24,
          height: 24,
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
            if (i < items.length - 1) const SizedBox(height: 34),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: data.onTap,
        child: Row(
          children: [
            // Rounded icon container
            Container(
              width: 57,
              height: 53,
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: SizedBox(width: 24, height: 24, child: data.icon),
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Text(
              data.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 15,
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
