import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: FinFlowColors.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: FinFlowColors.dark);

  static ThemeData _build({
    required Brightness brightness,
    required FinFlowColors colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: AppColors.emerald,
      primary: isDark ? AppColors.sage : AppColors.emerald,
      secondary: AppColors.coral,
      surface: colors.surface,
      error: colors.negativeAmount,
    );
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.navigationBackground,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.inputBorder),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.pageBackground,
      canvasColor: colors.surface,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      disabledColor: colors.disabled,
      fontFamily: 'Roboto',
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: overlay,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        labelStyle: TextStyle(color: colors.secondaryText),
        hintStyle: TextStyle(color: colors.secondaryText),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.disabled),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: colors.primaryText, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.bottomSheetBackground,
        modalBackgroundColor: colors.bottomSheetBackground,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? colors.elevatedSurface : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: isDark ? AppColors.sage : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.elevatedSurface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: colors.primaryText),
      ),
      dividerTheme: DividerThemeData(color: colors.divider),
      listTileTheme: ListTileThemeData(
        textColor: colors.primaryText,
        iconColor: colors.primaryText,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.navigationBackground,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navigationBackground,
        selectedItemColor: scheme.primary,
        unselectedItemColor: colors.secondaryText,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colors.dialogBackground,
        dialBackgroundColor: colors.elevatedSurface,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: colors.disabled.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
