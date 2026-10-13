import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

/// Il Gorilla: una mascotte che perde peso con le serie che fai tu.
const double petPesoIniziale = 120;
const double petPesoObiettivo = 80;
const double petKgPerSerie = 0.08;
const int petSerieMaxGiorno = 40;
const double petKgRecuperatiAlGiorno = 0.35;
const int petGiorniDiGrazia = 2;

enum UmorePet { felice, contento, affamato, triste }

class StatoPet {
  final String nome;
  final DateTime inizio;
  final double peso;
  final double kgPersi; // netti rispetto al peso iniziale
  final double maxKgPersi; // il massimo raggiunto (non si perde)
  final double progresso; // 0..1 verso il peso obiettivo
  final double grasso; // 0 = scolpito, 1 = molto in carne (per il disegno)
  final UmorePet umore;
  final int giorniSenza;
  final int serieOggi;
  final String stadio;
  final String frase;

  const StatoPet({
    required this.nome,
    required this.inizio,
    required this.peso,
    required this.kgPersi,
    required this.maxKgPersi,
    required this.progresso,
    required this.grasso,
    required this.umore,
    required this.giorniSenza,
    required this.serieOggi,
    required this.stadio,
    required this.frase,
  });

  double get kgOggi => math.min(serieOggi, petSerieMaxGiorno) * petKgPerSerie;
}

class PetServizio {
  PetServizio._();

  static const _chiaveNome = 'pet_nome';
  static const _chiaveInizio = 'pet_inizio';
  static const _chiaveMax = 'pet_max_persi';

  static String _due(int n) => n.toString().padLeft(2, '0');
  static String _chiave(DateTime d) => '${d.year}-${_due(d.month)}-${_due(d.day)}';

  static Future<String> nome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chiaveNome) ?? 'Kong';
  }

  static Future<void> rinomina(String nuovo) async {
    final t = nuovo.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveNome, t);
  }

  static String stadioDa(double peso) {
    if (peso > 105) return 'Panciotto';
    if (peso > 95) return 'Tondetto';
    if (peso > 85) return 'In forma';
    if (peso > 80.5) return 'Quasi scolpito';
    return 'Gorilla Alpha';
  }

  static String _frase(UmorePet u, int serieOggi, int giorno) {
    const felici = [
      'Grazie! Ogni serie mi toglie un po\' di pancia!',
      'Che energia! Non fermarti adesso.',
      'Mi sento più leggero, continua così!',
    ];
    const contenti = [
      'Un\'altra serie e mi sento meglio...',
      'Dai, oggi ci alleniamo insieme?',
      'Ti aspetto in palestra!',
    ];
    const affamati = [
      'Ho fame di serie... e anche di banane.',
      'Sto rimettendo su un po\' di peso, aiutami!',
      'Mi sento pesante: facciamo qualcosa?',
    ];
    const tristi = [
      'Mi sono dimenticato com\'è fare una serie...',
      'Sto ingrassando... ho bisogno di te!',
      'Torna ad allenarti, ti prego!',
    ];
    final lista = switch (u) {
      UmorePet.felice => felici,
      UmorePet.contento => contenti,
      UmorePet.affamato => affamati,
      UmorePet.triste => tristi,
    };
    return lista[giorno % lista.length];
  }

  /// Calcola lo stato del Gorilla dalle serie registrate dal giorno in cui
  /// l'hai adottato: ogni serie lo fa dimagrire, i giorni di stop lo
  /// fanno rimettere su peso.
  static Future<StatoPet> stato() async {
    final prefs = await SharedPreferences.getInstance();
    final ora = DateTime.now();
    final oggi = DateTime(ora.year, ora.month, ora.day);

    var inizio = oggi;
    final salvato = prefs.getString(_chiaveInizio);
    if (salvato == null) {
      await prefs.setString(_chiaveInizio, _chiave(oggi));
    } else {
      inizio = DateTime.tryParse(salvato) ?? oggi;
    }

    final perGiorno = await DatabaseHelper.instance.getSeriePerGiorno(_chiave(inizio));

    var peso = petPesoIniziale;
    var inattivi = 0;
    DateTime? ultimoAttivo;
    var serieOggi = 0;
    for (var d = inizio; !d.isAfter(oggi); d = DateTime(d.year, d.month, d.day + 1)) {
      final n = math.min(perGiorno[_chiave(d)] ?? 0, petSerieMaxGiorno);
      if (d == oggi) serieOggi = perGiorno[_chiave(d)] ?? 0;
      if (n > 0) {
        peso -= n * petKgPerSerie;
        inattivi = 0;
        ultimoAttivo = d;
      } else if (d.isBefore(oggi)) {
        inattivi++;
        if (inattivi > petGiorniDiGrazia) peso += petKgRecuperatiAlGiorno;
      }
      peso = math.min(math.max(peso, petPesoObiettivo), petPesoIniziale + 10);
    }

    final kgPersi = petPesoIniziale - peso;
    final maxPrima = prefs.getDouble(_chiaveMax) ?? 0;
    final maxKg = math.max(maxPrima, kgPersi);
    if (maxKg > maxPrima) await prefs.setDouble(_chiaveMax, maxKg);

    final giorniSenza = oggi.difference(ultimoAttivo ?? inizio).inDays;
    UmorePet umore;
    if (serieOggi > 0 || giorniSenza <= 1) {
      umore = UmorePet.felice;
    } else if (giorniSenza == 2) {
      umore = UmorePet.contento;
    } else if (giorniSenza <= 4) {
      umore = UmorePet.affamato;
    } else {
      umore = UmorePet.triste;
    }

    final grasso = ((peso - petPesoObiettivo) / (petPesoIniziale - petPesoObiettivo)).clamp(0.0, 1.0).toDouble();
    final progresso = (1 - grasso).clamp(0.0, 1.0).toDouble();
    final giornoDellAnno = oggi.difference(DateTime(oggi.year, 1, 1)).inDays;

    return StatoPet(
      nome: prefs.getString(_chiaveNome) ?? 'Kong',
      inizio: inizio,
      peso: peso,
      kgPersi: kgPersi,
      maxKgPersi: maxKg,
      progresso: progresso,
      grasso: grasso,
      umore: umore,
      giorniSenza: giorniSenza,
      serieOggi: serieOggi,
      stadio: stadioDa(peso),
      frase: _frase(umore, serieOggi, giornoDellAnno),
    );
  }

  /// Il massimo di kg persi dal Gorilla (per le medaglie).
  static Future<double> maxKgPersi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_chiaveMax) ?? 0;
  }
}
