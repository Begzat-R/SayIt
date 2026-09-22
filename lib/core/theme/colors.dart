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

  // Situation category tags (community post pills, Situations list) —
  // Everyday reuses [gold], Social reuses [primary]; Work needed a third hue.
  static const categoryWork = Color(0xFF4C7A57); // muted green

  // [primary] and [categoryWork] are tuned as near-black/dark hues for
  // legibility as TEXT on the light background — used as-is, that same
  // darkness reads as near-invisible against the dark theme's near-black
  // background (measured contrast ~1.4:1 and ~3.8:1 respectively, both
  // under the 4.5:1 AA floor for small text). [gold] is already light/warm
  // enough to clear 4.5:1 on both backgrounds, so it has no dark variant.
  static const primaryOnDark = Color(0xFF8B85C4); // lighter periwinkle
  static const categoryWorkOnDark = Color(0xFF7FB88F); // lighter sage

  // Theme-correct color for a situation category label/tag's foreground.
  static Color categoryColor(BuildContext context, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (category) {
      case 'Everyday':
        return gold;
      case 'Work':
        return isDark ? categoryWorkOnDark : categoryWork;
      case 'Social':
      default:
        return isDark ? primaryOnDark : primary;
    }
  }

  // [primary], used as an icon/accent color (not a button fill) outside the
  // category system — e.g. the breathing-exercise banner. Same dark-mode
  // legibility problem and same fix as categoryColor's Social case.
  static Color primaryAccent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? primaryOnDark : primary;

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
