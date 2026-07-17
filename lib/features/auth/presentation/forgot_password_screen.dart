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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authServiceProvider).sendOtp(email: email);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.checkEmailToReset)),
      );

      // Navigate to Verification screen
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.verification,
        arguments: email,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.forgotPasswordTitle,
      footer: TextButton(
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.signIn),
        child: Text(AppStrings.backToSignIn),
      ),
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.w(context, 20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepEmerald.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: AppStrings.email),
              ),
              SizedBox(height: Responsive.h(context, 16)),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: Responsive.h(context, 20),
                        width: Responsive.w(context, 20),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.resetPassword),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
