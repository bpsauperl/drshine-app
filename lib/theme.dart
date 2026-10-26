import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

/// drShine's palette: white tiles on light grey, near-black ink, one indigo accent.
class Brand {
  static const Color indigo = Color(0xFF5364A3);
  static const Color indigoSoft = Color(0xFFE6E9F5);
  static const Color ink = Color(0xFF1D1D1F);
  static const Color secondary = Color(0xFF6E6E73);
  static const Color canvas = Color(0xFFF4F6FA);
  static const Color tile = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD2D2D7);
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

  factory Palette.of(BuildContext context) =>
      Palette._(Theme.of(context).brightness);

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

/// The app theme comes from the shared Shine kit (Direction C), in indigo.
ThemeData buildTheme(Brightness brightness) =>
    kitTheme(KitAccent.drShine, brightness);
