import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const backgroundLight = Color(0xFFFAF9F6); // warm off-white
  static const backgroundDark = Color(0xFF111111);

  // Primary accent — deep indigo
  static const primary = Color(0xFF2D2A4A);

  // Gold — completions, rewards
  static const gold = Color(0xFFC9A84C);

  // Like (heart) icon — liked state only. Reads as "liked" against the
  // ivory background without clashing with the error red.
  static const like = Color(0xFFE0434B);

  // Error
  static const error = Color(0xFF9B2335);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0x8C1A1A1A); // ~55% opacity
  static const textPrimaryDark = Color(0xFFEFEDE6);
  static const textSecondaryDark = Color(0x8CEFEDE6);

  // Surfaces
  static const surfaceLight = Color(0xFFFDFCFA);
  static const surfaceDark = Color(0xFF1A1A1A);

  // Borders — 12% opacity
  static const borderLight = Color(0x1E1A1A1A);
  static const borderDark = Color(0x1EEFEDE6);

  // Context-aware helpers
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceMuted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

  static Color cardSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;

  // Soft diffused shadow — blur > spread, low opacity
  static List<BoxShadow> softShadow() => [
        BoxShadow(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}
