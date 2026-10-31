import 'package:flutter/material.dart';

/// Colors that have meaning in the app but are not part of Material's
/// [ColorScheme], so they can adapt to the active brightness.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.gain, required this.loss});

  /// Positive price movement.
  final Color gain;

  /// Negative price movement.
  final Color loss;

  @override
  AppColors copyWith({Color? gain, Color? loss}) =>
      AppColors(gain: gain ?? this.gain, loss: loss ?? this.loss);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      gain: Color.lerp(gain, other.gain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
    );
  }
}

/// Shorthand for the app's semantic colors.
extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Deep navy surfaces with emerald accents.
abstract final class AppTheme {
  static const Color navy900 = Color(0xFF071427);
  static const Color navy800 = Color(0xFF0B1B33);
  static const Color navy700 = Color(0xFF162C4A);
  static const Color emerald700 = Color(0xFF0E8F5F);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald300 = Color(0xFF34D399);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: emerald700,
    brightness: Brightness.light,
  ).copyWith(
    primary: navy800,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD7E3F4),
    onPrimaryContainer: navy900,
    secondary: emerald700,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFB9EFD9),
    onSecondaryContainer: const Color(0xFF04291D),
    surface: const Color(0xFFF7F9FC),
    onSurface: const Color(0xFF10233B),
    onSurfaceVariant: const Color(0xFF5B6B80),
    surfaceContainerLow: Colors.white,
    surfaceContainerHighest: const Color(0xFFE3EAF3),
    outlineVariant: const Color(0xFFC7D3E1),
    surfaceTint: navy800,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: emerald500,
    brightness: Brightness.dark,
  ).copyWith(
    primary: emerald300,
    onPrimary: const Color(0xFF04291D),
    primaryContainer: const Color(0xFF0C3B2E),
    onPrimaryContainer: const Color(0xFFB9EFD9),
    secondary: const Color(0xFFA7C6EE),
    onSecondary: navy900,
    secondaryContainer: const Color(0xFF1E3A5F),
    onSecondaryContainer: const Color(0xFFD7E3F4),
    surface: navy800,
    onSurface: const Color(0xFFE6EDF7),
    onSurfaceVariant: const Color(0xFFA9BACD),
    surfaceDim: navy900,
    surfaceBright: const Color(0xFF22395B),
    surfaceContainerLowest: const Color(0xFF04101F),
    surfaceContainerLow: navy900,
    surfaceContainer: const Color(0xFF102340),
    surfaceContainerHigh: navy700,
    surfaceContainerHighest: const Color(0xFF1E3654),
    outlineVariant: const Color(0xFF2C4767),
    surfaceTint: emerald300,
  );

  static ThemeData light() => _build(_lightScheme, Brightness.light);

  static ThemeData dark() => _build(_darkScheme, Brightness.dark);

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        AppColors(
          gain: isDark ? emerald300 : emerald700,
          loss: isDark ? const Color(0xFFFF8A80) : const Color(0xFFC0392B),
        ),
      ],
      appBarTheme: AppBarThemeData(
        backgroundColor: isDark ? navy900 : navy800,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
