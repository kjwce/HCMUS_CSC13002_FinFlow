import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  var _hideCurrent = true;
  var _hideNew = true;
  var _hideConfirm = true;
  var _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentController.text;
    final newPassword = _newController.text;
    final confirmation = _confirmController.text;
    if (currentPassword.isEmpty) {
      _showMessage(
        AppStrings.choose(
          'Please enter your current password.',
          'Vui lòng nhập mật khẩu hiện tại.',
        ),
      );
      return;
    }
    if (newPassword.length < 6) {
      _showMessage(AppStrings.passwordTooShort);
      return;
    }
    if (newPassword != confirmation) {
      _showMessage(AppStrings.passwordsDoNotMatch);
      return;
    }
    if (newPassword == currentPassword) {
      _showMessage(
        AppStrings.choose(
          'The new password must be different.',
          'Mật khẩu mới phải khác mật khẩu hiện tại.',
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Password changed successfully.',
              'Đổi mật khẩu thành công.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(
        AppStrings.choose(
          'Current password is incorrect or could not be verified.',
          'Mật khẩu hiện tại không đúng hoặc không thể xác minh.',
        ),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.primaryText,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          AppStrings.choose('Change Password', 'Đổi mật khẩu'),
          style: const TextStyle(
            color: Color(0xFF00785D),
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(Responsive.w(context, 20)),
          children: [
            Container(
              width: Responsive.w(context, 72),
              height: Responsive.w(context, 72),
              margin: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 125),
                vertical: Responsive.h(context, 14),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFE4F5EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF00785D),
                size: 34,
              ),
            ),
            SizedBox(height: Responsive.h(context, 10)),
            Text(
              AppStrings.choose(
                'Create a strong password you do not use for other accounts.',
                'Tạo mật khẩu mạnh mà bạn không dùng cho tài khoản khác.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: Responsive.sp(context, 14),
              ),
            ),
            SizedBox(height: Responsive.h(context, 28)),
            _PasswordField(
              controller: _currentController,
              label: AppStrings.choose('Current Password', 'Mật khẩu hiện tại'),
              obscureText: _hideCurrent,
              onToggleVisibility: () =>
                  setState(() => _hideCurrent = !_hideCurrent),
            ),
            SizedBox(height: Responsive.h(context, 16)),
            _PasswordField(
              controller: _newController,
              label: AppStrings.newPasswordLabel,
              obscureText: _hideNew,
              onToggleVisibility: () => setState(() => _hideNew = !_hideNew),
            ),
            SizedBox(height: Responsive.h(context, 16)),
            _PasswordField(
              controller: _confirmController,
              label: AppStrings.confirmNewPasswordLabel,
              obscureText: _hideConfirm,
              onToggleVisibility: () =>
                  setState(() => _hideConfirm = !_hideConfirm),
            ),
            SizedBox(height: Responsive.h(context, 30)),
            FilledButton(
              onPressed: _isSaving ? null : _changePassword,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007F62),
                minimumSize: Size.fromHeight(Responsive.h(context, 52)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      AppStrings.choose('Update Password', 'Cập nhật mật khẩu'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        filled: true,
        fillColor: context.finFlowColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
