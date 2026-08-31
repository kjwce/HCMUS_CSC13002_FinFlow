import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/decorated_phone_scaffold.dart';
import '../../../core/widgets/finflow_logo.dart';
import '../../../core/widgets/home_header_controls.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.children,
    this.footer,
    this.subtitle,
    this.showLogo = true,
    this.showCardTitle = true,
    this.showBackButton = false,
    this.headerTitle,
    this.footerOutsideCard = false,
    this.cardHorizontalPadding = 24,
    this.cardVerticalPadding = 26,
    this.onBackPressed,
    this.topContent,
    this.showCard = true,
    this.cardRadius = 24,
    this.fillViewport = false,
    this.centerViewportContent = false,
    this.pinFooterToBottom = false,
    this.headerTitleFontSize = 22,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;
  final String? subtitle;
  final bool showLogo;
  final bool showCardTitle;
  final bool showBackButton;
  final String? headerTitle;
  final bool footerOutsideCard;
  final double cardHorizontalPadding;
  final double cardVerticalPadding;
  final VoidCallback? onBackPressed;
  final Widget? topContent;
  final bool showCard;
  final double cardRadius;
  final bool fillViewport;
  final bool centerViewportContent;
  final bool pinFooterToBottom;
  final double headerTitleFontSize;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final authTheme = baseTheme.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(Responsive.h(context, 52)),
          backgroundColor: AppColors.deepEmerald,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.deepEmerald.withValues(
            alpha: 0.55,
          ),
          disabledForegroundColor: Colors.white70,
          elevation: 1,
          shadowColor: AppColors.deepEmerald.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    // The header controls sit above the scaffold in this shared shell.  Keep a
    // transparent Material ancestor here so InkWell can render its ripple in
    // both the real app and minimal widget-test harnesses.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: authTheme,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14),
            color: context.finFlowColors.primaryText,
          ),
          child: Stack(
            children: [
              DecoratedPhoneScaffold(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final verticalPadding = Responsive.h(context, 8);
                    final minimumHeight =
                        viewport.maxHeight - (verticalPadding * 2);

                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(context, 20),
                        vertical: verticalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: fillViewport ? minimumHeight : 0,
                        ),
                        child: IntrinsicHeight(
                          child: ListenableBuilder(
                            listenable: AppLanguage.instance,
                            builder: (context, _) => Column(
                              mainAxisSize: fillViewport
                                  ? MainAxisSize.max
                                  : MainAxisSize.min,
                              children: [
                                if (headerTitle != null || showBackButton)
                                  _buildHeader(context),
                                if (centerViewportContent) const Spacer(),
                                if (showLogo) ...[
                                  const RepaintBoundary(
                                    child: FinFlowLogo(size: 54),
                                  ),
                                  SizedBox(height: Responsive.h(context, 20)),
                                ],
                                if (topContent != null) ...[
                                  topContent!,
                                  SizedBox(height: Responsive.h(context, 14)),
                                ],
                                _buildCard(context),
                                if (footer != null && footerOutsideCard) ...[
                                  if (pinFooterToBottom)
                                    const Spacer()
                                  else
                                    SizedBox(height: Responsive.h(context, 18)),
                                  footer!,
                                ],
                                if (centerViewportContent) const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                // AuthShell's controls are siblings of DecoratedPhoneScaffold,
                // so explicitly account for the system status bar/notch here.
                top:
                    MediaQuery.paddingOf(context).top +
                    Responsive.h(context, 8),
                right: Responsive.w(context, 16),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HomeLanguageSelector(),
                    SizedBox(width: 8),
                    HomeThemeToggle(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: Responsive.h(context, 52),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed:
                  onBackPressed ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                headerTitle ?? title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: authTitleColor(context),
                  fontFamily: 'Manrope',
                  fontSize: Responsive.sp(context, headerTitleFontSize),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: Responsive.w(context, 420)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, cardHorizontalPadding),
        vertical: Responsive.h(context, cardVerticalPadding),
      ),
      decoration: showCard
          ? BoxDecoration(
              color: context.finFlowColors.surface,
              borderRadius: BorderRadius.circular(
                Responsive.w(context, cardRadius),
              ),
              border: Border.all(color: context.finFlowColors.divider),
              boxShadow: [
                BoxShadow(
                  color: context.finFlowColors.primaryText.withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCardTitle)
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: authTitleColor(context),
                fontFamily: 'Manrope',
                fontSize: Responsive.sp(context, 24),
                fontWeight: FontWeight.w800,
              ),
            ),
          if (subtitle != null) ...[
            SizedBox(height: Responsive.h(context, 8)),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Hanken Grotesk',
                fontSize: Responsive.sp(context, 16),
                fontWeight: FontWeight.w500,
                color: context.finFlowColors.secondaryText,
              ),
            ),
          ],
          if (showCardTitle || subtitle != null)
            SizedBox(height: Responsive.h(context, 20)),
          ...children,
          if (footer != null && !footerOutsideCard) ...[
            SizedBox(height: Responsive.h(context, 18)),
            footer!,
          ],
        ],
      ),
    );
  }
}

Color authTitleColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.finFlowColors.primaryText
      : AppColors.deepEmerald;
}

/// Stitch-style field with a compact label above the outlined input.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onToggleVisibility,
    this.isObscured = false,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onToggleVisibility;
  final bool isObscured;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 14.5),
            fontWeight: FontWeight.w700,
            color: context.finFlowColors.primaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 4)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: Responsive.sp(context, 16),
            fontWeight: FontWeight.w500,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            constraints: BoxConstraints(minHeight: Responsive.h(context, 52)),
            hintText: hintText,
            errorText: errorText,
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 12.5),
              fontWeight: FontWeight.w500,
              color: context.finFlowColors.negativeAmount,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: context.finFlowColors.negativeAmount,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: context.finFlowColors.negativeAmount,
                width: 1.5,
              ),
            ),
            hintStyle: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 16),
            ),
            prefixIcon: Icon(icon, size: Responsive.w(context, 18)),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    icon: Icon(
                      isObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: Responsive.w(context, 18),
                    ),
                    onPressed: onToggleVisibility,
                  ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 12),
              vertical: Responsive.h(context, 12),
            ),
          ),
        ),
      ],
    );
  }
}

bool isValidAuthEmail(String value) {
  return RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  ).hasMatch(value.trim());
}
