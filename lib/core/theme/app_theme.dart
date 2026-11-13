import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography and component styling shared by the whole application.
abstract final class AppTheme {
  static const String bodyFont = 'Almarai';
  static const String displayFont = 'Amiri';

  static TextTheme _textTheme(TextTheme base, Color ink, Color soft) {
    return base.apply(fontFamily: bodyFont, bodyColor: ink, displayColor: ink).copyWith(
          displayLarge: base.displayLarge!.copyWith(
            fontFamily: displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 44,
            height: 1.25,
            color: ink,
          ),
          displayMedium: base.displayMedium!.copyWith(
            fontFamily: displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 34,
            height: 1.3,
            color: ink,
          ),
          headlineLarge: base.headlineLarge!.copyWith(
            fontFamily: displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 28,
            height: 1.35,
            color: ink,
          ),
          headlineMedium: base.headlineMedium!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.45,
            color: ink,
          ),
          titleLarge: base.titleLarge!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            height: 1.5,
            color: ink,
          ),
          titleMedium: base.titleMedium!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.6,
            color: ink,
          ),
          bodyLarge: base.bodyLarge!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w400,
            fontSize: 16.5,
            height: 1.95,
            color: ink,
          ),
          bodyMedium: base.bodyMedium!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w400,
            fontSize: 14.5,
            height: 1.9,
            color: soft,
          ),
          labelLarge: base.labelLarge!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0,
          ),
          labelMedium: base.labelMedium!.copyWith(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: 0,
            color: soft,
          ),
        );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.clay,
      onPrimary: Colors.white,
      primaryContainer: AppColors.claySoft,
      onPrimaryContainer: Color(0xFF5A1E10),
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.indigoSoft,
      onSecondaryContainer: Color(0xFF0B2C37),
      tertiary: AppColors.ochre,
      onTertiary: Color(0xFF3A2A05),
      tertiaryContainer: AppColors.ochreSoft,
      onTertiaryContainer: Color(0xFF4A3608),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: AppColors.paperHigh,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.paper,
      onSurfaceVariant: AppColors.inkSoft,
      outline: Color(0xFFCFC3B0),
      outlineVariant: Color(0xFFE6DCCB),
      shadow: Color(0x22000000),
      scrim: Color(0x99000000),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.claySoft,
    );
    return _build(scheme, AppColors.paper);
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE38A6E),
      onPrimary: Color(0xFF3B1108),
      primaryContainer: Color(0xFF5D2A1D),
      onPrimaryContainer: Color(0xFFF6D5C9),
      secondary: Color(0xFF7FB6C7),
      onSecondary: Color(0xFF05222B),
      secondaryContainer: Color(0xFF20434E),
      onSecondaryContainer: Color(0xFFCDE6EE),
      tertiary: Color(0xFFE8BE72),
      onTertiary: Color(0xFF39280A),
      tertiaryContainer: Color(0xFF4E3B14),
      onTertiaryContainer: Color(0xFFF7E3BC),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: AppColors.nightSurface,
      onSurface: Color(0xFFF2EDE4),
      surfaceContainerHighest: AppColors.nightElevated,
      onSurfaceVariant: Color(0xFFC4C2CC),
      outline: Color(0xFF4A4C56),
      outlineVariant: Color(0xFF33353D),
      shadow: Color(0x66000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFF2EDE4),
      onInverseSurface: AppColors.night,
      inversePrimary: AppColors.clay,
    );
    return _build(scheme, AppColors.night);
  }

  static ThemeData _build(ColorScheme scheme, Color scaffoldBackground) {
    final base = ThemeData(brightness: scheme.brightness, useMaterial3: true, colorScheme: scheme);
    final textTheme = _textTheme(base.textTheme, scheme.onSurface, scheme.onSurfaceVariant);
    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.brightness == Brightness.light ? Colors.white : AppColors.nightElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.brightness == Brightness.light
            ? AppColors.paperHigh
            : AppColors.nightSurface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        height: 68,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        selectedLabelTextStyle: textTheme.labelLarge,
        unselectedLabelTextStyle: textTheme.labelMedium,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
