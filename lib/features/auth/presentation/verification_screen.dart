import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/decorated_phone_scaffold.dart';
import '../providers/auth_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _codeController = TextEditingController();
  var _isSubmitting = false;
  var _isResending = false;
  var _secondsRemaining = 60;
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
          fullName: _fullName ?? 'New FinFlow User',
          email: email,
          password: _password!,
        );
      } else {
        await authService.sendOtp(email: email);
      }
      _startCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.otpSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend code: $e')),
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
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _email;
    final code = _codeController.text.trim();
    if (code.length != 8 || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the 8-digit code')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    if (_isSignUpFlow) {
      // -- SIGN UP FLOW --
      final success = await ref
          .read(authServiceProvider)
          .completeRegistration(
            email: email,
            token: code,
            password: _password!,
            fullName: _fullName ?? 'New FinFlow User',
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.otpVerified)),
        );
        // New user → go to budget setup first
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.budgetSetup,
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.invalidOtp)),
        );
      }
    } else {
      // -- FORGOT PASSWORD FLOW --
      final success = await ref
          .read(authServiceProvider)
          .verifyOtp(
            email: email,
            token: code,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.newPassword,
          arguments: email,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.invalidOtp)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedPhoneScaffold(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // finFlow logo
              Text(
                'FinFlow',
                style: TextStyle(
                  fontSize: Responsive.sp(context, 36),
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 9, 82, 37),
                ),
              ),
              SizedBox(height: Responsive.h(context, 72)),

              // White card
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 24),
                  vertical: Responsive.h(context, 32),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'Verification Code',
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 22),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 8)),

                    // Description
                    Text(
                      'A verification code has been sent to your mail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 13),
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 24)),

                    // Single input field for the code
                    Container(
                      width: double.infinity,
                      height: Responsive.h(context, 50),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 20),
                          fontWeight: FontWeight.w700,
                          letterSpacing: Responsive.w(context, 8),
                        ),
                        decoration: InputDecoration(
                          hintText: '--------',
                          hintStyle: TextStyle(
                            fontSize: Responsive.sp(context, 20),
                            letterSpacing: Responsive.w(context, 8),
                            color: Color(0xFFBFC9C3),
                          ),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(vertical: Responsive.h(context, 14)),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 12)),

                    // Change Email link
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Change email feature coming soon'),
                          ),
                        );
                      },
                      child: Text(
                        'Change Email',
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 13),
                          color: const Color(0xFF0068FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(context, 4)),

                    // Resend code button with countdown
                    SizedBox(
                      height: Responsive.h(context, 44),
                      child: _isResending
                          ? Center(
                              child: SizedBox(
                                height: Responsive.h(context, 20),
                                width: Responsive.w(context, 20),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap:
                                  _secondsRemaining > 0 ? null : _handleResend,
                              child: Center(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _secondsRemaining > 0
                                            ? 'Resend in '
                                            : 'Resend code',
                                        style: TextStyle(
                                          fontSize: Responsive.sp(context, 13),
                                          color: _secondsRemaining > 0
                                              ? AppColors.muted
                                              : const Color(0xFF0068FF),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_secondsRemaining > 0)
                                        TextSpan(
                                          text: '$_secondsRemaining\'s',
                                          style: TextStyle(
                                            fontSize: Responsive.sp(context, 13),
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: Responsive.h(context, 16)),

                    // Button: "Reset Password" or "Next" depending on flow
                    SizedBox(
                      width: Responsive.w(context, 200),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: const Color(0xFF093030),
                          minimumSize: Size(
                            double.infinity,
                            Responsive.h(context, 44),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: Responsive.h(context, 20),
                                width: Responsive.w(context, 20),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF093030),
                                ),
                              )
                            : Text(
                                _isSignUpFlow ? 'Next' : 'Reset Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: Responsive.sp(context, 15),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: Responsive.h(context, 24)),

              // Already a member / Sign in
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already a member?',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: Responsive.sp(context, 14),
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 4)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.signIn,
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        color: AppColors.blueAccent,
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
