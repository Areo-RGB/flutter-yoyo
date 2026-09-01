import 'package:flutter/material.dart';

/// Maps the default roster's first names to the corresponding portrait file.
///
/// The roster stores first names for its built-in athletes while the supplied
/// files use full names, so the lookup intentionally uses the first token.
const Map<String, String> _avatarAssetsByFirstName = {
  'alex': 'assets/avatars/Alex_Moore.png',
  'arturo': 'assets/avatars/Arturo_Montes_Hernandez.png',
  'arvid': 'assets/avatars/Arvid_Lorenz.png',
  'finley': 'assets/avatars/Finley_Charlier.png',
  'jakob': 'assets/avatars/Jakob_Merkle.png',
  'lasse': 'assets/avatars/Lasse_Schmidt.png',
  'lennox': 'assets/avatars/Lennox_Niemann.png',
  'levi': 'assets/avatars/Levi_Petko.png',
  'lion': 'assets/avatars/Lion_Macak.png',
  'lionel': 'assets/avatars/Lionel.png',
  'milan': 'assets/avatars/Milan_Wekiaroglou.png',
  'paul': 'assets/avatars/Paul_Miethe.png',
  'peter': 'assets/avatars/Peter_Grelle.png',
  'silas': 'assets/avatars/Silas_Aldenhoff.png',
  'tayo': 'assets/avatars/Tayo_Mohammed.png',
  'tommy': 'assets/avatars/Tommy.png',
};

/// Returns the supplied portrait asset for [name], or null when none exists.
String? athleteAvatarAssetPath(String name) {
  final firstName = name.trim().split(RegExp(r'\s+')).firstOrNull;
  if (firstName == null || firstName.isEmpty) return null;
  return _avatarAssetsByFirstName[firstName.toLowerCase()];
}

class AthleteAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color backgroundColor;
  final TextStyle fallbackStyle;

  const AthleteAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.backgroundColor,
    this.fallbackStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  });

  String _getInitials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    final nonEmptyParts = parts.where((part) => part.isNotEmpty).toList();
    if (nonEmptyParts.isEmpty) return '?';
    if (nonEmptyParts.length == 1) {
      return nonEmptyParts.first.substring(0, 1).toUpperCase();
    }
    return '${nonEmptyParts[0].substring(0, 1)}${nonEmptyParts[1].substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = athleteAvatarAssetPath(name);
    final diameter = radius * 2;
    final fallback = Text(_getInitials(name), style: fallbackStyle);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: assetPath == null
          ? fallback
          : ClipOval(
              child: Image.asset(
                assetPath,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}
