import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_manager.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';

/// Settings screen with cover image, back arrow + title, menu rows
/// matching Figma node 1:1314 "settings".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColors = context.finFlowColors;
    return Scaffold(
      backgroundColor: themeColors.pageBackground,
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 4,
        onAddTap: () => AddTransactionSheet.show(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Cover image ──
              SizedBox(
                height: Responsive.h(context, 206),
                width: double.infinity,
                child: Image.asset(
                  'assets/settings_cover.png',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Back arrow (trên cùng) ──
              Positioned(
                top: Responsive.h(context, 12),
                left: Responsive.w(context, 20),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.arrow_back,
                    color: _settingsText,
                    size: 24,
                  ),
                ),
              ),
              // ── Notification bell (phải) ──
              const Positioned(top: 12, right: 20, child: NotificationBell()),
              // ── Title "Settings" ở giữa cover ──
              Positioned(
                top: Responsive.h(context, 80),
                left: 0,
                right: 0,
                child: Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.sp(context, 20),
                    color: _settingsText,
                  ),
                ),
              ),

              // ── White card ──
              Container(
                margin: EdgeInsets.only(top: Responsive.h(context, 180)),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.h(context, 60)),
                    // Menu items
                    _buildMenuList(context),
                    SizedBox(height: Responsive.h(context, 40)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 38)),
      child: Column(
        children: [
          const _SettingsMenuRow(
            icon: Icons.notifications_outlined,
            label: 'Notification Settings',
            action: ActionType.comingSoon,
          ),
          SizedBox(height: Responsive.h(context, 48)),
          const _SettingsMenuRow(
            icon: Icons.lock_outline,
            label: 'Password Settings',
            action: ActionType.navigatePassword,
          ),
          SizedBox(height: Responsive.h(context, 48)),
          const _SettingsMenuRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Budget Limit',
            action: ActionType.editBudget,
          ),
          SizedBox(height: Responsive.h(context, 48)),
          const _DarkModeToggle(),
          SizedBox(height: Responsive.h(context, 48)),
          const _SettingsMenuRow(
            icon: Icons.delete_outline,
            label: 'Delete Account',
            iconColor: Colors.red,
            labelColor: Colors.red,
            action: ActionType.deleteAccount,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Dark Mode toggle row
// ─────────────────────────────────────────────────────────────────────

class _DarkModeToggle extends StatelessWidget {
  const _DarkModeToggle();

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeManager.instance.isDark;
    final colors = context.finFlowColors;
    return GestureDetector(
      onTap: () => AppThemeManager.instance.toggle(),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: Responsive.w(context, 31),
            height: Responsive.w(context, 31),
            child: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: colors.primaryText,
              size: Responsive.w(context, 22),
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          Expanded(
            child: Text(
              isDark ? 'Dark Mode (ON)' : 'Dark Mode (OFF)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 15),
                color: colors.primaryText,
              ),
            ),
          ),
          Icon(
            isDark ? Icons.toggle_on : Icons.toggle_off_outlined,
            color: colors.primaryText,
            size: Responsive.w(context, 28),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Action types for menu items
// ─────────────────────────────────────────────────────────────────────

enum ActionType { comingSoon, navigatePassword, deleteAccount, editBudget }

// ─────────────────────────────────────────────────────────────────────
//  Individual menu row
// ─────────────────────────────────────────────────────────────────────

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.icon,
    required this.label,
    required this.action,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final ActionType action;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? const Color(0xFF093030);

    return GestureDetector(
      onTap: () => _handleTap(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: Responsive.w(context, 31),
            height: Responsive.w(context, 31),
            child: Icon(
              icon,
              color: effectiveColor,
              size: Responsive.w(context, 22),
            ),
          ),
          SizedBox(width: Responsive.w(context, 16)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: Responsive.sp(context, 15),
                color: labelColor ?? const Color(0xFF363130),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: const Color(0xFF093030),
            size: Responsive.w(context, 24),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (action) {
      case ActionType.comingSoon:
        _showComingSoonDialog(context);
      case ActionType.navigatePassword:
        Navigator.of(context).pushNamed(AppRoutes.newPassword);
      case ActionType.deleteAccount:
        _showDeleteConfirmation(context);
      case ActionType.editBudget:
        _showBudgetDialog(context);
    }
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.comingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final currentLimit = user?.budgetLimit ?? 0;
    final controller = TextEditingController(
      text: currentLimit > 0 ? _addCommas(currentLimit.toString()) : '',
    );
    var isFormatting = false;

    void formatAmount() {
      if (isFormatting) return;
      isFormatting = true;
      final text = controller.text.replaceAll(',', '');
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        controller.text = '';
      } else {
        final formatted = _addCommas(digits);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      isFormatting = false;
    }

    controller.addListener(formatAmount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Budget Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set your monthly spending limit:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: Responsive.h(context, 12)),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '5,000,000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.removeListener(formatAmount);
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final raw = controller.text.trim().replaceAll(',', '');
              final amount = int.tryParse(raw);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              try {
                await AuthService.instance.updateProfile(
                  fullName: user?.fullName ?? 'User',
                  budgetLimit: amount,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Budget limit updated')),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.confirmClearTitle),
        content: const Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // TODO: implement account deletion flow
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

const _settingsText = Color(0xFF093030);

/// Format a numeric string with thousand-separator commas.
String _addCommas(String digits) {
  final buffer = StringBuffer();
  int count = 0;
  for (int i = digits.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
    count++;
  }
  return buffer.toString().split('').reversed.join();
}
