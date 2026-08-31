import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'auth_shell.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Wait for the OAuth callback to be processed: Supabase fires an auth
  /// event when the deep-link session arrives, and AuthService fetches the
  /// profile and *then* notifies listeners. This method resolves when
  /// [AuthService.currentUser] becomes set, so navigation happens only after
  /// the profile is fully synced. Used on Android where
  /// [AuthService.signInWithGoogle] only opens the external browser and
  /// returns before the deep-link callback has completed.
  Future<bool> _waitForGoogleSession(AuthService authService) async {
    if (authService.currentUser != null) return true;

    final completer = Completer<bool>();
    void onAuthChanged() {
      if (!completer.isCompleted && authService.currentUser != null) {
        completer.complete(true);
      }
    }

    authService.addListener(onAuthChanged);
    onAuthChanged(); // handle the case where the session landed before we subscribed

    // Backstop: if no session/event arrives (e.g. the deep link is never
    // delivered), release the button rather than hanging forever.
    final timeout = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final result = await completer.future;
    timeout.cancel();
    authService.removeListener(onAuthChanged);
    return result;
  }

  /// Navigate to the correct destination after a successful sign-in.
  /// Must be called after [AuthService] has a [currentUser].
  void _navigateAfterSignIn() {
    final authService = ref.read(authServiceProvider);
    String destination;
    if (authService.needsBudgetSetup) {
      destination = AppRoutes.walletOnboarding;
    } else {
      destination = AppRoutes.dashboard;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  Future<void> _handleGoogleSignIn() async {
    final authService = ref.read(authServiceProvider);
    setState(() => _isSubmitting = true);
    try {
      await authService.signInWithGoogle();
      final ok = await _waitForGoogleSession(authService);
      if (!mounted) return;
      if (ok) _navigateAfterSignIn();
    } catch (e) {
      debugPrint('Google sign-in error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.choose('Log In', 'Đăng nhập'),
      headerTitle: AppStrings.choose('Log In', 'Đăng nhập'),
      showBackButton: true,
      showLogo: false,
      showCardTitle: false,
      footerOutsideCard: true,
      fillViewport: true,
      onBackPressed: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false),
      cardHorizontalPadding: 14,
      cardVerticalPadding: 16,
      cardRadius: 16,
      topContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.choose(
                'Welcome back to FinFlow',
                'Chào mừng bạn quay lại FinFlow',
              ),
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 17),
                fontWeight: FontWeight.w500,
                color: context.finFlowColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
      footer: Padding(
        padding: EdgeInsets.only(bottom: Responsive.h(context, 10)),
        child: TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.signUp),
          child: Text(
            AppStrings.newToFinflowSignUp,
            style: TextStyle(
              fontSize: Responsive.sp(context, 15),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      children: [
        AuthField(
          label: AppStrings.email,
          controller: _emailController,
          icon: Icons.mail_outline,
          hintText: AppStrings.choose('Enter your email', 'Nhập email của bạn'),
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        SizedBox(height: Responsive.h(context, 12)),
        AuthField(
          label: AppStrings.password,
          controller: _passwordController,
          icon: Icons.lock_outline,
          hintText: AppStrings.choose('Enter your password', 'Nhập mật khẩu'),
          obscureText: _obscurePassword,
          onToggleVisibility: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          isObscured: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
        ),
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) =>
                  setState(() => _rememberMe = value ?? false),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                AppStrings.choose('Remember me', 'Ghi nhớ tôi'),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 14),
                  fontWeight: FontWeight.w500,
                  color: context.finFlowColors.secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
              child: Text(
                AppStrings.forgotPassword,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(context, 6)),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final email = _emailController.text.trim().toLowerCase();
                  final password = _passwordController.text;
                  final emailError = email.isEmpty
                      ? AppStrings.choose(
                          'Email is required.',
                          'Vui lòng nhập email.',
                        )
                      : (!isValidAuthEmail(email)
                            ? AppStrings.choose(
                                'Please enter a valid email address.',
                                'Vui lòng nhập địa chỉ email hợp lệ.',
                              )
                            : null);
                  final passwordError = password.isEmpty
                      ? AppStrings.choose(
                          'Password is required.',
                          'Vui lòng nhập mật khẩu.',
                        )
                      : null;
                  setState(() {
                    _emailError = emailError;
                    _passwordError = passwordError;
                  });
                  if (emailError != null || passwordError != null) return;

                  setState(() => _isSubmitting = true);
                  try {
                    final success = await ref
                        .read(authServiceProvider)
                        .signIn(email: email, password: password);
                    if (!context.mounted) return;
                    if (success) {
                      _navigateAfterSignIn();
                    } else {
                      setState(() {
                        _isSubmitting = false;
                        _passwordError = AppStrings.invalidEmailOrPassword;
                      });
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() {
                      _isSubmitting = false;
                      _passwordError = AppStrings.choose(
                        'Unable to log in. Please try again.',
                        'Không thể đăng nhập. Vui lòng thử lại.',
                      );
                    });
                  }
                },
          child: Text(
            _isSubmitting ? AppStrings.signingIn : AppStrings.signIn,
            style: TextStyle(
              fontSize: Responsive.sp(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        Row(
          children: [
            Expanded(child: Divider(color: context.finFlowColors.divider)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 12),
              ),
              child: Text(
                AppStrings.orContinueWith,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w500,
                  color: context.finFlowColors.secondaryText,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.finFlowColors.divider)),
          ],
        ),
        SizedBox(height: Responsive.h(context, 18)),
        SizedBox(
          width: double.infinity,
          height: Responsive.h(context, 52),
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(Responsive.h(context, 52)),
              backgroundColor: context.finFlowColors.surface,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? context.finFlowColors.primaryText
                  : AppColors.deepEmerald,
              side: BorderSide(color: context.finFlowColors.inputBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: SvgPicture.asset(
              'assets/icons/icon-google.svg',
              width: Responsive.w(context, 22),
              height: Responsive.w(context, 22),
            ),
            label: Text(
              AppStrings.choose('Continue with Google', 'Tiếp tục với Google'),
              style: TextStyle(
                fontSize: Responsive.sp(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
