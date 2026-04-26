import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const radius = 8.0;
  static const cardRadius = 12.0;
  static const sidebarWidth = 220.0;
  static const headerHeight = 64.0;
  static const bottomNavHeight = 56.0;

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData _build(ColorSet c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: (brightness == Brightness.dark ? ColorScheme.dark : ColorScheme.light)(
        surface: c.surface,
        primary: c.accent,
        onPrimary: c.textOnAccent,
        secondary: c.accentHover,
        error: c.error,
        outline: c.border,
      ),
      cardColor: c.surface,
      dividerColor: c.border,
      hoverColor: c.surfaceHover,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 15.2),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 14.4, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.textOnAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: c.border),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius * 2)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface,
        contentTextStyle: TextStyle(color: c.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: c.textOnAccent, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 32),
        headlineMedium: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 28),
        headlineSmall: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 24),
        titleLarge: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 24),
        titleMedium: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(color: c.textSecondary, fontSize: 14),
        bodyLarge: TextStyle(color: c.text, fontSize: 16, height: 1.6),
        bodyMedium: TextStyle(color: c.text, fontSize: 16, height: 1.6),
        bodySmall: TextStyle(color: c.textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: c.text, fontSize: 14.4, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: c.textSecondary, fontSize: 13),
        labelSmall: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
    );
  }
}
