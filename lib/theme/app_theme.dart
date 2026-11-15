import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

class AppColors {
  static const background = Color(0xFFF2F2F5);
  static const card = Colors.white;

  /// Verde fluo del tema scuro.
  static const neon = Color(0xFF39FF14);

  /// Verde più profondo per il tema chiaro: il fluo su bianco non si leggeva
  /// (contrasto 1,4:1), questo arriva a 4,2:1 e regge il testo nero sopra.
  static const verdeChiaro = Color(0xFF1E8F0A);

  /// Colore principale dell'app, adattato al tema attivo.
  static Color get accento =>
      ThemeController.modalita.value == ThemeMode.light ? verdeChiaro : neon;
  static const grigioChip = Color(0xFFEDEDF0);

  static const backgroundScuro = Color(0xFF0A0A0C);
  static const cardScuro = Color(0xFF151519);
  static const grigioChipScuro = Color(0xFF212126);
}

Color coloreCard(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.cardScuro : AppColors.card;

Color coloreChip(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.grigioChipScuro : AppColors.grigioChip;

/// Colore delle card "rialzate" (un grigio-nero leggermente più chiaro dello sfondo).
Color coloreSuperficie(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E24) : Colors.white;

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
  required Color superficie,
}) {
  final testi = _testi(testo, b);
  final accento = b == Brightness.dark ? AppColors.neon : AppColors.verdeChiaro;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: sfondo,
    pageTransitionsTheme: _transizioniFluide,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accento,
      brightness: b,
      primary: accento,
      onPrimary: Colors.black,
      surface: card,
    ),
    textTheme: testi,
    appBarTheme: AppBarTheme(
      backgroundColor: sfondo,
      foregroundColor: testo,
      elevation: 0,
      // Niente velatura colorata quando il contenuto scorre sotto la barra.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.oswald(
          fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: testo),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: GoogleFonts.oswald(
          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: testo),
      contentTextStyle: GoogleFonts.barlow(fontSize: 15, height: 1.4, color: testo.withValues(alpha: 0.8)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w600, color: testo),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accento,
        textStyle: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.6),
      ),
    ),
    dividerTheme: DividerThemeData(color: testo.withValues(alpha: 0.08), thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accento,
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
      indicatorColor: accento.withValues(alpha: opacitaIndicatore),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.oswald(
            fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: testo),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: card),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accento,
      foregroundColor: Colors.black,
      shape: CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: accento,
      contentTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accento),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.black : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accento : null,
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
      superficie: Colors.white,
    );

ThemeData buildDarkTheme() => _costruisci(
      b: Brightness.dark,
      sfondo: AppColors.backgroundScuro,
      card: AppColors.cardScuro,
      chip: AppColors.grigioChipScuro,
      testo: Colors.white,
      hint: Colors.grey.shade600,
      opacitaIndicatore: 0.25,
      superficie: const Color(0xFF1E1E24),
    );
