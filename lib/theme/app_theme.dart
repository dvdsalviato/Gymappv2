import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF2F2F5);
  static const card = Colors.white;
  static const accento = Color(0xFF39FF14);
  static const grigioChip = Color(0xFFEDEDF0);

  static const backgroundScuro = Color(0xFF0A0A0C);
  static const cardScuro = Color(0xFF151519);
  static const grigioChipScuro = Color(0xFF212126);
}

Color coloreCard(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.cardScuro : AppColors.card;

Color coloreChip(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.grigioChipScuro : AppColors.grigioChip;

const _transizioniFluide = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

TextTheme _testi(Color colore, Brightness b) {
  final base = ThemeData(brightness: b)
      .textTheme
      .apply(bodyColor: colore, displayColor: colore);
  final corpo = GoogleFonts.barlowTextTheme(base);
  return corpo.copyWith(
    headlineSmall: GoogleFonts.oswald(
        textStyle: corpo.headlineSmall, fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.oswald(
        textStyle: corpo.titleLarge, fontWeight: FontWeight.w600, letterSpacing: 0.6),
    titleMedium: GoogleFonts.oswald(
        textStyle: corpo.titleMedium, fontWeight: FontWeight.w500, letterSpacing: 0.4),
    labelLarge: GoogleFonts.oswald(
        textStyle: corpo.labelLarge, fontWeight: FontWeight.w500, letterSpacing: 0.8),
  );
}

ThemeData _costruisci({
  required Brightness b,
  required Color sfondo,
  required Color card,
  required Color chip,
  required Color testo,
  required Color hint,
  required double opacitaIndicatore,
}) {
  final testi = _testi(testo, b);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: sfondo,
    pageTransitionsTheme: _transizioniFluide,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accento,
      brightness: b,
      primary: AppColors.accento,
      onPrimary: Colors.black,
      surface: card,
    ),
    textTheme: testi,
    appBarTheme: AppBarTheme(
      backgroundColor: sfondo,
      foregroundColor: testo,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accento,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.oswald(
            fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: chip,
      hintStyle: TextStyle(color: hint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: AppColors.accento.withOpacity(opacitaIndicatore),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.oswald(
            fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: testo),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: card),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accento,
      foregroundColor: Colors.black,
      shape: CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.accento,
      contentTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accento),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.black : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accento : null,
      ),
    ),
  );
}

ThemeData buildLightTheme() => _costruisci(
      b: Brightness.light,
      sfondo: AppColors.background,
      card: AppColors.card,
      chip: AppColors.grigioChip,
      testo: Colors.black,
      hint: Colors.grey.shade400,
      opacitaIndicatore: 0.35,
    );

ThemeData buildDarkTheme() => _costruisci(
      b: Brightness.dark,
      sfondo: AppColors.backgroundScuro,
      card: AppColors.cardScuro,
      chip: AppColors.grigioChipScuro,
      testo: Colors.white,
      hint: Colors.grey.shade600,
      opacitaIndicatore: 0.25,
    );
