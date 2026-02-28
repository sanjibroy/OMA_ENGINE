import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const background = Color(0xFF0F0F13);
  static const panelBg = Color(0xFF16161D);
  static const surfaceBg = Color(0xFF1E1E28);
  static const borderColor = Color(0xFF2A2A35);

  // Dialog — warm charcoal, no color cast, easy on the eyes
  static const dialogBg = Color(0xFF201E1C);
  static const dialogSurface = Color(0xFF2A2826);
  static const dialogBorder = Color(0xFF3D3A38);

  // Accent
  static const accent = Color(0xFF7C6FF7);
  static const accentHover = Color(0xFF9D98FA);

  // Text
  static const textPrimary = Color(0xFFE2E2E8);
  static const textSecondary = Color(0xFF888899);
  static const textMuted = Color(0xFF4A4A5A);

  // Status
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  // Tile palette highlight
  static const tileSelected = Color(0xFF7C6FF7);
  static const tileHover = Color(0xFF2A2A3A);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.panelBg,
          primary: AppColors.accent,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        dividerColor: AppColors.borderColor,
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          labelSmall: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 18),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderColor),
          ),
          textStyle:
              const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(AppColors.borderColor),
        ),
      );
}
