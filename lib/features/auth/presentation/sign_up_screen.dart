import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;

    final nameError = name.isEmpty
        ? AppStrings.choose('Full name is required.', 'Vui lòng nhập họ tên.')
        : null;
    final emailError = email.isEmpty
        ? AppStrings.choose('Email is required.', 'Vui lòng nhập email.')
        : (!isValidAuthEmail(email)
              ? AppStrings.choose(
                  'Please enter a valid email address.',
                  'Vui lòng nhập địa chỉ email hợp lệ.',
                )
              : null);
    final passwordIsValid =
        password.length >= 6 &&
        password.contains(RegExp('[A-Z]')) &&
        password.contains(RegExp('[a-z]')) &&
        password.contains(RegExp(r'\d'));
    final passwordError = passwordIsValid
        ? null
        : AppStrings.choose(
            'Password does not meet all requirements.',
            'Mật khẩu chưa đáp ứng đầy đủ yêu cầu.',
          );
    final confirmationError = confirmation.isEmpty
        ? AppStrings.choose(
            'Please confirm your password.',
            'Vui lòng xác nhận mật khẩu.',
          )
        : (password != confirmation ? AppStrings.passwordsDoNotMatch : null);
    final termsError = _acceptedTerms
        ? null
        : AppStrings.choose(
            'Please accept the Terms of Service and Privacy Policy.',
            'Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách riêng tư.',
          );

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmationError;
      _termsError = termsError;
    });
    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmationError != null ||
        termsError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authServiceProvider)
          .sendOtpForSignUp(fullName: name, email: email, password: password);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.verification,
        arguments: {'email': email, 'fullName': name, 'password': password},
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _emailError = error.message.toString();
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('SignUp error: $error');
      setState(() {
        _isSubmitting = false;
        _emailError = AppStrings.choose(
          'Unable to create the account. Please try again.',
          'Không thể tạo tài khoản. Vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.choose('Sign Up', 'Đăng ký'),
      headerTitle: AppStrings.choose('Sign Up', 'Đăng ký'),
      showBackButton: true,
      showLogo: false,
      showCardTitle: false,
      footerOutsideCard: true,
      fillViewport: true,
      centerViewportContent: true,
      cardHorizontalPadding: 14,
      cardVerticalPadding: 16,
      cardRadius: 16,
      onBackPressed: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false),
      footer: TextButton(
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.signIn),
        child: Text(
          AppStrings.alreadyHaveAccount,
          style: TextStyle(
            fontSize: Responsive.sp(context, 15),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: [
        _LabeledField(
          label: AppStrings.choose('Full Name', 'Họ và tên'),
          controller: _nameController,
          hintText: AppStrings.choose('Enter your name', 'Nhập họ tên của bạn'),
          prefixIcon: Icons.person_outline,
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _LabeledField(
          label: AppStrings.email,
          controller: _emailController,
          hintText: AppStrings.choose('Enter your email', 'Nhập email của bạn'),
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _LabeledField(
          label: AppStrings.password,
          controller: _passwordController,
          obscureText: _obscurePassword,
          hintText: AppStrings.choose(
            'Enter your password',
            'Nhập mật khẩu của bạn',
          ),
          prefixIcon: Icons.lock_outline,
          onToggleVisibility: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          isObscured: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        _LabeledField(
          label: AppStrings.choose('Confirm Password', 'Xác nhận mật khẩu'),
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          hintText: AppStrings.choose(
            'Confirm your password',
            'Nhập lại mật khẩu của bạn',
          ),
          prefixIcon: Icons.lock_outline,
          onToggleVisibility: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
          isObscured: _obscureConfirmPassword,
          errorText: _confirmPasswordError,
          onChanged: (_) {
            if (_confirmPasswordError != null) {
              setState(() => _confirmPasswordError = null);
            }
          },
        ),
        SizedBox(height: Responsive.h(context, 10)),
        _PasswordRequirements(password: _passwordController.text),
        SizedBox(height: Responsive.h(context, 8)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: Responsive.w(context, 32),
              height: Responsive.w(context, 32),
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (value) => setState(() {
                  _acceptedTerms = value ?? false;
                  _termsError = null;
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                side: BorderSide(
                  width: 1.6,
                  color: context.finFlowColors.secondaryText,
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 6)),
            Expanded(
              child: Text(
                AppStrings.choose(
                  'I agree to the Terms of Service and Privacy Policy.',
                  'Tôi đồng ý với Điều khoản dịch vụ và Chính sách riêng tư.',
                ),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 13.5),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: context.finFlowColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
        if (_termsError != null) ...[
          SizedBox(height: Responsive.h(context, 4)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _termsError!,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 12.5),
                fontWeight: FontWeight.w500,
                color: context.finFlowColors.negativeAmount,
              ),
            ),
          ),
        ],
        SizedBox(height: Responsive.h(context, 18)),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            _isSubmitting
                ? AppStrings.creating
                : AppStrings.choose('Sign Up', 'Đăng ký'),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleVisibility,
    this.isObscured = false,
    this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final bool isObscured;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14.5),
            fontWeight: FontWeight.w700,
            color: context.finFlowColors.primaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 4)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 16),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            constraints: BoxConstraints(minHeight: Responsive.h(context, 52)),
            hintText: hintText,
            errorText: errorText,
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 12.5),
              fontWeight: FontWeight.w500,
              color: context.finFlowColors.negativeAmount,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: context.finFlowColors.negativeAmount,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: context.finFlowColors.negativeAmount,
                width: 1.5,
              ),
            ),
            hintStyle: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 16),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(prefixIcon, size: Responsive.w(context, 18)),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    icon: Icon(
                      isObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: Responsive.w(context, 18),
                    ),
                    onPressed: onToggleVisibility,
                  ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 12),
              vertical: Responsive.h(context, 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final checks = <({String label, bool valid})>[
      (
        label: AppStrings.choose('At least 6 characters', 'Ít nhất 6 ký tự'),
        valid: password.length >= 6,
      ),
      (
        label: AppStrings.choose(
          'One uppercase and one lowercase letter',
          'Có chữ hoa và chữ thường',
        ),
        valid:
            password.contains(RegExp('[A-Z]')) &&
            password.contains(RegExp('[a-z]')),
      ),
      (
        label: AppStrings.choose(
          'At least one number',
          'Có ít nhất một chữ số',
        ),
        valid: password.contains(RegExp(r'\d')),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: checks
          .map(
            (check) => Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.h(context, 1.5),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: check.valid
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
                        fontWeight: check.valid
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: check.valid
                            ? context.finFlowColors.primaryText
                            : context.finFlowColors.secondaryText,
                      ),
                      child: Text(check.label),
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
