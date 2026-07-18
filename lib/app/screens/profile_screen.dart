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
/// The original profile header uses a cover image with an overlapping avatar.
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

    return Scaffold(
      backgroundColor: context.finFlowColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileCover(
                avatarUrl: user?.avatarUrl,
                displayName: displayName,
              ),
              Container(
                margin: EdgeInsets.only(top: Responsive.h(context, 216)),
                decoration: BoxDecoration(
                  color: context.finFlowColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.h(context, 76)),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(context, 20),
                        color: _profileText,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    _MenuItems(onTabChanged: onTabChanged),
                    SizedBox(height: Responsive.h(context, 40)),
                  ],
                ),
              ),
              Positioned(
                top: Responsive.h(context, 152),
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
// Cover image and header
// ---------------------------------------------------------------------------

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: Responsive.h(context, 56),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: Responsive.w(context, 15),
                  backgroundColor: AppColors.lightGreen,
                  backgroundImage:
                      avatarUrl != null && avatarUrl!.trim().isNotEmpty
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null || avatarUrl!.trim().isEmpty
                      ? Text(
                          displayName.trim().isEmpty
                              ? '?'
                              : displayName
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: Responsive.sp(context, 12),
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: Responsive.w(context, 10)),
                Text(
                  AppStrings.profileTitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.sp(context, 20),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.finFlowColors.primaryText
                        : const Color(0xFF006B52),
                  ),
                ),
                const Spacer(),
                const NotificationBell(),
              ],
            ),
          ),
        ),
        Image.asset(
          'assets/profile_cover.png',
          width: double.infinity,
          height: Responsive.h(context, 200),
          fit: BoxFit.cover,
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
          colorFilter: const ColorFilter.mode(
            Color(0xFF2389B8),
            BlendMode.srcIn,
          ),
        ),
        bgColor: const Color(0xFFE8F5FB),
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
          colorFilter: const ColorFilter.mode(
            Color(0xFF168B68),
            BlendMode.srcIn,
          ),
        ),
        bgColor: const Color(0xFFE6F7EF),
        label: AppStrings.security,
        onTap: () {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed(AppRoutes.security);
        },
      ),
      _MenuItemData(
        icon: SvgPicture.asset(
          'assets/icons/icon_setting.svg',
          width: Responsive.w(context, 24),
          height: Responsive.h(context, 24),
          colorFilter: const ColorFilter.mode(
            Color(0xFF72831F),
            BlendMode.srcIn,
          ),
        ),
        bgColor: const Color(0xFFF3F5D9),
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
          colorFilter: const ColorFilter.mode(
            Color(0xFFA33CAA),
            BlendMode.srcIn,
          ),
        ),
        bgColor: const Color(0xFFF7EAF8),
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
          colorFilter: const ColorFilter.mode(
            Color(0xFFD84A55),
            BlendMode.srcIn,
          ),
        ),
        bgColor: const Color(0xFFFCEBED),
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
              SizedBox(height: Responsive.h(context, 10)),
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
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x14006C46)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1200523C),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: data.onTap,
            child: Container(
              constraints: BoxConstraints(minHeight: Responsive.h(context, 62)),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 12),
                vertical: Responsive.h(context, 10),
              ),
              child: Row(
                children: [
                  Container(
                    width: Responsive.w(context, 40),
                    height: Responsive.w(context, 40),
                    padding: EdgeInsets.all(Responsive.w(context, 8)),
                    decoration: BoxDecoration(
                      color: data.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: data.icon,
                  ),
                  SizedBox(width: Responsive.w(context, 14)),
                  Expanded(
                    child: Text(
                      data.label,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.sp(context, 15),
                        color: _profileText,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: Responsive.w(context, 20),
                    color: const Color(0xFF7D8985),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
