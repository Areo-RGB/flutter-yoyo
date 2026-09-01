import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Centralized styling primitives — single source for the card radius,
/// button shapes and spacing values repeated across feature screens.
class AppDecorations {
  static const double cardRadius = 16;
  static const double cardRadiusLarge = 20;
  static const double chipRadius = 16;
  static const double badgeRadius = 12;

  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.fromLTRB(14, 12, 14, 12);
  static const double sectionSpacing = 12;
  static const double smallGap = 8;
  static const double largeGap = 24;

  static BoxDecoration slateCard({double radius = cardRadius}) => BoxDecoration(
        color: slate900,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration slateCardWithBorder({
    double radius = cardRadius,
    Color borderColor = slate700,
  }) =>
      BoxDecoration(
        color: slate800,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      );

  static RoundedRectangleBorder roundedButtonShape({double radius = 12}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static ButtonStyle primaryButton(Color bg) => ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        shape: roundedButtonShape(),
      );

  static ButtonStyle outlineButton(Color fg) => OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: fg),
        shape: roundedButtonShape(),
      );
}

class AppGaps {
  static const SizedBox h8 = SizedBox(height: 8);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h24 = SizedBox(height: 24);
  static const SizedBox w8 = SizedBox(width: 8);
  static const SizedBox w12 = SizedBox(width: 12);
}

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
