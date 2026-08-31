import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/notification_bell.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../shell/finflow_app.dart';

const _profileBackground = Color(0xFFEDF7F3);
const _profileText = Color(0xFF102F29);
const _secondaryText = Color(0xFF52655E);
const _profileBorder = Color(0xFFE3EAE7);
const _profileDarkBackground = Color(0xFF081C18);
const _profileDarkSurface = Color(0xFF16352E);
const _profileDarkBorder = Color(0xFF29483F);
const _profileDarkText = Color(0xFFF4FBF8);
const _profileDarkSecondaryText = Color(0xFFA9C1B9);
const _profileDarkMutedText = Color(0xFF708D84);
const _profileDarkLogout = Color(0xFFFF6B70);

/// Profile screen shown inside [MainShell] bottom navigation.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.onTabChanged});

  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final displayName = user?.fullName ?? AppStrings.noActiveUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? _profileDarkBackground : _profileBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 16),
            0,
            Responsive.w(context, 16),
            Responsive.h(context, 28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProfileHeader(),
              SizedBox(height: Responsive.h(context, 8)),
              _ProfileSummaryCard(
                avatarUrl: user?.avatarUrl,
                displayName: displayName,
                email: email,
              ),
              SizedBox(height: Responsive.h(context, 14)),
              _ProfileMenuGroups(onTabChanged: onTabChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: Responsive.h(context, 56),
      child: Row(
        children: [
          Text(
            AppStrings.profileTitle,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 21),
              fontWeight: FontWeight.w800,
              color: isDark ? _profileDarkText : const Color(0xFF005D49),
            ),
          ),
          const Spacer(),
          const NotificationBell(),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.avatarUrl,
    required this.displayName,
    required this.email,
  });

  final String? avatarUrl;
  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.h(context, 112)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 18),
        vertical: Responsive.h(context, 16),
      ),
      decoration: BoxDecoration(
        color: isDark ? _profileDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? _profileDarkBorder : _profileBorder),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x16004736),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.w(context, 76),
            height: Responsive.w(context, 76),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? _profileDarkBackground : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? _profileDarkBorder : Colors.transparent,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24004736),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.lightGreen,
              backgroundImage: avatarUrl?.trim().isNotEmpty == true
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl?.trim().isNotEmpty == true
                  ? null
                  : Text(
                      displayName.trim().isEmpty
                          ? '?'
                          : displayName.trim().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: Responsive.sp(context, 28),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 19),
                    fontWeight: FontWeight.w800,
                    color: isDark ? _profileDarkText : _profileText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 3)),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 12.5),
                    fontWeight: FontWeight.w500,
                    color: isDark ? _profileDarkSecondaryText : _secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.bgColor,
    required this.darkBgColor,
    required this.label,
    required this.description,
    required this.onTap,
    this.isDestructive = false,
  });

  final Widget icon;
  final Color bgColor;
  final Color darkBgColor;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool isDestructive;
}

