import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/decorated_phone_scaffold.dart';
import '../../../core/widgets/finflow_logo.dart';
import '../../../core/widgets/language_switcher.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedPhoneScaffold(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FinFlowLogo(size: 54),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...children,
                  if (footer != null) ...[const SizedBox(height: 18), footer!],
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 60,
          right: 12,
          child: LanguageSwitcherFab(),
        ),
      ],
    );
  }
}
