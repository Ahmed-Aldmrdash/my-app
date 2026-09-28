import 'package:flutter/material.dart';

/// The app's palette: a lively violet with fresh accents.
class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const primarySoft = Color(0xFFA29BFE);
  static const pink = Color(0xFFFD79A8);
  static const coral = Color(0xFFFF7675);
  static const teal = Color(0xFF00B894);
  static const mint = Color(0xFF55EFC4);
  static const amber = Color(0xFFFDCB6E);
  static const orange = Color(0xFFF39C12);
  static const sky = Color(0xFF0984E3);
  static const cyan = Color(0xFF00CEC9);

  static const success = Color(0xFF00B894);
  static const warning = Color(0xFFF39C12);
  static const danger = Color(0xFFE74C3C);
  static const bonus = Color(0xFFB45CE7);

  static const lightBackground = Color(0xFFF5F4FB);
  static const darkBackground = Color(0xFF110F1A);
  static const darkCard = Color(0xFF1D1A29);

  static const heroGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFF), Color(0xFFB39DFF)],
  );

  static const focusGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFFFF7675), Color(0xFFFD79A8), Color(0xFFB45CE7)],
  );

  static const tealGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
  );

  /// A soft two-stop gradient built from any colour (e.g. a subject's).
  static LinearGradient gradientOf(Color c) => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [c, Color.lerp(c, Colors.white, 0.28)!],
  );

  /// White or near-black, whichever reads better on [c].
  static Color onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1E1B2E);
}

const _fontFamily = 'Cairo';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  final scheme = base.copyWith(
    primary: dark ? AppColors.primarySoft : AppColors.primary,
    onPrimary: dark ? const Color(0xFF1E1650) : Colors.white,
    surface: dark ? AppColors.darkBackground : AppColors.lightBackground,
    surfaceContainerLowest: dark ? AppColors.darkCard : Colors.white,
    surfaceContainerLow: dark ? AppColors.darkCard : Colors.white,
    error: AppColors.danger,
  );

  final textTheme = ThemeData(
    brightness: brightness,
    fontFamily: _fontFamily,
  ).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: dark ? AppColors.darkCard : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkCard : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 4,
      extendedTextStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.darkCard : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
