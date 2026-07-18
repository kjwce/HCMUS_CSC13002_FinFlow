import 'package:flutter/material.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../app/shell/finflow_app.dart';
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
        title: const Text('Delete account?'),
        content: const Text(
          'Your profile and all associated financial data will be permanently deleted. This action cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
            ),
            child: const Text('Delete permanently'),
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
        SnackBar(content: Text('Unable to delete account: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
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
        centerTitle: true,
        title: const Text(
          'Security',
          style: TextStyle(
            color: Color(0xFF00785D),
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
            title: 'Password Settings',
            children: [
              _SecurityRow(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.changePassword),
              ),
              _SecurityRow(
                icon: Icons.verified_user_outlined,
                title: 'Forgot Password',
                subtitle: 'Reset your account password via email',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 26)),
          _SecurityGroup(
            title: 'Danger Zone',
            danger: true,
            children: [
              _SecurityRow(
                icon: Icons.delete_outline_rounded,
                title: _isDeleting ? 'Deleting Account...' : 'Delete Account',
                subtitle: 'Permanently delete your data',
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
    final borderColor = danger ? const Color(0xFFFFD4D0) : colors.divider;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
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
              color: danger ? const Color(0xFFFFF0EF) : const Color(0xFFF2F8F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: danger
                    ? const Color(0xFFBA1A1A)
                    : const Color(0xFF00785D),
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(height: 1, indent: Responsive.w(context, 14)),
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
    final accent = danger ? const Color(0xFFBA1A1A) : const Color(0xFF008C6B);
    return InkWell(
      onTap: onTap,
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
                color: danger
                    ? const Color(0xFFFFE7E5)
                    : const Color(0xFF00C99A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: danger ? accent : Colors.white,
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
                      color: danger ? accent : colors.primaryText,
                      fontSize: Responsive.sp(context, 15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontSize: Responsive.sp(context, 11),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: colors.secondaryText),
          ],
        ),
      ),
    );
  }
}
