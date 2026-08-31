import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  var _isSubmitting = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(
        () => _emailError = AppStrings.choose(
          'Email is required.',
          'Vui lòng nhập email.',
        ),
      );
      return;
    }
    if (!isValidAuthEmail(email)) {
      setState(
        () => _emailError = AppStrings.choose(
          'Please enter a valid email address.',
          'Vui lòng nhập địa chỉ email hợp lệ.',
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _emailError = null;
    });
    try {
      await ref.read(authServiceProvider).resetPassword(email: email);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.checkEmailToReset)));

      // Navigate to Verification screen
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.verification, arguments: email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _emailError = AppStrings.choose(
          'Unable to send the reset code. Check this email and try again.',
          'Không thể gửi mã đặt lại. Hãy kiểm tra email và thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.forgotPasswordTitle,
      headerTitle: AppStrings.forgotPasswordTitle,
      showBackButton: true,
      showLogo: false,
      showCardTitle: false,
      footerOutsideCard: true,
      cardHorizontalPadding: 14,
      cardVerticalPadding: 16,
      cardRadius: 12,
      subtitle: AppStrings.enterEmailToReset,
      footer: TextButton(
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.signIn),
        child: Text(
          AppStrings.backToSignIn,
          style: TextStyle(
            fontSize: Responsive.sp(context, 15),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: [
        Container(
          width: Responsive.w(context, 68),
          height: Responsive.w(context, 68),
          decoration: BoxDecoration(
            color: context.finFlowColors.inputBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.key_outlined,
            size: Responsive.w(context, 34),
            color: authTitleColor(context),
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        Text(
          AppStrings.choose('Reset your password', 'Đặt lại mật khẩu'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 18),
            fontWeight: FontWeight.w700,
            color: context.finFlowColors.primaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 6)),
        Text(
          AppStrings.choose(
            'Enter your registered email address and we’ll send you instructions to reset your password.',
            'Nhập email đã đăng ký để nhận hướng dẫn đặt lại mật khẩu.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 15),
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: context.finFlowColors.secondaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        AuthField(
          label: AppStrings.email,
          hintText: 'nguyenvana@example.com',
          controller: _emailController,
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        SizedBox(height: Responsive.h(context, 16)),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _sendOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepEmerald,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? SizedBox(
                  height: Responsive.h(context, 20),
                  width: Responsive.w(context, 20),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  AppStrings.resetPassword,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
