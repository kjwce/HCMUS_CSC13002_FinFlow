import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return AuthShell(
          title: AppStrings.signIn,
          footer: Column(
            children: [
              Text(AppStrings.orContinueWith),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(
                    iconWidget: Padding(
                      padding: const EdgeInsets.all(7),
                      child: SvgPicture.asset(
                        'assets/icons/icon-google.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                    onTap: () async {
                      setState(() => _isSubmitting = true);
                      await ref.read(authServiceProvider).signInWithGoogle();
                      if (!context.mounted) return;
                      setState(() => _isSubmitting = false);
                    },
                  ),
                  const SizedBox(width: 12),
                  _SocialButton(icon: Icons.facebook, onTap: () async {
                    setState(() => _isSubmitting = true);
                    await ref.read(authServiceProvider).signInWithFacebook();
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                  }),
                  const SizedBox(width: 12),
                  _SocialButton(icon: Icons.apple, onTap: () async {
                    setState(() => _isSubmitting = true);
                    await ref.read(authServiceProvider).signInWithApple();
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                  }),
                ],
              ),
              const SizedBox(height: 18),
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
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: AppStrings.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                        setState(() => _isSubmitting = false);

                        if (success) {
                          // Check if user needs to set budget limit
                          final authService = ref.read(authServiceProvider);
                          final destination = authService.needsBudgetSetup
                              ? AppRoutes.budgetSetup
                              : AppRoutes.dashboard;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            destination,
                            (route) => false,
                          );
                        } else {
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
      },
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
        height: 44,
        width: 44,
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
