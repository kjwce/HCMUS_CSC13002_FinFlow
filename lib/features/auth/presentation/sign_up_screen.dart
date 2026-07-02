import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.signUp,
      footer: TextButton(
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.signIn),
        child: Text(AppStrings.alreadyHaveAccount),
      ),
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: AppStrings.fullName),
        ),
        SizedBox(height: Responsive.h(context, 12)),
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
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 12)),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: AppStrings.confirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);

                  final password = _passwordController.text;
                  final confirmPassword = _confirmPasswordController.text;

                  if (password.length < 6) {
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.passwordTooShort)),
                    );
                    return;
                  }

                  if (password != confirmPassword) {
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppStrings.passwordsDoNotMatch),
                      ),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(authServiceProvider)
                        .sendOtpForSignUp(
                          fullName: _nameController.text,
                          email: _emailController.text,
                          password: password,
                        );
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    Navigator.of(context).pushReplacementNamed(
                      AppRoutes.verification,
                      arguments: {
                        'email': _emailController.text.trim().toLowerCase(),
                        'fullName': _nameController.text.trim().isEmpty
                            ? 'New FinFlow User'
                            : _nameController.text.trim(),
                        'password': password,
                      },
                    );
                  } on ArgumentError catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isSubmitting = false);
                    debugPrint('SignUp error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${AppStrings.registrationFailed}: $e'),
                      ),
                    );
                  }
                },
          child: Text(
            _isSubmitting ? AppStrings.creating : AppStrings.createAccount,
          ),
        ),
      ],
    );
  }
}
