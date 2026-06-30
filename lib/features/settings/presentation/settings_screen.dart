import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_manager.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/services/auth_service.dart';

/// Settings screen with cover image, back arrow + title, menu rows
/// matching Figma node 1:1314 "settings".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      bottomNavigationBar: const AppBottomNavBar(selectedIndex: 4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Cover image ──
              SizedBox(
                height: 206,
                width: double.infinity,
                child: Image.asset(
                  'assets/settings_cover.png',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Back arrow (trên cùng) ──
              Positioned(
                top: 12,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back,
                      color: _settingsText, size: 24),
                ),
              ),
              // ── Notification bell (phải) ──
              const Positioned(
                top: 12,
                right: 20,
                child: NotificationBell(),
              ),
              // ── Title "Settings" ở giữa cover ──
              const Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: _settingsText,
                  ),
                ),
              ),

              // ── White card ──
              Container(
                margin: const EdgeInsets.only(top: 180),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Menu items
                    _buildMenuList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Column(
        children: [
          const _SettingsMenuRow(
            icon: Icons.notifications_outlined,
            label: 'Notification Settings',
            action: ActionType.comingSoon,
          ),
          const SizedBox(height: 48),
          const _SettingsMenuRow(
            icon: Icons.lock_outline,
            label: 'Password Settings',
            action: ActionType.navigatePassword,
          ),
          const SizedBox(height: 48),
          const _SettingsMenuRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Budget Limit',
            action: ActionType.editBudget,
          ),
          const SizedBox(height: 48),
          const _DarkModeToggle(),
          const SizedBox(height: 48),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => AppThemeManager.instance.toggle(),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 31,
            height: 31,
            child: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: const Color(0xFF093030),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isDark ? 'Dark Mode (ON)' : 'Dark Mode (OFF)',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Color(0xFF363130),
              ),
            ),
          ),
          Icon(
            isDark ? Icons.toggle_on : Icons.toggle_off_outlined,
            color: const Color(0xFF093030),
            size: 28,
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
            width: 31,
            height: 31,
            child: Icon(icon, color: effectiveColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: labelColor ?? const Color(0xFF363130),
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF093030), size: 24),
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
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '5,000,000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
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
