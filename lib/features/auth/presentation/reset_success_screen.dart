import 'package:flutter/material.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'auth_shell.dart';

/// Confirmation shown after a recovery password has been saved successfully.
class ResetSuccessScreen extends StatelessWidget {
  const ResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AppStrings.choose('Password Updated', 'Đã cập nhật mật khẩu'),
      headerTitle: AppStrings.choose('Authentication', 'Xác thực'),
      showBackButton: true,
      showLogo: false,
      showCardTitle: true,
      cardHorizontalPadding: 18,
      cardVerticalPadding: 18,
      cardRadius: 12,
      children: [
        Container(
          width: Responsive.w(context, 76),
          height: Responsive.w(context, 76),
          decoration: BoxDecoration(
            color: context.finFlowColors.inputBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: Responsive.w(context, 44),
            color: context.finFlowColors.positiveAmount,
          ),
        ),
        SizedBox(height: Responsive.h(context, 24)),
        Text(
          AppStrings.choose(
            'Your password has been successfully updated. You can now sign in with your new password.',
            'Mật khẩu đã được cập nhật thành công. Bạn có thể đăng nhập bằng mật khẩu mới.',
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.signIn, (route) => false),
            child: Text(
              AppStrings.choose('Log In Now', 'Đăng nhập ngay'),
              style: TextStyle(
                fontSize: Responsive.sp(context, 16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