class _ProfileMenuGroups extends ConsumerWidget {
  const _ProfileMenuGroups({this.onTabChanged});

  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editProfile = _MenuItemData(
      icon: SvgPicture.asset(
        'assets/icons/icon_profile.svg',
        colorFilter: const ColorFilter.mode(Color(0xFF387CE8), BlendMode.srcIn),
      ),
      bgColor: const Color(0xFFEAF2FF),
      darkBgColor: const Color(0x333B82F6),
      label: AppStrings.editProfileMenuItem,
      description: AppStrings.choose(
        'Photo, name & personal details',
        'Ảnh, tên và thông tin cá nhân',
      ),
      onTap: () async {
        final result = await Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(AppRoutes.editProfile);
        if (result is int && context.mounted) onTabChanged?.call(result);
      },
    );
    final security = _MenuItemData(
      icon: SvgPicture.asset(
        'assets/icons/icon_security.svg',
        colorFilter: const ColorFilter.mode(Color(0xFF007C61), BlendMode.srcIn),
      ),
      bgColor: const Color(0xFFE5F4EF),
      darkBgColor: const Color(0x3322C55E),
      label: AppStrings.security,
      description: AppStrings.choose('Passwords & 2FA', 'Mật khẩu và 2FA'),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(AppRoutes.security),
    );
    final settings = _MenuItemData(
      icon: SvgPicture.asset(
        'assets/icons/icon_setting.svg',
        colorFilter: const ColorFilter.mode(Color(0xFFFF6B00), BlendMode.srcIn),
      ),
      bgColor: const Color(0xFFFFEED9),
      darkBgColor: const Color(0x33F59E0B),
      label: AppStrings.choose('App Settings', 'Cài đặt ứng dụng'),
      description: AppStrings.choose(
        'Notifications & Theme',
        'Thông báo và giao diện',
      ),
      onTap: () async {
        final result = await Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(AppRoutes.settings);
        if (result is int && context.mounted) onTabChanged?.call(result);
      },
    );
    final community = _MenuItemData(
      icon: Icon(
        Icons.groups_rounded,
        size: Responsive.w(context, 23),
        color: const Color(0xFF00A78B),
      ),
      bgColor: const Color(0xFFDDF8F1),
      darkBgColor: const Color(0x3314B8A6),
      label: AppStrings.choose('Community Activity', 'Hoạt động cộng đồng'),
      description: AppStrings.choose(
        'Your posts & comments',
        'Bài viết và bình luận của bạn',
      ),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(AppRoutes.communityActivity),
    );
    final help = _MenuItemData(
      // Keep FinFlow's original Help asset instead of Stitch's question icon.
      icon: SvgPicture.asset(
        'assets/icons/icon_help.svg',
        colorFilter: const ColorFilter.mode(Color(0xFFA33CAA), BlendMode.srcIn),
      ),
      bgColor: const Color(0xFFF5E8F8),
      darkBgColor: const Color(0x338B5CF6),
      label: AppStrings.choose('Help & Support', 'Trợ giúp và hỗ trợ'),
      description: AppStrings.choose(
        'FAQs & Chat with us',
        'Câu hỏi thường gặp và trò chuyện hỗ trợ',
      ),
      onTap: () {},
    );
    final logout = _MenuItemData(
      icon: SvgPicture.asset(
        'assets/icons/icon_logout.svg',
        colorFilter: const ColorFilter.mode(Color(0xFFD83A45), BlendMode.srcIn),
      ),
      bgColor: const Color(0xFFFCEBED),
      darkBgColor: const Color(0x33FF6B70),
      label: AppStrings.logout,
      description: '',
      isDestructive: true,
      onTap: () async {
        await ref.read(authServiceProvider).signOut();
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
      },
    );

    return Column(
      children: [
        _MenuGroup(items: [editProfile, security, settings]),
        SizedBox(height: Responsive.h(context, 12)),
        _MenuGroup(items: [community, help]),
        SizedBox(height: Responsive.h(context, 12)),
        _MenuGroup(items: [logout], destructive: true),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, this.destructive = false});

  final List<_MenuItemData> items;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _profileDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? destructive
                    ? _profileDarkLogout.withValues(alpha: 0.35)
                    : _profileDarkBorder
              : destructive
              ? const Color(0xFFF0C9CC)
              : _profileBorder,
        ),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x11004736),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(data: items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 62,
                endIndent: 14,
                color: isDark ? _profileDarkBorder : const Color(0xFFE8ECEA),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.data});

  final _MenuItemData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 64)),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 13),
            vertical: Responsive.h(context, 8),
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.w(context, 38),
                height: Responsive.w(context, 38),
                padding: EdgeInsets.all(Responsive.w(context, 8)),
                decoration: BoxDecoration(
                  color: isDark ? data.darkBgColor : data.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: data.icon,
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 15.5),
                        fontWeight: FontWeight.w700,
                        color: data.isDestructive
                            ? (isDark
                                  ? _profileDarkLogout
                                  : const Color(0xFFB71927))
                            : (isDark ? _profileDarkText : _profileText),
                      ),
                    ),
                    if (data.description.isNotEmpty) ...[
                      SizedBox(height: Responsive.h(context, 1)),
                      Text(
                        data.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: Responsive.sp(context, 13),
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? _profileDarkSecondaryText
                              : _secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!data.isDestructive)
                Icon(
                  Icons.chevron_right_rounded,
                  size: Responsive.w(context, 20),
                  color: isDark
                      ? _profileDarkMutedText
                      : const Color(0xFF8BB6AB),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
