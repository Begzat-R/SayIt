import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme(Color textColor) {
  return TextTheme(
    // Display / headline — Epilogue (confident grotesque with editorial presence)
    displayLarge: GoogleFonts.epilogue(
      fontSize: 52,
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: -1.0,
      height: 1.05,
    ),
    displayMedium: GoogleFonts.epilogue(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: textColor,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    displaySmall: GoogleFonts.epilogue(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textColor,
      letterSpacing: -0.3,
      height: 1.15,
    ),
    headlineLarge: GoogleFonts.epilogue(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: textColor,
      letterSpacing: -0.2,
    ),
    headlineMedium: GoogleFonts.epilogue(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineSmall: GoogleFonts.epilogue(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    // Titles / body — Figtree (warm, geometric, readable)
    titleLarge: GoogleFonts.figtree(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleMedium: GoogleFonts.figtree(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleSmall: GoogleFonts.figtree(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.figtree(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textColor,
      height: 1.6,
    ),
    bodyMedium: GoogleFonts.figtree(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textColor,
      height: 1.55,
    ),
    bodySmall: GoogleFonts.figtree(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    labelLarge: GoogleFonts.figtree(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    labelMedium: GoogleFonts.figtree(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: textColor,
    ),
    labelSmall: GoogleFonts.figtree(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: textColor,
      letterSpacing: 0.5,
    ),
  );
}
