import 'package:flutter/material.dart';

// Premium dark-first Artyug palette
const kOrange = Color(0xFFFF6A2B);
const kOrangeDark = Color(0xFFD84F1A);
const kOrangeLight = Color(0x26FF6A2B);
const kBlack = Color(0xFF0A0D14);
const kGrey = Color(0xFFA9B1C1);
const kBorder = Color(0xFF2A3447);
const kBg = Color(0xFF090D15);
const kWhite = Color(0xFFFFFFFF);

class AppColors {
  AppColors._();

  // Core surfaces — stepped luminance so cards, chrome, and sidebar read clearly on the canvas
  static const Color background = Color(0xFF070B12);
  static const Color surface = Color(0xFF141C2C);
  static const Color surfaceVariant = Color(0xFF1C2739);
  static const Color surfaceHigh = Color(0xFF2A3A52);
  /// Sidebar / drawer: clearly lighter than [background] so the rail never “disappears”
  static const Color sidebar = Color(0xFF121A2A);

  // Brand
  static const Color primary = Color(0xFFFF6A2B);
  static const Color primaryDark = Color(0xFFD84F1A);
  static const Color primaryLight = Color(0x26FF6A2B);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF7F9FF);
  static const Color textSecondary = Color(0xFFB5C0D4);
  static const Color textTertiary = Color(0xFF72809A);

  /// Headings/body on white or light-tint cards while the app shell stays dark
  static const Color textOnLight = Color(0xFF0F172A);
  static const Color textOnLightSecondary = Color(0xFF4B5563);

  // Borders — slightly brighter for separation on dark fills
  static const Color border = Color(0xFF354056);
  static const Color borderStrong = Color(0xFF4A5D7A);

  // Semantic
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF2BB673);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF4F8BFF);

  // Backward-compat aliases
  static const Color primarySoft = Color(0x26FF6A2B);
  static const Color badgeBlue = Color(0xFF4F8BFF);
  static const Color badgeGold = Color(0xFFF59E0B);

  // Light aliases retained for compatibility
  static const Color lightBackground = background;
  static const Color lightSurface = surface;
  static const Color lightBorder = border;
  static const Color lightText = textPrimary;

  // Gradients
  static const Gradient goldGradient = LinearGradient(
    colors: [Color(0xFFFF7A3B), Color(0xFFFF5A1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC060A12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFF0C1220), Color(0xFF111826)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color darkBg = background;
  static const Color darkSurface = surface;
  static const Color darkBorder = border;
  static const Color darkText = textPrimary;

  // ── Light palette (keep in sync with [ThemeProvider] light theme) ─────────
  static const Color _lightCanvas = Color(0xFFF2F4F8);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceMuted = Color(0xFFEEF2F7);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color _lightBorderStrong = Color(0xFFD1D5DB);
  static const Color _lightTextPrimary = Color(0xFF0F172A);
  static const Color _lightTextSecondary = Color(0xFF4B5563);
  static const Color _lightTextTertiary = Color(0xFF6B7280);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Page background — matches Material scaffold in both modes.
  static Color canvas(BuildContext context) =>
      _isDark(context) ? background : _lightCanvas;

  /// Cards, sheets, nav search fields.
  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? surface : _lightSurface;

  /// Muted panels (secondary cards, placeholders).
  static Color surfaceMutedOf(BuildContext context) =>
      _isDark(context) ? surfaceVariant : _lightSurfaceMuted;

  static Color surfaceHighOf(BuildContext context) =>
      _isDark(context) ? surfaceHigh : const Color(0xFFE2E8F0);

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? border : _lightBorder;

  static Color borderStrongOf(BuildContext context) =>
      _isDark(context) ? borderStrong : _lightBorderStrong;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? textPrimary : _lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? textSecondary : _lightTextSecondary;

  static Color textTertiaryOf(BuildContext context) =>
      _isDark(context) ? textTertiary : _lightTextTertiary;

  static Gradient heroGradientOf(BuildContext context) {
    if (_isDark(context)) return heroGradient;
    return const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFE8EEF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Card / floating shadow strength by mode.
  static List<BoxShadow> cardShadows(BuildContext context,
      {bool hovered = false}) {
    final a = _isDark(context) ? (hovered ? 0.45 : 0.32) : (hovered ? 0.14 : 0.08);
    final blur = hovered ? 28.0 : 20.0;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: a),
        blurRadius: blur,
        offset: const Offset(0, 12),
      ),
    ];
  }
}
