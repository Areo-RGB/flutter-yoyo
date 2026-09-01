import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

ThemeData yoYoLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: athleticBlue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0F2FE),
      onPrimaryContainer: athleticBlueDark,
      secondary: warnOrange,
      onSecondary: Colors.white,
      secondaryContainer: warnOrangeBg,
      onSecondaryContainer: warnOrangeDark,
      tertiary: runGreen,
      onTertiary: Colors.white,
      tertiaryContainer: runGreenLight,
      onTertiaryContainer: runGreenDark,
      error: eliminateRed,
      onError: Colors.white,
      errorContainer: eliminateRedLight,
      onErrorContainer: eliminateRedDark,
      surface: Colors.white,
      onSurface: slate900,
      surfaceContainerHighest: slate100,
      onSurfaceVariant: slate700,
      outline: slate200,
    ),
    textTheme: yoYoTextTheme,
  );
}

ThemeData yoYoDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: athleticBlueLight,
      onPrimary: slate900,
      primaryContainer: athleticBlueDark,
      onPrimaryContainer: Color(0xFFE0F2FE),
      secondary: warnOrangeLight,
      onSecondary: slate900,
      secondaryContainer: warnOrangeBgDark,
      onSecondaryContainer: warnOrangeBg,
      tertiary: runGreenLight,
      onTertiary: slate900,
      tertiaryContainer: runGreenDark,
      onTertiaryContainer: runGreenLight,
      error: eliminateRedLight,
      onError: slate900,
      errorContainer: eliminateRedDark,
      onErrorContainer: eliminateRedLight,
      surface: slate800,
      onSurface: slate50,
      surfaceContainerHighest: slate700,
      onSurfaceVariant: slate200,
      outline: slate600,
    ),
    textTheme: yoYoTextTheme,
  );
}
