import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/decorated_phone_scaffold.dart';
import '../providers/auth_provider.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.passwordTooShort)));
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.passwordsDoNotMatch)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authServiceProvider).updatePassword(newPassword: password);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Sign out to clear recovery session before navigating to sign-in
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.passwordResetSuccess)));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedPhoneScaffold(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: Responsive.w(context, 72),
                color: AppColors.emerald,
              ),
              SizedBox(height: Responsive.h(context, 24)),
              Text(
                AppStrings.newPassword,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: Responsive.h(context, 8)),
              Text(
                AppStrings.newPasswordDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              SizedBox(height: Responsive.h(context, 24)),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppStrings.newPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: Responsive.h(context, 12)),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppStrings.confirmNewPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: Responsive.h(context, 24)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: Responsive.h(context, 20),
                          width: Responsive.w(context, 20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(AppStrings.reset),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
