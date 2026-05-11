import 'package:flutter/material.dart';

class AppColors {
  // Background colors
  static const background = Color(0xFF0d0d1a);
  static const surface = Color(0xFF1a1a2e);
  static const surfaceLight = Color(0xFF252542);

  // Primary colors
  static const primary = Color(0xFF00ff9f);
  static const secondary = Color(0xFF00d4ff);
  static const accent = Color(0xFF7c3aed);

  // Text colors
  static const textPrimary = Color(0xFFe0e0e0);
  static const textSecondary = Color(0xFFa0a0a0);
  static const textMuted = Color(0xFF6b6b8d);

  // Status colors
  static const border = Color(0xFF2a2a4a);
  static const success = Color(0xFF00ff9f);
  static const warning = Color(0xFFffcc00);
  static const error = Color(0xFFff4757);

  // Priority colors
  static const priorityHigh = Color(0xFFff4757);
  static const priorityMedium = Color(0xFFffcc00);
  static const priorityLow = Color(0xFF00ff9f);

  // Gradient presets
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF00ff9f), Color(0xFF00d4ff)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7c3aed), Color(0xFF00d4ff)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.primary, size: 28),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        indicatorColor: Color(0xFF1a3a2e),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Custom Box Shadows for cards
class AppShadows {
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 12,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];
}