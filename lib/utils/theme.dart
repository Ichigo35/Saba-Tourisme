import 'package:flutter/material.dart';

/// Palette inspirée du Laos et du voyage : rouge profond, or/safran, fond
/// crème chaleureux. Contraste élevé, pensé pour rester lisible en extérieur
/// et par des utilisateurs peu familiers des interfaces complexes (point 18).
class AppColors {
  static const primary = Color(0xFFB0212F); // rouge profond (drapeau lao)
  static const primaryDark = Color(0xFF7A1620);
  static const accent = Color(0xFFE0A526); // or / safran
  static const background = Color(0xFFFFF8EC); // crème
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF2B1B12);
  static const textMuted = Color(0xFF6B5B4D);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB05A00);
  static const danger = Color(0xFFC62828);
}

/// Polices : NotoSans pour le français, NotoSansLao pour le lao — assure un
/// rendu correct du script lao sur tous les appareils Android, y compris
/// hors-ligne (pas de dépendance à une police système ou téléchargée).
class AppFonts {
  static const french = 'NotoSans';
  static const lao = 'NotoSansLao';
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.french,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.french,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts.french,
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
  );
}
