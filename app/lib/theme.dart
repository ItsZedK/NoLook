import 'package:flutter/material.dart';
import 'package:nolook_core/nolook_core.dart';

/// m3 palette from #2f63a4
class NlColors extends ThemeExtension<NlColors> {
  const NlColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.violetContainer,
    required this.onVioletContainer,
    required this.peachContainer,
    required this.onPeachContainer,
    required this.error,
    required this.errorContainer,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceMid,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.wash,
  });

  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color secondaryContainer, onSecondaryContainer;
  final Color tertiaryContainer, onTertiaryContainer;
  final Color violetContainer, onVioletContainer, peachContainer, onPeachContainer;
  final Color error, errorContainer;
  final Color surface, surfaceLow, surfaceMid, surfaceHigh, surfaceHighest;
  final Color onSurface, onSurfaceVariant, outline, outlineVariant;

  /// translucent overlay for coloured cards
  final Color wash;

  static const light = NlColors(
    primary: Color(0xFF305F9B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD5E3FF),
    onPrimaryContainer: Color(0xFF001C3B),
    secondaryContainer: Color(0xFFDAE2F9),
    onSecondaryContainer: Color(0xFF131C2B),
    tertiaryContainer: Color(0xFFC4ECF6),
    onTertiaryContainer: Color(0xFF001F25),
    violetContainer: Color(0xFFECE0FF),
    onVioletContainer: Color(0xFF23104A),
    peachContainer: Color(0xFFFFDCC6),
    onPeachContainer: Color(0xFF311300),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFFF8F9FF),
    surfaceLow: Color(0xFFF2F3FA),
    surfaceMid: Color(0xFFECEEF4),
    surfaceHigh: Color(0xFFE6E8EE),
    surfaceHighest: Color(0xFFE0E2E8),
    onSurface: Color(0xFF191C20),
    onSurfaceVariant: Color(0xFF43474E),
    outline: Color(0xFF73777F),
    outlineVariant: Color(0xFFC3C6CF),
    wash: Color(0x99FFFFFF),
  );

  static const dark = NlColors(
    primary: Color(0xFFA7C8FF),
    onPrimary: Color(0xFF003061),
    primaryContainer: Color(0xFF144781),
    onPrimaryContainer: Color(0xFFD5E3FF),
    secondaryContainer: Color(0xFF3D4759),
    onSecondaryContainer: Color(0xFFDAE2F9),
    tertiaryContainer: Color(0xFF004E59),
    onTertiaryContainer: Color(0xFFC4ECF6),
    violetContainer: Color(0xFF4A3A70),
    onVioletContainer: Color(0xFFECE0FF),
    peachContainer: Color(0xFF6A3B1B),
    onPeachContainer: Color(0xFFFFDCC6),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF93000A),
    surface: Color(0xFF111318),
    surfaceLow: Color(0xFF191C20),
    surfaceMid: Color(0xFF1D2024),
    surfaceHigh: Color(0xFF282A2F),
    surfaceHighest: Color(0xFF33353A),
    onSurface: Color(0xFFE1E2E9),
    onSurfaceVariant: Color(0xFFC3C6CF),
    outline: Color(0xFF8D9199),
    outlineVariant: Color(0xFF43474E),
    wash: Color(0x1FFFFFFF),
  );

  (Color, Color) block(BlockColor c) => switch (c) {
        BlockColor.teal => (tertiaryContainer, onTertiaryContainer),
        BlockColor.violet => (violetContainer, onVioletContainer),
        BlockColor.peach => (peachContainer, onPeachContainer),
        BlockColor.grey => (surfaceMid, onSurface),
      };

  @override
  NlColors copyWith() => this;

  @override
  NlColors lerp(NlColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension NlContext on BuildContext {
  NlColors get nl => Theme.of(this).extension<NlColors>()!;
  bool get isPhone => MediaQuery.sizeOf(this).width < 760;
}

/// variable fonts, set the wght axis too
TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) => TextStyle(
      fontFamily: 'Outfit',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
    );

TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1}) => TextStyle(
      fontFamily: 'Syne',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: size * -0.02,
    );

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? NlColors.dark : NlColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.secondaryContainer,
    onSecondaryContainer: c.onSecondaryContainer,
    tertiary: c.primary,
    onTertiary: c.onPrimary,
    tertiaryContainer: c.tertiaryContainer,
    onTertiaryContainer: c.onTertiaryContainer,
    error: c.error,
    onError: c.onPrimary,
    errorContainer: c.errorContainer,
    surface: c.surface,
    onSurface: c.onSurface,
    onSurfaceVariant: c.onSurfaceVariant,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surfaceLow,
    surfaceContainer: c.surfaceMid,
    surfaceContainerHigh: c.surfaceHigh,
    surfaceContainerHighest: c.surfaceHighest,
    outline: c.outline,
    outlineVariant: c.outlineVariant,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    fontFamily: 'Outfit',
    extensions: [c],
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary),
    tooltipTheme: TooltipThemeData(
      textStyle: body(12, color: c.surface),
      decoration: BoxDecoration(color: c.onSurface, borderRadius: BorderRadius.circular(6)),
      waitDuration: const Duration(milliseconds: 500),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.outlineVariant),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}
