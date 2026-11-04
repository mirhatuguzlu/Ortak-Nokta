import 'package:flutter/material.dart';

/// Sitedeki (site/src/styles.css) sıcak kâğıt paletiyle aynı renkler.
abstract final class Palette {
  static const paper = Color(0xFFF7F1E6);
  static const card = Color(0xFFFFFBF4);
  static const ink = Color(0xFF1F2A24);
  static const inkSoft = Color(0xFF5C665F);
  static const line = Color(0xFFDDD1BC);
  static const green = Color(0xFF1F5C4A);
  static const greenDeep = Color(0xFF163F33);
  static const greenSoft = Color(0xFFDDE9DF);
  static const clay = Color(0xFFC4603A);
  static const claySoft = Color(0xFFF3DCCD);
  static const sun = Color(0xFFE5AE45);
}

/// Kişi renkleri: haritada ve paylaşım kartında birbirinden kolay ayrılır.
const personColors = [
  Palette.clay,
  Palette.green,
  Color(0xFF7A4A72),
  Color(0xFF3B6B9C),
  Color(0xFFB8862B),
];

ThemeData appTheme(Brightness b) {
  final light = b == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: Palette.green, brightness: b);
  final scheme = light
      ? base.copyWith(
          primary: Palette.green,
          onPrimary: Colors.white,
          primaryContainer: Palette.greenSoft,
          onPrimaryContainer: Palette.greenDeep,
          secondary: Palette.clay,
          secondaryContainer: Palette.claySoft,
          onSecondaryContainer: const Color(0xFF5A2A16),
          tertiary: Palette.sun,
          surface: Palette.paper,
          onSurface: Palette.ink,
          onSurfaceVariant: Palette.inkSoft,
          surfaceContainerLowest: Palette.card,
          surfaceContainerLow: Palette.card,
          surfaceContainer: const Color(0xFFF1E8D8),
          surfaceContainerHigh: const Color(0xFFEFE5D3),
          surfaceContainerHighest: const Color(0xFFE8DCC6),
          outline: const Color(0xFFB9AC95),
          outlineVariant: Palette.line,
        )
      : base.copyWith(secondary: const Color(0xFFE59A78), tertiary: Palette.sun);
  final radius = BorderRadius.circular(18);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  final text = Typography.material2021(platform: TargetPlatform.android).englishLike.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          shape: pill, textStyle: buttonText, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          shape: pill,
          textStyle: buttonText,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: buttonText)),
    chipTheme: ChipThemeData(shape: pill),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
    ),
  );
}
