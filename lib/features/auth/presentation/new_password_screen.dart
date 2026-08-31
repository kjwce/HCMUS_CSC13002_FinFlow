import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _isSubmitting = false;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final passwordIsValid =
        password.length >= 6 &&
        password.contains(RegExp('[A-Z]')) &&
        password.contains(RegExp(r'\d'));
    final passwordError = passwordIsValid
        ? null
        : AppStrings.choose(
            'Password does not meet all requirements.',
            'Mật khẩu chưa đáp ứng đầy đủ yêu cầu.',
          );
    final confirmError = confirm.isEmpty
        ? AppStrings.choose(
            'Please confirm your password.',
            'Vui lòng xác nhận mật khẩu.',
          )
        : (password != confirm ? AppStrings.passwordsDoNotMatch : null);
    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    if (passwordError != null || confirmError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authServiceProvider).updatePassword(newPassword: password);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Sign out to clear recovery session before navigating to the success page.
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.resetSuccess, (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _passwordError = AppStrings.choose(
          'Unable to update the password. Please try again.',
          'Không thể cập nhật mật khẩu. Vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.newPassword,
      headerTitle: AppStrings.choose('Reset Password', 'Đặt lại mật khẩu'),
      showBackButton: true,
      showLogo: false,
      showCardTitle: false,
      footerOutsideCard: true,
      cardHorizontalPadding: 14,
      cardVerticalPadding: 16,
      cardRadius: 12,
      footer: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false),
        child: Text(
          AppStrings.backToSignIn,
          style: TextStyle(
            fontSize: Responsive.sp(context, 15),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.choose('Create a new password', 'Tạo mật khẩu mới'),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 18),
              fontWeight: FontWeight.w700,
              color: authTitleColor(context),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 4)),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.choose(
              'Your new password must be different from passwords you have used before.',
              'Mật khẩu mới phải khác các mật khẩu bạn đã dùng trước đây.',
            ),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 15),
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: context.finFlowColors.secondaryText,
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        AuthField(
          label: AppStrings.newPasswordLabel,
          controller: _passwordController,
          icon: Icons.lock_outline,
          hintText: AppStrings.newPasswordLabel,
          obscureText: _obscurePassword,
          onToggleVisibility: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          isObscured: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        AuthField(
          label: AppStrings.confirmNewPasswordLabel,
          controller: _confirmController,
          icon: Icons.lock_outline,
          hintText: AppStrings.confirmNewPasswordLabel,
          obscureText: _obscureConfirm,
          onToggleVisibility: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          isObscured: _obscureConfirm,
          errorText: _confirmError,
          onChanged: (_) {
            if (_confirmError != null) setState(() => _confirmError = null);
          },
        ),
        SizedBox(height: Responsive.h(context, 10)),
        _ResetRequirements(password: _passwordController.text),
        SizedBox(height: Responsive.h(context, 24)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _updatePassword,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    AppStrings.choose('Update Password', 'Cập nhật mật khẩu'),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ResetRequirements extends StatelessWidget {
  const _ResetRequirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        AppStrings.choose('At least 6 characters', 'Ít nhất 6 ký tự'),
        password.length >= 6,
      ),
      (
        AppStrings.choose(
          'Contains at least 1 uppercase letter',
          'Có ít nhất 1 chữ hoa',
        ),
        password.contains(RegExp('[A-Z]')),
      ),
      (
        AppStrings.choose('Contains at least 1 number', 'Có ít nhất 1 chữ số'),
        password.contains(RegExp(r'\d')),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.h(context, 1.5),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: item.$2
                        ? Container(
                            key: const ValueKey('valid'),
                            width: Responsive.w(context, 14),
                            height: Responsive.w(context, 14),
                            decoration: BoxDecoration(
                              color: context.finFlowColors.positiveAmount,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: Responsive.w(context, 10),
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            key: const ValueKey('invalid'),
                            width: Responsive.w(context, 14),
                            height: Responsive.w(context, 14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 1.2,
                                color: context.finFlowColors.secondaryText,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(width: Responsive.w(context, 7)),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: Responsive.sp(context, 13.5),
                        fontWeight: item.$2 ? FontWeight.w600 : FontWeight.w500,
                        color: item.$2
                            ? context.finFlowColors.primaryText
                            : context.finFlowColors.secondaryText,
                      ),
                      child: Text(item.$1),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
