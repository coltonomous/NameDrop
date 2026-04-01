import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NameDropTheme {
  // Core palette
  static const navy = Color(0xFF0A1628);
  static const royalBlue = Color(0xFF162D50);
  static const panelBlue = Color(0xFF1B3A5C);
  static const gold = Color(0xFFFFD54F);
  static const brightGold = Color(0xFFFFE082);
  static const hotCoral = Color(0xFFFF6B6B);
  static const mintGreen = Color(0xFF69F0AE);
  static const cream = Color(0xFFFFF8E1);
  static const dimGold = Color(0x80FFD54F);

  static ThemeData build() {
    final headlineFont = GoogleFonts.bangers();
    final bodyFont = GoogleFonts.outfit();

    return ThemeData(
      scaffoldBackgroundColor: navy,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: hotCoral,
        tertiary: mintGreen,
        surface: panelBlue,
        onPrimary: navy,
        onSecondary: Colors.white,
        onSurface: cream,
        outline: dimGold,
      ),
      textTheme: TextTheme(
        displayLarge: headlineFont.copyWith(
          fontSize: 64,
          color: gold,
          letterSpacing: 4,
        ),
        displayMedium: headlineFont.copyWith(
          fontSize: 48,
          color: gold,
          letterSpacing: 3,
        ),
        headlineMedium: headlineFont.copyWith(
          fontSize: 32,
          color: gold,
          letterSpacing: 2,
        ),
        titleLarge: headlineFont.copyWith(
          fontSize: 24,
          color: gold,
          letterSpacing: 1.5,
        ),
        titleMedium: bodyFont.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cream,
        ),
        titleSmall: bodyFont.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: brightGold,
        ),
        bodyLarge: bodyFont.copyWith(fontSize: 16, color: cream),
        bodyMedium: bodyFont.copyWith(fontSize: 14, color: cream),
        bodySmall: bodyFont.copyWith(fontSize: 12, color: brightGold),
        labelSmall: bodyFont.copyWith(fontSize: 11, color: cream),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headlineFont.copyWith(
          fontSize: 28,
          color: gold,
          letterSpacing: 2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navy,
          textStyle: headlineFont.copyWith(
            fontSize: 20,
            letterSpacing: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brightGold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: royalBlue,
        hintStyle: bodyFont.copyWith(color: dimGold),
        errorStyle: bodyFont.copyWith(color: hotCoral, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dimGold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dimGold),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: hotCoral),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: hotCoral,
        contentTextStyle: bodyFont.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: royalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  static BoxDecoration get panelDecoration => BoxDecoration(
        color: panelBlue,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dimGold, width: 1.5),
      );

  static BoxDecoration get completedPanelDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mintGreen, width: 1.5),
      );

  static BoxDecoration get partialPanelDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A1942), Color(0xFF6A1B6A)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hotCoral, width: 1.5),
      );

  static BoxDecoration get freePanelDecoration => BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x40FFD54F), width: 1),
      );
}
