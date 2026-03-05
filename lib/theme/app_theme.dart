import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds — neutral dark, VSCode-style
  static const background = Color(0xFF1E1E1E);
  static const panelBg = Color(0xFF252526);
  static const surfaceBg = Color(0xFF2D2D30);
  static const borderColor = Color(0xFF3E3E42);

  // Dialog
  static const dialogBg = Color(0xFF252526);
  static const dialogSurface = Color(0xFF2D2D30);
  static const dialogBorder = Color(0xFF3E3E42);

  // Accent — VSCode blue
  static const accent = Color(0xFF3573A5);
  static const accentHover = Color(0xFF4A8BBF);

  // Text
  static const textPrimary = Color(0xFFD4D4D4);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textMuted = Color(0xFF6A6A6A);

  // Status
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  // Tile palette highlight
  static const tileSelected = Color(0xFF3573A5);
  static const tileHover = Color(0xFF2A2D2E);
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
        dialogTheme: const DialogTheme(
          backgroundColor: AppColors.panelBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.borderColor),
          ),
        ),
      );
}
