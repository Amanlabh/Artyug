import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

// Legacy aliases preserved so existing screens importing ThemeProvider constants
// keep compiling while the new design system uses AppColors tokens.
const Color kOrange = AppColors.primary;
const Color kOrangeDark = AppColors.primaryDark;
const Color kOrangeLight = AppColors.primaryLight;
const Color kBlack = AppColors.textPrimary;
const Color kGrey = AppColors.textSecondary;
const Color kBorder = AppColors.border;
const Color kBg = AppColors.background;
const Color kWhite = Colors.white;

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;


  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;

    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', value);
    notifyListeners();
  }

  ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);
  ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    const fontFamily = 'Outfit';

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.info,
      onSecondary: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.surface : const Color(0xFFF6F8FC),
      onSurface: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.background : const Color(0xFFF2F4F8),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.sidebar : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black54,
        width: 304,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        foregroundColor:
            isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textSecondary : const Color(0xFF4B5563),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? AppColors.textPrimary : const Color(0xFF111827),
          side: BorderSide(
            color: isDark ? AppColors.borderStrong : const Color(0xFFD1D5DB),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariant : Colors.white,
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textTertiary : const Color(0xFF6B7280),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceVariant : const Color(0xFFF3F4F6),
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        side: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFD1D5DB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceHigh : const Color(0xFF111827),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor:
            isDark ? AppColors.textTertiary : const Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
