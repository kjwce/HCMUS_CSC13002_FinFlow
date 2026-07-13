import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
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
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 28),
                vertical: Responsive.h(context, 24),
              ),
              // Rebuild text + children when language changes, but the scaffold,
              // corner blobs, and language switcher stay stable.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Static portion — never rebuilds on language change.
                  const RepaintBoundary(child: FinFlowLogo(size: 54)),
                  SizedBox(height: Responsive.h(context, 28)),
                  // Dynamic portion — rebuilds only when language changes
                  // so AppStrings reflect the new locale.
                  ListenableBuilder(
                    listenable: AppLanguage.instance,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: context.finFlowColors.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: Responsive.h(context, 18)),
                        ...children,
                        if (footer != null) ...[
                          SizedBox(height: Responsive.h(context, 18)),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: Responsive.h(context, 60),
          right: Responsive.w(context, 12),
          child: const LanguageSwitcherFab(),
        ),
      ],
    );
  }
}
