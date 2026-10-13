import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors sampled from the Figma prototype screenshots. Adjust here and every screen follows.
class AppColors {
  static const bg = Color(0xFF11131E);
  static const surface = Color(0xFF1C2038);
  static const surfaceAlt = Color(0xFF252A44);
  static const border = Color(0xFF2B3050);
  static const gold = Color(0xFFDFB562);
  static const goldDisabled = Color(0xFF665636);
  static const onGold = Color(0xFF11131E);
  static const text = Color(0xFFF5F2EA);
  static const muted = Color(0xFF9EA3BC);
  static const hint = Color(0xFF6B708A);
  static const green = Color(0xFF63A68A);
  static const error = Color(0xFFE5736B);
}

/// Serif for headings, Figtree for everything else. Swap the font calls if the design uses others.
class AppText {
  static TextStyle heading([double size = 30]) => GoogleFonts.sourceSerif4(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    height: 1.15,
  );

  static TextStyle body([
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
  ]) => GoogleFonts.figtree(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.35,
  );
}

OutlineInputBorder _outline(Color c) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(20),
  borderSide: BorderSide(color: c, width: 1.2),
);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final textTheme = GoogleFonts.figtreeTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.onGold,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.error,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.heading(22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: AppText.body(16, FontWeight.w500, AppColors.hint),
      errorStyle: AppText.body(13, FontWeight.w500, AppColors.error),
      border: _outline(AppColors.border),
      enabledBorder: _outline(AppColors.border),
      disabledBorder: _outline(AppColors.border),
      focusedBorder: _outline(AppColors.gold),
      errorBorder: _outline(AppColors.error),
      focusedErrorBorder: _outline(AppColors.error),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.gold,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceAlt,
      contentTextStyle: AppText.body(15),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
