import 'package:flutter/material.dart';

class VtColors {
  // Brand palette — mirrors the web app's CSS variables
  static const Color bg        = Color(0xFF0F172A); // --rm-bg-solid (dark)
  static const Color surface   = Color(0xFF1E293B); // --rm-surface (dark)
  static const Color surface2  = Color(0xFF0F172A); // --rm-surface-2
  static const Color primary   = Color(0xFF1C75BC); // --rm-primary
  static const Color primaryBg = Color(0x261C75BC); // --rm-primary-bg
  static const Color navy      = Color(0xFF262262); // brand navy
  static const Color text      = Color(0xFFFFFFFF);
  static const Color text2     = Color(0xA6FFFFFF); // .65 alpha
  static const Color text3     = Color(0x4DFFFFFF); // .30 alpha
  static const Color border    = Color(0x14FFFFFF); // .08 alpha
  static const Color danger    = Color(0xFFEF4444);
  static const Color success   = Color(0xFF22C55E);
  static const Color warning   = Color(0xFFF59E0B);

  static const Color inputFill = Color(0xFF1E293B);

  // Light surfaces — used by the auth screens, which read on white
  static const Color authBg       = Color(0xFFFBFCFE);
  static const Color authInk      = Color(0xFF1B2559); // headings, matches logo navy
  static const Color authInkMuted = Color(0xFF6B7686);
  static const Color authBorder   = Color(0xFFE3E8F0);
  static const Color authFill     = Color(0xFFF5F7FA);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VtColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: VtColors.surface,
      primary: VtColors.primary,
      onPrimary: Colors.white,
      onSurface: VtColors.text,
      error: VtColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VtColors.surface,
      foregroundColor: VtColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: VtColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: VtColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: VtColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VtColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.danger),
      ),
      hintStyle: const TextStyle(color: VtColors.text3, fontSize: 14),
      labelStyle: const TextStyle(color: VtColors.text2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VtColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: VtColors.primary),
    ),
    dividerTheme: const DividerThemeData(
      color: VtColors.border,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: VtColors.text, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: VtColors.text, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: VtColors.text, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: VtColors.text, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: VtColors.text),
      bodyMedium: TextStyle(color: VtColors.text2),
      bodySmall: TextStyle(color: VtColors.text3, fontSize: 12),
    ),
  );

  // Light variant — used by the auth (login/register) screens, which
  // read on a white background rather than the app's default dark theme.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: VtColors.authBg,
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: VtColors.primary,
      onPrimary: Colors.white,
      onSurface: VtColors.authInk,
      error: VtColors.danger,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VtColors.authFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: VtColors.authInkMuted,
      suffixIconColor: VtColors.authInkMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.authBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.authBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VtColors.danger),
      ),
      hintStyle: const TextStyle(color: VtColors.authInkMuted, fontSize: 14),
      labelStyle: const TextStyle(color: VtColors.authInkMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VtColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: VtColors.primary),
    ),
    dividerTheme: const DividerThemeData(
      color: VtColors.authBorder,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: VtColors.authInk, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: VtColors.authInk, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: VtColors.authInk, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: VtColors.authInk, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: VtColors.authInk),
      bodyMedium: TextStyle(color: VtColors.authInkMuted),
      bodySmall: TextStyle(color: VtColors.authInkMuted, fontSize: 12),
    ),
  );
}
