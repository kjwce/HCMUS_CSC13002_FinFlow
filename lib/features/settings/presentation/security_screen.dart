import 'package:flutter/material.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/presentation/add_transaction_sheet.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  var _isDeleting = false;

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_rounded,
          color: Color(0xFFBA1A1A),
          size: 34,
        ),
        title: Text(AppStrings.choose('Delete account?', 'Xóa tài khoản?')),
        content: Text(
          AppStrings.choose(
            'Your profile and all associated financial data will be permanently deleted. This action cannot be undone.',
            'Hồ sơ và toàn bộ dữ liệu tài chính liên quan sẽ bị xóa vĩnh viễn. Không thể hoàn tác thao tác này.',
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
            ),
            child: Text(
              AppStrings.choose('Delete permanently', 'Xóa vĩnh viễn'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await AuthService.instance.deleteAccount();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Unable to delete account: $error',
              'Không thể xóa tài khoản: $error',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _securityDarkBackground : colors.pageBackground,
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 4,
        onAddTap: () => AddTransactionSheet.show(context),
      ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark
            ? _securityDarkBackground
            : colors.pageBackground,
        foregroundColor: isDark ? _securityDarkText : colors.primaryText,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        centerTitle: true,
        title: Text(
          AppStrings.security,
          style: TextStyle(
            color: isDark ? _securityDarkText : const Color(0xFF00785D),
            fontFamily: 'Hanken Grotesk',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 16),
          Responsive.h(context, 16),
          Responsive.w(context, 16),
          Responsive.h(context, 30),
        ),
        children: [
          _SecurityGroup(
            title: AppStrings.choose('Password Settings', 'Cài đặt mật khẩu'),
            children: [
              _SecurityRow(
                icon: Icons.lock_outline_rounded,
                title: AppStrings.choose('Change Password', 'Đổi mật khẩu'),
                subtitle: AppStrings.choose(
                  'Update your account password',
                  'Cập nhật mật khẩu tài khoản',
                ),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.changePassword),
              ),
              _SecurityRow(
                icon: Icons.verified_user_outlined,
                title: AppStrings.choose('Forgot Password', 'Quên mật khẩu'),
                subtitle: AppStrings.choose(
                  'Reset your account password via email',
                  'Đặt lại mật khẩu tài khoản qua email',
                ),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 26)),
          _SecurityGroup(
            title: AppStrings.choose('Danger Zone', 'Khu vực nguy hiểm'),
            danger: true,
            children: [
              _SecurityRow(
                icon: Icons.delete_outline_rounded,
                title: _isDeleting
                    ? AppStrings.choose(
                        'Deleting Account...',
                        'Đang xóa tài khoản...',
                      )
                    : AppStrings.choose('Delete Account', 'Xóa tài khoản'),
                subtitle: AppStrings.choose(
                  'Permanently delete your data',
                  'Xóa vĩnh viễn dữ liệu của bạn',
                ),
                danger: true,
                trailing: _isDeleting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isDeleting ? null : _confirmDeleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityGroup extends StatelessWidget {
  const _SecurityGroup({
    required this.title,
    required this.children,
    this.danger = false,
  });

  final String title;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? (danger
              ? _securityDarkDanger.withValues(alpha: 0.3)
              : _securityDarkBorder)
        : (danger ? const Color(0xFFFFD4D0) : colors.divider);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _securityDarkSurface : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0E002D22),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 14),
              vertical: Responsive.h(context, 10),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? (danger
                        ? _securityDarkDangerBackground.withValues(alpha: 0.5)
                        : _securityDarkGroupHeader)
                  : (danger
                        ? const Color(0xFFFFF0EF)
                        : const Color(0xFFF2F8F5)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: isDark
                    ? _securityDarkSecondaryText
                    : (danger
                          ? const Color(0xFFBA1A1A)
                          : const Color(0xFF00785D)),
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(
                height: 1,
                indent: Responsive.w(context, 14),
                color: isDark ? _securityDarkBorder : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? (danger ? _securityDarkDanger : _securityDarkAccent)
        : (danger ? const Color(0xFFBA1A1A) : const Color(0xFF008C6B));
    return InkWell(
      onTap: onTap,
      overlayColor: WidgetStatePropertyAll(
        isDark ? _securityDarkBorder.withValues(alpha: 0.45) : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 14),
          vertical: Responsive.h(context, 14),
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.w(context, 42),
              height: Responsive.w(context, 42),
              decoration: BoxDecoration(
                color: isDark
                    ? (danger
                          ? _securityDarkDangerBackground
                          : _securityDarkIconBackground)
                    : (danger
                          ? const Color(0xFFFFE7E5)
                          : const Color(0xFF00C99A)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? accent : (danger ? accent : Colors.white),
                size: Responsive.w(context, 21),
              ),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger
                          ? accent
                          : (isDark ? _securityDarkText : colors.primaryText),
                      fontSize: Responsive.sp(context, 15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? _securityDarkSecondaryText
                          : colors.secondaryText,
                      fontSize: Responsive.sp(context, 11),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? _securityDarkMutedText : colors.secondaryText,
                ),
          ],
        ),
      ),
    );
  }
}

const _securityDarkBackground = Color(0xFF081C18);
const _securityDarkSurface = Color(0xFF16352E);
const _securityDarkBorder = Color(0xFF29483F);
const _securityDarkText = Color(0xFFF4FBF8);
const _securityDarkSecondaryText = Color(0xFFA9C1B9);
const _securityDarkMutedText = Color(0xFF708D84);
const _securityDarkAccent = Color(0xFF38D6AC);
const _securityDarkGroupHeader = Color(0xFF112622);
const _securityDarkIconBackground = Color(0xFF0A241F);
const _securityDarkDanger = Color(0xFFFF6B70);
const _securityDarkDangerBackground = Color(0xFF301314);
