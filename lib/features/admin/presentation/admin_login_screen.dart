import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_moderation_service.dart';
import 'admin_preferences_controls.dart';
import 'admin_strings.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.service,
    required this.onSignedIn,
  });

  final AdminModerationService service;
  final VoidCallback onSignedIn;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    var stage = AdminStrings.t(
      'authenticating the account',
      'xác thực tài khoản',
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final allowed = await widget.service.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (allowed) {
        stage = AdminStrings.t(
          'opening the admin console',
          'mở trang quản trị',
        );
        widget.onSignedIn();
      } else {
        setState(
          () => _error = AdminStrings.t(
            'This account does not have admin access.',
            'Tài khoản này không có quyền quản trị.',
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${AdminStrings.t('Signed in, but the admin permission check failed', 'Đăng nhập thành công nhưng kiểm tra quyền admin thất bại')}: '
              '${error.message} (${error.code ?? AdminStrings.t('no error code', 'không có mã lỗi')}).',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Admin sign-in failed during $stage: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => _error =
              '${AdminStrings.t('Error while', 'Lỗi khi')} $stage: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _authErrorMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => AdminStrings.t(
        'Supabase rejected the sign-in: the email or password does not match (invalid_credentials).',
        'Supabase từ chối thông tin đăng nhập: email hoặc mật khẩu không khớp (invalid_credentials).',
      ),
      'email_not_confirmed' => AdminStrings.t(
        'The email is not confirmed in Supabase (email_not_confirmed).',
        'Email chưa được xác nhận trong Supabase (email_not_confirmed).',
      ),
      'email_provider_disabled' => AdminStrings.t(
        'Email sign-in is disabled in Supabase (email_provider_disabled).',
        'Đăng nhập bằng email đang bị tắt trong Supabase (email_provider_disabled).',
      ),
      'user_banned' => AdminStrings.t(
        'This account is banned in Supabase (user_banned).',
        'Tài khoản đang bị khóa trong Supabase (user_banned).',
      ),
      _ => '${error.message} (${error.code ?? 'auth_error'}).',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (MediaQuery.sizeOf(context).width >= 900)
                const Expanded(flex: 5, child: _LoginBrandPanel()),
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Logo(),
                            const SizedBox(height: 42),
                            Text(
                              AdminStrings.t(
                                'Admin sign in',
                                'Đăng nhập quản trị',
                              ),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AdminStrings.t(
                                'Only authorized FinFlow admin accounts can access this console.',
                                'Chỉ tài khoản quản trị FinFlow đã được cấp quyền mới có thể truy cập.',
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 30),
                            TextFormField(
                              controller: _emailController,
                              autofocus: true,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: AdminStrings.t(
                                  'Admin email',
                                  'Email quản trị',
                                ),
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                  ? AdminStrings.t(
                                      'Enter a valid email',
                                      'Nhập email hợp lệ',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: AdminStrings.t(
                                  'Password',
                                  'Mật khẩu',
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? AdminStrings.t(
                                      'Enter your password',
                                      'Nhập mật khẩu',
                                    )
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFECEA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFB42318),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(_error!)),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                _submitting
                                    ? AdminStrings.t(
                                        'Authenticating...',
                                        'Đang xác thực...',
                                      )
                                    : AdminStrings.t('Sign in', 'Đăng nhập'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 17,
                                  color: Color(0xFF80928C),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  AdminStrings.t(
                                    'Sign-in is secured by Supabase',
                                    'Phiên đăng nhập được bảo vệ bởi Supabase',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF80928C),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            top: 18,
            right: 22,
            child: AdminPreferencesControls(),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(58),
      decoration: BoxDecoration(
        color: const Color(0xFF0E4D3C),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(light: true),
          const Spacer(),
          const Icon(Icons.forum_outlined, color: Color(0xFFA8E6C8), size: 68),
          const SizedBox(height: 28),
          Text(
            AdminStrings.t(
              'Keep the FinFlow community\nsafe and useful.',
              'Giữ cộng đồng FinFlow\nan toàn và hữu ích.',
            ),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AdminStrings.t(
              'Review content, handle reports, and manage post quality in one place.',
              'Xem xét nội dung, xử lý báo cáo và kiểm soát chất lượng bài đăng tại một nơi.',
            ),
            style: const TextStyle(
              color: Color(0xFFC6DDD6),
              fontSize: 17,
              height: 1.6,
            ),
          ),
          const Spacer(),
          const Text(
            'FINFLOW • COMMUNITY OPERATIONS',
            style: TextStyle(
              color: Color(0xFF8EB9AA),
              letterSpacing: 1.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: light ? Colors.white : const Color(0xFF0B6B4F),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.show_chart_rounded,
            color: light ? const Color(0xFF0B6B4F) : Colors.white,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'FinFlow',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: light
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: light ? Colors.white12 : const Color(0xFFE4F2EC),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'ADMIN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: light ? Colors.white : const Color(0xFF0B6B4F),
            ),
          ),
        ),
      ],
    );
  }
}
