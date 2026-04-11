import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Stitch color tokens ─────────────────────────────────────────────────
  static const _primary = Color(0xFF031632);
  static const _primaryContainer = Color(0xFF1A2B48);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _onPrimaryContainer = Color(0xFF8293B5);

  static const _secondary = Color(0xFF0058BE);
  static const _secondaryContainer = Color(0xFF2170E4);
  static const _onSecondary = Color(0xFFFFFFFF);
  static const _onSecondaryContainer = Color(0xFFFEFCFF);

  static const _tertiary = Color(0xFF001B0F);
  static const _tertiaryContainer = Color(0xFF003220);
  static const _onTertiary = Color(0xFFFFFFFF);
  static const _onTertiaryContainer = Color(0xFF00A673);

  static const _error = Color(0xFFBA1A1A);
  static const _errorContainer = Color(0xFFFFDAD6);
  static const _onError = Color(0xFFFFFFFF);
  static const _onErrorContainer = Color(0xFF93000A);

  static const _surface = Color(0xFFF9F9FF);
  static const _surfaceDim = Color(0xFFCADAFF);
  static const _surfaceBright = Color(0xFFF9F9FF);
  static const _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const _surfaceContainerLow = Color(0xFFF1F3FF);
  static const _surfaceContainer = Color(0xFFE8EEFF);
  static const _surfaceContainerHigh = Color(0xFFDFE8FF);
  static const _surfaceContainerHighest = Color(0xFFD7E2FF);
  static const _onSurface = Color(0xFF081B38);
  static const _onSurfaceVariant = Color(0xFF44474D);

  static const _outline = Color(0xFF75777E);
  static const _outlineVariant = Color(0xFFC5C6CE);

  static const _inverseSurface = Color(0xFF20304E);
  static const _inverseOnSurface = Color(0xFFECF0FF);
  static const _inversePrimary = Color(0xFFB6C7EB);

  // ── Light color scheme ──────────────────────────────────────────────────
  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primary,
    primaryContainer: _primaryContainer,
    onPrimary: _onPrimary,
    onPrimaryContainer: _onPrimaryContainer,
    primaryFixed: Color(0xFFD7E2FF),
    primaryFixedDim: Color(0xFFB6C7EB),
    secondary: _secondary,
    secondaryContainer: _secondaryContainer,
    onSecondary: _onSecondary,
    onSecondaryContainer: _onSecondaryContainer,
    secondaryFixed: Color(0xFFD8E2FF),
    secondaryFixedDim: Color(0xFFADC6FF),
    tertiary: _tertiary,
    tertiaryContainer: _tertiaryContainer,
    onTertiary: _onTertiary,
    onTertiaryContainer: _onTertiaryContainer,
    tertiaryFixed: Color(0xFF6FFBBE),
    tertiaryFixedDim: Color(0xFF4EDEA3),
    error: _error,
    errorContainer: _errorContainer,
    onError: _onError,
    onErrorContainer: _onErrorContainer,
    surface: _surface,
    surfaceDim: _surfaceDim,
    surfaceBright: _surfaceBright,
    surfaceContainerLowest: _surfaceContainerLowest,
    surfaceContainerLow: _surfaceContainerLow,
    surfaceContainer: _surfaceContainer,
    surfaceContainerHigh: _surfaceContainerHigh,
    surfaceContainerHighest: _surfaceContainerHighest,
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceVariant,
    outline: _outline,
    outlineVariant: _outlineVariant,
    inverseSurface: _inverseSurface,
    onInverseSurface: _inverseOnSurface,
    inversePrimary: _inversePrimary,
    surfaceTint: Color(0xFF4E5F7E),
    shadow: Colors.black,
    scrim: Colors.black,
  );

  // ── Typography ──────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base) {
    final manrope = GoogleFonts.manropeTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);

    return inter.copyWith(
      displayLarge: manrope.displayLarge?.copyWith(letterSpacing: -1.2),
      displayMedium: manrope.displayMedium?.copyWith(letterSpacing: -0.8),
      displaySmall: manrope.displaySmall?.copyWith(letterSpacing: -0.5),
      headlineLarge: manrope.headlineLarge?.copyWith(letterSpacing: -0.5),
      headlineMedium: manrope.headlineMedium?.copyWith(letterSpacing: -0.3),
      headlineSmall: manrope.headlineSmall?.copyWith(letterSpacing: -0.2),
      titleLarge: manrope.titleLarge?.copyWith(letterSpacing: -0.2),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const cs = _lightColorScheme;
    final textTheme = _buildTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: Brightness.light,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.primary,
        elevation: 0,
        indicatorColor: Colors.white.withAlpha(25),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Colors.white.withAlpha(180)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        horizontalTitleGap: 12,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: cs.outlineVariant.withAlpha(50)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(cs.surfaceContainerLow),
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
        dataTextStyle: GoogleFonts.inter(fontSize: 13, color: cs.onSurface),
        dividerThickness: 0,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: cs.secondary,
        labelColor: cs.secondary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: GoogleFonts.inter(color: cs.onInverseSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final darkColorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _inversePrimary,
      primaryContainer: const Color(0xFF374765),
      onPrimary: _primary,
      onPrimaryContainer: const Color(0xFFD7E2FF),
      secondary: const Color(0xFFADC6FF),
      secondaryContainer: const Color(0xFF004395),
      onSecondary: const Color(0xFF001A42),
      onSecondaryContainer: const Color(0xFFD8E2FF),
      tertiary: const Color(0xFF4EDEA3),
      tertiaryContainer: const Color(0xFF005236),
      onTertiary: _tertiary,
      onTertiaryContainer: const Color(0xFF6FFBBE),
      error: const Color(0xFFFFB4AB),
      errorContainer: const Color(0xFF93000A),
      onError: const Color(0xFF690005),
      onErrorContainer: _errorContainer,
      surface: const Color(0xFF111827),
      surfaceDim: const Color(0xFF0D1117),
      surfaceBright: const Color(0xFF1E293B),
      surfaceContainerLowest: const Color(0xFF0D1117),
      surfaceContainerLow: const Color(0xFF151D2E),
      surfaceContainer: const Color(0xFF1A2332),
      surfaceContainerHigh: const Color(0xFF1E293B),
      surfaceContainerHighest: const Color(0xFF243044),
      onSurface: const Color(0xFFE2E8F0),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF64748B),
      outlineVariant: const Color(0xFF334155),
      inverseSurface: const Color(0xFFE2E8F0),
      onInverseSurface: const Color(0xFF1E293B),
      inversePrimary: _primary,
      surfaceTint: const Color(0xFF4E5F7E),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final textTheme = _buildTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      brightness: Brightness.dark,
      textTheme: textTheme,
      scaffoldBackgroundColor: darkColorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: darkColorScheme.surfaceContainer,
        foregroundColor: darkColorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          color: darkColorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: darkColorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 8,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: darkColorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        horizontalTitleGap: 12,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkColorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkColorScheme.secondary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          darkColorScheme.surfaceContainerHigh,
        ),
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: darkColorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: darkColorScheme.onSurface,
        ),
        dividerThickness: 0,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: darkColorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: darkColorScheme.secondary,
        labelColor: darkColorScheme.secondary,
        unselectedLabelColor: darkColorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: darkColorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkColorScheme.secondary,
        foregroundColor: darkColorScheme.onSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
