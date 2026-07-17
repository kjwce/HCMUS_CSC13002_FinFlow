import 'package:flutter/material.dart';

class AppColors {
  static const emerald = Color(0xFF0D8F5A);
  static const deepEmerald = Color(0xFF075E45);
  static const mint = Color(0xFFE7F4EC);
  static const mintSoft = Color(0xFFF3FBF6);
  static const sage = Color(0xFFB8D9C8);
  static const ink = Color(0xFF10251D);
  static const muted = Color(0xFF6D7B74);
  static const coral = Color(0xFFE86B5D);
  static const amber = Color(0xFFE5B54B);

  // Dashboard new design colors
  static const primaryGreen = Color(0xFF00D09E);
  static const lightGreen = Color(0xFFDFF7E2);
  static const darkText = Color(0xFF052224);
  static const blueAccent = Color(0xFF0068FF);
  static const dashboardBg = Color(0xFFF4FFF6);

  // Dashboard Figma design colors
  static const dashboardHeaderBg = Color(0xFFD4F4E4);
  static const darkGreenText = Color(0xFF003829);
  static const mediumGreen = Color(0xFF008768);
  static const darkGray = Color(0xFF444745);
  static const mutedGray = Color(0xFF8E928F);
  static const borderGray = Color(0xFFBFC9C3);
  static const deepGreen = Color(0xFF404944);
  static const ingBlue = Color(0xFF3799D2);
  static const brdTeal = Color(0xFF1CA380);
  static const ingTextBlue = Color(0xFF006492);
  static const brdTextGreen = Color(0xFF006C52);
  static const accentTeal = Color(0xFF44BF99);
  static const chartBlueFill = Color(0xFFD4EAFE);
  static const chartBlueBorder = Color(0xFF2A96FA);
  static const chartGreenFill = Color(0xFFCCF1E5);
  static const chartGreenBorder = Color(0xFF63DBB6);
  static const chartOrangeFill = Color(0xFFFFE0D0);
  static const chartOrangeBorder = Color(0xFFFF897A);
}

@immutable
class FinFlowColors extends ThemeExtension<FinFlowColors> {
  const FinFlowColors({
    required this.pageBackground,
    required this.surface,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.inputBackground,
    required this.inputBorder,
    required this.divider,
    required this.dialogBackground,
    required this.bottomSheetBackground,
    required this.navigationBackground,
    required this.positiveAmount,
    required this.negativeAmount,
    required this.warning,
    required this.disabled,
  });

  final Color pageBackground;
  final Color surface;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color inputBackground;
  final Color inputBorder;
  final Color divider;
  final Color dialogBackground;
  final Color bottomSheetBackground;
  final Color navigationBackground;
  final Color positiveAmount;
  final Color negativeAmount;
  final Color warning;
  final Color disabled;

  static const light = FinFlowColors(
    pageBackground: AppColors.mintSoft,
    surface: Colors.white,
    elevatedSurface: Color(0xFFF4F5F4),
    primaryText: AppColors.darkText,
    secondaryText: AppColors.muted,
    inputBackground: Colors.white,
    inputBorder: Color(0xFFBFC9C3),
    divider: Color(0xFFE6EAE8),
    dialogBackground: Colors.white,
    bottomSheetBackground: Colors.white,
    navigationBackground: Color(0xFFE6F8EA),
    positiveAmount: AppColors.deepEmerald,
    negativeAmount: Color(0xFFBA1A1A),
    warning: AppColors.amber,
    disabled: Color(0xFF9AA49F),
  );

  static const dark = FinFlowColors(
    pageBackground: Color(0xFF07120E),
    surface: Color(0xFF12231B),
    elevatedSurface: Color(0xFF1A2E25),
    primaryText: Color(0xFFE3F1E9),
    secondaryText: Color(0xFFA9B9B0),
    inputBackground: Color(0xFF1A2E25),
    inputBorder: Color(0xFF496057),
    divider: Color(0xFF2D4037),
    dialogBackground: Color(0xFF12231B),
    bottomSheetBackground: Color(0xFF12231B),
    navigationBackground: Color(0xFF0D1C16),
    positiveAmount: Color(0xFF7ADBB7),
    negativeAmount: Color(0xFFFFB4AB),
    warning: Color(0xFFFFD166),
    disabled: Color(0xFF718078),
  );

  @override
  FinFlowColors copyWith({
    Color? pageBackground,
    Color? surface,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? inputBackground,
    Color? inputBorder,
    Color? divider,
    Color? dialogBackground,
    Color? bottomSheetBackground,
    Color? navigationBackground,
    Color? positiveAmount,
    Color? negativeAmount,
    Color? warning,
    Color? disabled,
  }) => FinFlowColors(
    pageBackground: pageBackground ?? this.pageBackground,
    surface: surface ?? this.surface,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    inputBackground: inputBackground ?? this.inputBackground,
    inputBorder: inputBorder ?? this.inputBorder,
    divider: divider ?? this.divider,
    dialogBackground: dialogBackground ?? this.dialogBackground,
    bottomSheetBackground: bottomSheetBackground ?? this.bottomSheetBackground,
    navigationBackground: navigationBackground ?? this.navigationBackground,
    positiveAmount: positiveAmount ?? this.positiveAmount,
    negativeAmount: negativeAmount ?? this.negativeAmount,
    warning: warning ?? this.warning,
    disabled: disabled ?? this.disabled,
  );

  @override
  FinFlowColors lerp(covariant FinFlowColors? other, double t) {
    if (other == null) return this;
    return FinFlowColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dialogBackground: Color.lerp(
        dialogBackground,
        other.dialogBackground,
        t,
      )!,
      bottomSheetBackground: Color.lerp(
        bottomSheetBackground,
        other.bottomSheetBackground,
        t,
      )!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      positiveAmount: Color.lerp(positiveAmount, other.positiveAmount, t)!,
      negativeAmount: Color.lerp(negativeAmount, other.negativeAmount, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

extension FinFlowThemeContext on BuildContext {
  FinFlowColors get finFlowColors =>
      Theme.of(this).extension<FinFlowColors>() ?? FinFlowColors.light;
}
