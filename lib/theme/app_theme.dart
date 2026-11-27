import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

/// Un colore dell'app: variante per il tema scuro e per quello chiaro.
/// Le varianti chiare sono scure abbastanza da leggersi sul bianco e da
/// reggere il testo nero sopra (contrasto ≥ 4:1 in entrambi i casi).
class ColoreApp {
  final String nome;
  final Color scuro;
  final Color chiaro;
  const ColoreApp(this.nome, this.scuro, this.chiaro);
}

const List<ColoreApp> paletteApp = [
  ColoreApp('Lime', Color(0xFFA3E635), Color(0xFF5B8C13)),
  ColoreApp('Verde fluo', Color(0xFF39FF14), Color(0xFF1E8F0A)),
  ColoreApp('Menta', Color(0xFF34D399), Color(0xFF0E8A5F)),
  ColoreApp('Azzurro', Color(0xFF38BDF8), Color(0xFF0B7AB8)),
  ColoreApp('Arancio', Color(0xFFFB923C), Color(0xFFD35400)),
];

/// Indice che indica "colore scelto con il cerchio".
const int indiceColorePersonalizzato = 5;

ColoreApp get coloreAppAttuale {
  final i = ThemeController.colore.value;
  if (i == indiceColorePersonalizzato) return coloreDaBase(Color(ThemeController.personalizzato.value));
  return paletteApp[(i >= 0 && i < paletteApp.length) ? i : 0];
}

double _contrasto(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Da un colore qualsiasi ricava le due varianti leggibili:
/// - tema scuro: schiarito finché il testo nero sopra si legge bene;
/// - tema chiaro: la luminosità che si legge sia sul bianco sia col testo nero.
ColoreApp coloreDaBase(Color base) {
  final hsl = HSLColor.fromColor(base);
  Color conLuce(double l) => hsl.withLightness(math.min(1.0, math.max(0.0, l))).toColor();

  var scuro = conLuce(hsl.lightness);
  for (var l = hsl.lightness; l <= 0.96; l += 0.02) {
    scuro = conLuce(l);
    if (_contrasto(scuro, Colors.black) >= 8 && _contrasto(scuro, const Color(0xFF151519)) >= 6) break;
  }

  var chiaro = conLuce(0.35);
  var migliore = 0.0;
  for (var l = 0.15; l <= 0.65; l += 0.01) {
    final c = conLuce(l);
    final m = math.min(_contrasto(c, Colors.white), _contrasto(c, Colors.black));
    if (m > migliore) {
      migliore = m;
      chiaro = c;
    }
  }
  return ColoreApp('Personalizzato', scuro, chiaro);
}

class AppColors {
  static const background = Color(0xFFF2F2F5);
  static const card = Colors.white;

  /// Verde fluo del tema scuro.
  static const neon = Color(0xFF39FF14);

  /// Verde più profondo per il tema chiaro: il fluo su bianco non si leggeva
  /// (contrasto 1,4:1), questo arriva a 4,2:1 e regge il testo nero sopra.
  static const verdeChiaro = Color(0xFF1E8F0A);

  /// Colore principale dell'app: quello scelto, adattato al tema attivo.
  static Color get accento => ThemeController.modalita.value == ThemeMode.light
      ? coloreAppAttuale.chiaro
      : coloreAppAttuale.scuro;
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

/// Raggio degli angoli dei pannelli: squadrati il giusto, non "a bolla".
const double raggioPannello = 12;

/// Fondo dei pannelli: leggera sfumatura (luce dall'alto a sinistra) e un
/// filo di bordo, invece del riquadro piatto molto arrotondato.
BoxDecoration pannello(BuildContext context, {double raggio = raggioPannello, Color? bordo}) {
  final scuro = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(raggio),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: scuro
          ? const [Color(0xFF1F1F26), Color(0xFF15151A)]
          : const [Colors.white, Color(0xFFF8F8FA)],
    ),
    border: Border.all(
      color: bordo ?? (scuro ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.07)),
    ),
  );
}

/// Titolo di sezione: tacca colorata + testo spaziato in maiuscolo.
class TitoloSezione extends StatelessWidget {
  final String testo;
  final Widget? azione;
  final EdgeInsetsGeometry padding;
  const TitoloSezione(this.testo, {super.key, this.azione, this.padding = const EdgeInsets.only(bottom: 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(width: 3, height: 13, color: AppColors.accento),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              testo.toUpperCase(),
              style: GoogleFonts.oswald(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 1.6,
              ),
            ),
          ),
          if (azione != null) azione!,
        ],
      ),
    );
  }
}

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
  final accento = b == Brightness.dark ? coloreAppAttuale.scuro : coloreAppAttuale.chiaro;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.oswald(
          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: testo),
      contentTextStyle: GoogleFonts.barlow(fontSize: 15, height: 1.4, color: testo.withValues(alpha: 0.8)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w600, color: testo),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raggioPannello)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accento,
        textStyle: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.6),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: testo.withValues(alpha: 0.16)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: DividerThemeData(color: testo.withValues(alpha: 0.08), thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accento,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
