import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _codeController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  var _isSubmitting = false;
  var _isResending = false;
  var _secondsRemaining = 60;
  String? _verificationError;
  Timer? _timer;

  String? _email;
  String? _fullName;
  String? _password;

  /// true = sign-up flow, false = forgot-password flow
  bool get _isSignUpFlow => _password != null && _password!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
      }
      if (mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _handleResend() async {
    final email = _email;
    if (email == null || email.isEmpty) return;

    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      if (_isSignUpFlow) {
        await authService.sendOtpForSignUp(
          fullName:
              _fullName ??
              AppStrings.choose('New FinFlow User', 'Người dùng FinFlow mới'),
          email: email,
          password: _password!,
        );
      } else {
        await authService.resetPassword(email: email);
      }
      _startCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.otpSent)));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _verificationError = AppStrings.choose(
          'Unable to resend the code. Please try again.',
          'Không thể gửi lại mã. Vui lòng thử lại.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract arguments before first build so _isSignUpFlow works correctly.
    if (_email != null) return; // Already extracted
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _email = args['email'] as String?;
      _fullName = args['fullName'] as String?;
      _password = args['password'] as String?;
    } else if (args is String) {
      _email = args;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleOtpChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      for (
        var offset = 0;
        offset < digits.length && index + offset < 6;
        offset++
      ) {
        _otpControllers[index + offset].value = TextEditingValue(
          text: digits[offset],
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      final next = (index + digits.length).clamp(0, 5).toInt();
      _otpFocusNodes[next].requestFocus();
    } else if (digits.isEmpty) {
      _otpControllers[index].clear();
      if (index > 0) _otpFocusNodes[index - 1].requestFocus();
    } else {
      _otpControllers[index].value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      if (index < 5) _otpFocusNodes[index + 1].requestFocus();
    }
    _codeController.text = _otpControllers.map((item) => item.text).join();
    if (_verificationError != null) setState(() => _verificationError = null);
  }

  KeyEventResult _handleOtpKeyEvent(int index, KeyEvent event) {
    // After entering a digit, focus moves to the next (empty) box.  Backspace
    // on that box does not change its text, so TextField.onChanged is never
    // called. Handle it here to remove the previous digit in one press.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      return _deletePreviousOtp(index)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _deletePreviousOtp(int index) {
    if (index <= 0 ||
        _otpControllers[index].text.isNotEmpty ||
        _otpControllers[index - 1].text.isEmpty) {
      return false;
    }
    _otpControllers[index - 1].clear();
    _codeController.text = _otpControllers.map((item) => item.text).join();
    _otpFocusNodes[index - 1].requestFocus();
    if (_verificationError != null) setState(() => _verificationError = null);
    return true;
  }

  Future<void> _handleSubmit() async {
    final email = _email;
    final code = _codeController.text.trim();
    if (code.length != 6 || email == null || email.isEmpty) {
      setState(() {
        _verificationError = AppStrings.choose(
          'Please enter the 6-digit code',
          'Vui lòng nhập mã 6 chữ số',
        );
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _verificationError = null;
    });

    if (_isSignUpFlow) {
      // -- SIGN UP FLOW --
      final success = await ref
          .read(authServiceProvider)
          .completeRegistration(
            email: email,
            token: code,
            password: _password!,
            fullName:
                _fullName ??
                AppStrings.choose('New FinFlow User', 'Người dùng FinFlow mới'),
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.otpVerified)));
        // New user → go to wallet onboarding first, then budget setup
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.walletOnboarding, (route) => false);
      } else {
        setState(() => _verificationError = AppStrings.invalidOtp);
      }
    } else {
      // -- FORGOT PASSWORD FLOW --
      final success = await ref
          .read(authServiceProvider)
          .verifyPasswordRecoveryOtp(email: email, token: code);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.newPassword, arguments: email);
      } else {
        setState(() => _verificationError = AppStrings.invalidOtp);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.verifyEmail,
      headerTitle: AppStrings.verifyEmail,
      showBackButton: true,
      showLogo: false,
      showCardTitle: false,
      footerOutsideCard: true,
      showCard: false,
      cardHorizontalPadding: 0,
      cardVerticalPadding: 0,
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
        Container(
          width: Responsive.w(context, 68),
          height: Responsive.w(context, 68),
          decoration: BoxDecoration(
            color: context.finFlowColors.inputBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mail_outline,
            size: Responsive.w(context, 34),
            color: authTitleColor(context),
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        Text(
          AppStrings.choose('Verify Your Email', 'Xác thực email'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: Responsive.sp(context, 24),
            fontWeight: FontWeight.w700,
            color: context.finFlowColors.primaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 6)),
        Text(
          AppStrings.choose(
            'We sent a verification code to\n${_email ?? ''}',
            'Mã xác thực đã được gửi đến\n${_email ?? ''}',
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
        SizedBox(height: Responsive.h(context, 16)),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.w(context, 320)),
            child: Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 3),
                    ),
                    child: AspectRatio(
                      aspectRatio: 0.9,
                      child: Focus(
                        onKeyEvent: (node, event) =>
                            _handleOtpKeyEvent(index, event),
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          // Keep the field visually one digit wide while allowing a
                          // six-digit clipboard paste to reach _handleOtpChanged.
                          maxLength: 1,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          inputFormatters: [
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              // Some soft keyboards report Backspace on an
                              // empty field as an empty-to-empty edit instead
                              // of a key event.
                              if (oldValue.text.isEmpty &&
                                  newValue.text.isEmpty) {
                                _deletePreviousOtp(index);
                              }
                              return newValue;
                            }),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) => _handleOtpChanged(index, value),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: Responsive.sp(context, 22),
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _verificationError != null
                                    ? Colors.redAccent
                                    : context.finFlowColors.inputBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _verificationError != null
                                    ? Colors.redAccent
                                    : context.finFlowColors.positiveAmount,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_verificationError != null) ...[
          SizedBox(height: Responsive.h(context, 6)),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: Responsive.w(context, 14),
                  color: Colors.redAccent,
                ),
                SizedBox(width: Responsive.w(context, 4)),
                Expanded(
                  child: Text(
                    _verificationError!,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 13.5),
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: Responsive.h(context, 18)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isSignUpFlow
                        ? AppStrings.choose('Continue', 'Tiếp tục')
                        : AppStrings.verify,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 10)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed(AppRoutes.signUp),
            child: Text(
              AppStrings.choose('Change email address', 'Đổi email'),
              style: TextStyle(
                fontSize: Responsive.sp(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 16)),
        if (_isResending)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(
            onPressed: _secondsRemaining > 0 ? null : _handleResend,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 14),
                  fontWeight: FontWeight.w500,
                  color: context.finFlowColors.secondaryText,
                ),
                children: [
                  TextSpan(
                    text: AppStrings.choose(
                      "Didn't receive the code? ",
                      'Chưa nhận được mã? ',
                    ),
                  ),
                  TextSpan(
                    text: AppStrings.resendCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _secondsRemaining > 0
                          ? context.finFlowColors.secondaryText
                          : context.finFlowColors.positiveAmount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_secondsRemaining > 0)
          Text(
            AppStrings.choose(
              'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
              'Gửi lại mã sau 00:${_secondsRemaining.toString().padLeft(2, '0')}',
            ),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 13.5),
              fontWeight: FontWeight.w500,
              color: context.finFlowColors.secondaryText,
            ),
          ),
      ],
    );
  }
}
