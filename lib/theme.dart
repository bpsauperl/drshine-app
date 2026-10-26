import 'package:flutter/material.dart';

/// drShine's palette: white tiles on light grey, near-black ink, one indigo accent.
class Brand {
  static const Color indigo = Color(0xFF5364A3);
  static const Color indigoSoft = Color(0xFFE6E9F5);
  static const Color ink = Color(0xFF1D1D1F);
  static const Color secondary = Color(0xFF6E6E73);
  static const Color canvas = Color(0xFFF4F6FA);
  static const Color tile = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE3E6EE);
  static const Color success = Color(0xFF2E8B57);
  static const Color danger = Color(0xFFC0392B);

  // Dark mode.
  static const Color darkCanvas = Color(0xFF000000);
  static const Color darkTile = Color(0xFF1C1C1E);
  static const Color darkInk = Color(0xFFF5F5F7);
  static const Color darkSecondary = Color(0xFF98989D);
  static const Color darkLine = Color(0xFF2C2C2E);
  static const Color indigoLight = Color(0xFF8B99D6);
  static const Color indigoSoftDark = Color(0xFF262B40);

  static const double radius = 20;
  static const double gutter = 20;
}

/// Colours that change with light and dark mode, read from the theme.
class Palette {
  const Palette._(this.brightness);

  factory Palette.of(BuildContext context) => Palette._(Theme.of(context).brightness);

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;
  Color get canvas => isDark ? Brand.darkCanvas : Brand.canvas;
  Color get tile => isDark ? Brand.darkTile : Brand.tile;
  Color get ink => isDark ? Brand.darkInk : Brand.ink;
  Color get secondary => isDark ? Brand.darkSecondary : Brand.secondary;
  Color get line => isDark ? Brand.darkLine : Brand.line;
  Color get accent => isDark ? Brand.indigoLight : Brand.indigo;
  Color get accentSoft => isDark ? Brand.indigoSoftDark : Brand.indigoSoft;

  /// Behind white text: the brand indigo in both modes, for contrast.
  Color get accentFill => Brand.indigo;
}

ThemeData buildTheme(Brightness brightness) {
  final p = Palette._(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.indigo,
    brightness: brightness,
  ).copyWith(
    primary: p.accent,
    onPrimary: Colors.white,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.accent,
    surface: p.tile,
    onSurface: p.ink,
    onSurfaceVariant: p.secondary,
    outline: p.line,
    outlineVariant: p.line,
    error: Brand.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    scaffoldBackgroundColor: p.canvas,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.9),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.35),
      bodySmall: text.bodySmall?.copyWith(color: p.secondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium?.copyWith(color: p.ink, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    ),
    cardTheme: CardThemeData(
      color: p.tile,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brand.radius)),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.tile,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 1.5)),
      labelStyle: TextStyle(color: p.secondary),
      hintStyle: TextStyle(color: p.secondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accentFill,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.line,
        disabledForegroundColor: p.secondary,
        minimumSize: const Size.fromHeight(52),
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: p.line),
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent, textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.tile,
      selectedColor: p.accentSoft,
      side: BorderSide(color: p.line),
      labelStyle: text.bodyMedium?.copyWith(color: p.ink, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(rounded),
        side: WidgetStatePropertyAll(BorderSide(color: p.line)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accentSoft : p.tile),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.ink),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? Brand.darkTile : Brand.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radius))),
    ),
  );
}
