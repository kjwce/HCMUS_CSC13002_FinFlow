import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    Navigator.of(context).pushNamedAndRemoveUntil(
      destination,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.signIn,
      footer: Column(
        children: [
          Text(AppStrings.orContinueWith),
          SizedBox(height: Responsive.h(context, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(
                iconWidget: Padding(
                  padding: EdgeInsets.all(Responsive.w(context, 7)),
                  child: SvgPicture.asset(
                    'assets/icons/icon-google.svg',
                    width: Responsive.w(context, 24),
                    height: Responsive.h(context, 24),
                  ),
                ),
                onTap: () async {
                  setState(() => _isSubmitting = true);
                  try {
                    final ok =
                        await ref.read(authServiceProvider).signInWithGoogle();
                    if (!context.mounted) return;
                    if (ok) {
                      _navigateAfterSignIn();
                    }
                  } catch (e) {
                    debugPrint('Google sign-in error: $e');
                  }
                  if (!context.mounted) return;
                  setState(() => _isSubmitting = false);
                },
              ),
              SizedBox(width: Responsive.w(context, 12)),
              _SocialButton(icon: Icons.facebook, onTap: () async {
                setState(() => _isSubmitting = true);
                try {
                  final ok =
                      await ref.read(authServiceProvider).signInWithFacebook();
                  if (!context.mounted) return;
                  if (ok) {
                    _navigateAfterSignIn();
                  }
                } catch (e) {
                  debugPrint('Facebook sign-in error: $e');
                }
                if (!context.mounted) return;
                setState(() => _isSubmitting = false);
              }),
              SizedBox(width: Responsive.w(context, 12)),
              _SocialButton(icon: Icons.apple, onTap: () async {
                setState(() => _isSubmitting = true);
                try {
                  final ok =
                      await ref.read(authServiceProvider).signInWithApple();
                  if (!context.mounted) return;
                  if (ok) {
                    _navigateAfterSignIn();
                  }
                } catch (e) {
                  debugPrint('Apple sign-in error: $e');
                }
                if (!context.mounted) return;
                setState(() => _isSubmitting = false);
              }),
            ],
          ),
          SizedBox(height: Responsive.h(context, 18)),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed(AppRoutes.signUp),
            child: Text(AppStrings.newToFinflowSignUp),
          ),
        ],
      ),
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: AppStrings.email),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: AppStrings.password,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
            child: Text(AppStrings.forgotPassword),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);

                  try {
                    final success = await ref
                        .read(authServiceProvider)
                        .signIn(
                          email: _emailController.text.trim().toLowerCase(),
                          password: _passwordController.text,
                        );
                    if (!context.mounted) return;

                    if (success) {
                      // Profile is already loaded inside signIn(), so
                      // currentUser is ready — navigate immediately.
                      // No setState needed: we are navigating away.
                      _navigateAfterSignIn();
                    } else {
                      setState(() => _isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppStrings.invalidEmailOrPassword),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
          child: Text(_isSubmitting ? AppStrings.signingIn : AppStrings.signIn),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({this.icon, this.iconWidget, required this.onTap});

  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: Responsive.w(context, 44),
        width: Responsive.w(context, 44),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sage),
        ),
        child: iconWidget ?? Icon(icon, color: AppColors.deepEmerald),
      ),
    );
  }
}
