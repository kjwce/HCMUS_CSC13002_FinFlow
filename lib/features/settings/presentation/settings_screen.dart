import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_manager.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'finflow_push_notifications';
  final _preferences = SharedPreferencesAsync();
  var _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifications());
  }

  Future<void> _loadNotifications() async {
    try {
      final saved = await _preferences.getBool(_notificationsKey);
      if (mounted && saved != null) {
        setState(() => _notificationsEnabled = saved);
      }
    } catch (_) {}
  }

  void _setNotifications(bool value) {
    setState(() => _notificationsEnabled = value);
    unawaited(_preferences.setBool(_notificationsKey, value));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppThemeManager.instance,
        AppLanguage.instance,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final colors = context.finFlowColors;
        final user = AuthService.instance.currentUser;
        final isVietnamese =
            AppLanguage.instance.locale == AppLocale.vietnamese;

        return Scaffold(
          backgroundColor: colors.pageBackground,
          bottomNavigationBar: AppBottomNavBar(
            selectedIndex: 4,
            onAddTap: () => AddTransactionSheet.show(context),
          ),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: colors.pageBackground,
            foregroundColor: colors.primaryText,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: Responsive.w(context, 16)),
                child: CircleAvatar(
                  radius: Responsive.w(context, 16),
                  backgroundColor: const Color(0xFFDDF4EC),
                  backgroundImage: user?.avatarUrl?.trim().isNotEmpty == true
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl?.trim().isNotEmpty == true
                      ? null
                      : Text(
                          (user?.fullName.trim().isNotEmpty ?? false)
                              ? user!.fullName.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF006B52),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 16),
              Responsive.h(context, 10),
              Responsive.w(context, 16),
              Responsive.h(context, 28),
            ),
            children: [
              _SettingsCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget Limit',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.budgetLimits),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              _SettingsCard(
                icon: Icons.notifications_none_rounded,
                title: 'Push Notifications',
                switchValue: _notificationsEnabled,
                onSwitchChanged: _setNotifications,
              ),
              SizedBox(height: Responsive.h(context, 12)),
              _SettingsCard(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                switchValue: AppThemeManager.instance.isDark,
                onSwitchChanged: (value) => AppThemeManager.instance.setMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              _SettingsCard(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: isVietnamese
                    ? 'Tiếng Việt / English'
                    : 'English / Tiếng Việt',
                switchValue: isVietnamese,
                onSwitchChanged: (value) => AppLanguage.instance.setLocale(
                  value ? AppLocale.vietnamese : AppLocale.english,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.switchValue,
    this.onSwitchChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Material(
      color: colors.surface,
      elevation: 0,
      shadowColor: const Color(0x16002820),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: BoxConstraints(minHeight: Responsive.h(context, 70)),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 14),
            vertical: Responsive.h(context, 12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10002F24),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.w(context, 42),
                height: Responsive.w(context, 42),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F5F0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: Responsive.w(context, 21),
                  color: const Color(0xFF00785D),
                ),
              ),
              SizedBox(width: Responsive.w(context, 14)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 15),
                        fontWeight: FontWeight.w600,
                        color: colors.primaryText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Responsive.h(context, 2)),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 11),
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (switchValue != null)
                Switch.adaptive(
                  value: switchValue!,
                  onChanged: onSwitchChanged,
                  activeTrackColor: const Color(0xFF00A77D),
                )
              else
                Icon(Icons.chevron_right_rounded, color: colors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
