import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../constants/ui_constants.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
        error: AppColors.danger,
        tertiary: AppColors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: UIConstants.elevationMD,
        centerTitle: false,
        titleTextStyle: UIConstants.heading4.copyWith(
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.spaceLG, 
            vertical: UIConstants.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusLG),
          ),
          elevation: UIConstants.elevationSM,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          textStyle: UIConstants.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        elevation: UIConstants.elevationMD,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusLG),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: UIConstants.spaceLG, 
          vertical: UIConstants.spaceSM,
        ),
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: UIConstants.elevationLG,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXL),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}