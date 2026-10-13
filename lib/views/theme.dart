import 'package:flutter/material.dart';

/// Palet Klontonk (sama dengan versi web): krem hangat + biru, dengan mode gelap.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static const light = Palette(
    bg: Color(0xFFEBE4DB),
    surface: Colors.white,
    surface2: Color(0xFFE4DACC),
    border: Color(0xFFDFD4C6),
    text: Color(0xFF2B2420),
    textSecondary: Color(0xFF5C5248),
    textMuted: Color(0xFF6F6357),
    primary: Color(0xFF0060AF),
    primarySoft: Color(0xFFE8F1FA),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0891B2),
  );

  static const dark = Palette(
    bg: Color(0xFF0A1628),
    surface: Color(0xFF121E33),
    surface2: Color(0xFF0E1829),
    border: Color(0xFF1E2A44),
    text: Color(0xFFE8EEF5),
    textSecondary: Color(0xFF9AA8BC),
    textMuted: Color(0xFF5A6B82),
    primary: Color(0xFF4A90D9),
    primarySoft: Color(0xFF0E2A4A),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF22B8CF),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteContext on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0060AF), brightness: brightness).copyWith(
    primary: p.primary,
    surface: p.surface,
    onSurface: p.text,
    error: p.danger,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    dividerColor: p.border,
    appBarTheme: AppBarTheme(backgroundColor: p.surface, foregroundColor: p.text, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(bodyColor: p.text, displayColor: p.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.primary, 2),
      errorBorder: border(p.danger),
      hintStyle: TextStyle(color: p.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: p.text, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22)))),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    drawerTheme: DrawerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(color: Colors.white)),
  );
}
