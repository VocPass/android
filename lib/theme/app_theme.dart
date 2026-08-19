import 'package:flutter/material.dart';

/// App-wide theme, tuned for an iOS / SwiftUI-like feel:
/// grouped backgrounds, soft rounded cards, hairline separators,
/// a single cyan brand accent, and full light + dark support.
class AppTheme {
  /// Brand accent (cyan/teal) — matches the home screen icons.
  static const Color accent = Color(0xFF12B5C9);
  static const Color accentDark = Color(0xFF2DD4E0);

  // iOS-like grouped background / card colors.
  static const Color _lightGroupedBg = Color(0xFFF2F2F7);
  static const Color _lightCard = Colors.white;
  static const Color _darkGroupedBg = Color(0xFF000000);
  static const Color _darkCard = Color(0xFF1C1C1E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: _lightCard,
      surfaceContainerHighest: const Color(0xFFEDEFF3),
      outlineVariant: const Color(0xFFD9D9DE),
    );
    return _build(
      scheme: scheme,
      scaffoldBg: _lightGroupedBg,
      cardBg: _lightCard,
      navBg: Colors.white,
      accentColor: accent,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentDark,
      surface: _darkCard,
      surfaceContainerHighest: const Color(0xFF2C2C2E),
      outlineVariant: const Color(0xFF38383A),
    );
    return _build(
      scheme: scheme,
      scaffoldBg: _darkGroupedBg,
      cardBg: _darkCard,
      navBg: const Color(0xFF161618),
      accentColor: accentDark,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color cardBg,
    required Color navBg,
    required Color accentColor,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: accentColor,
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: scheme.onSurfaceVariant,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentColor : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        elevation: 0,
        height: 66,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentColor.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected)
                ? accentColor
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? accentColor
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentColor),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
