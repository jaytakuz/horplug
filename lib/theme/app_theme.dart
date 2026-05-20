import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1B3A5C);
  static const primaryForeground = Colors.white;
  static const ring = Color(0xFF7CB9E8);
  static const background = Color(0xFFFFF8F0);
  static const card = Colors.white;
  
  static const success = Color(0xFF2D6A4F);
  static const successBg = Color(0xFFD4EDDA);
  
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFEF3C7);
  
  static const destructive = Color(0xFFEF4444);
  static const destructiveBg = Color(0xFFFEE2E2);
  
  static const muted = Color(0xFFEEF1F4);
  static const mutedForeground = Color(0xFF6B7C90);
  static const border = Color(0xFFDDE3EA);
}

class AppShadows {
  static const md = [
    BoxShadow(
      color: Color.fromRGBO(27, 58, 92, 0.06),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(27, 58, 92, 0.08),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];
}

ThemeData buildAppTheme() {
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      surface: AppColors.card,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );

  return baseTheme.copyWith(
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      labelStyle: const TextStyle(color: AppColors.primary),
      hintStyle: const TextStyle(color: AppColors.mutedForeground),
      helperStyle: const TextStyle(color: AppColors.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0xFFB8D4F1),
      selectionHandleColor: AppColors.primary,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.primary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
      labelSmall: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
    ),
  );
}
