import 'package:flutter/material.dart';

ThemeData buildAdminTheme(Brightness brightness) {
  const emerald = Color(0xFF0B6B4F);
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF16231F) : Colors.white;
  final page = dark ? const Color(0xFF0D1714) : const Color(0xFFF4F7F6);
  final input = dark ? const Color(0xFF1B2B26) : const Color(0xFFF7F9F8);
  final border = dark ? const Color(0xFF31433C) : const Color(0xFFDCE5E1);
  final scheme = ColorScheme.fromSeed(
    seedColor: emerald,
    brightness: brightness,
    primary: dark ? const Color(0xFF68D1A8) : emerald,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    cardColor: surface,
    dividerColor: border,
    canvasColor: surface,
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: input,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF294039) : const Color(0xFF243A34),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: input,
      selectedColor: dark ? const Color(0xFF24493D) : const Color(0xFFDCEFE7),
      side: BorderSide(color: border),
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
  );
}
