import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class LivelloRango {
  final String nome;
  final Color colore;
  const LivelloRango(this.nome, this.colore);
}

const List<LivelloRango> livelliRango = [
  LivelloRango('Ferro', Color(0xFF8E9399)),
  LivelloRango('Bronzo', Color(0xFFCD7F32)),
  LivelloRango('Argento', Color(0xFFC9D1D9)),
  LivelloRango('Oro', Color(0xFFFFC83D)),
  LivelloRango('Platino', Color(0xFF5EE6D8)),
  LivelloRango('Diamante', Color(0xFF6AA7FF)),
  LivelloRango('Leggenda', Color(0xFFC77DFF)),
];

class Alzata {
  final String id;
  final String nome;
  final List<String> parole;
  final List<String> escludi;

  /// Rapporto massimale stimato / peso corporeo da raggiungere per
  /// Bronzo, Argento, Oro, Platino, Diamante, Leggenda (valori indicativi).
  final List<double> soglie;

  const Alzata(this.id, this.nome, this.parole, this.escludi, this.soglie);
}

const List<Alzata> alzatePrincipali = [
  Alzata('panca', 'Panca piana', ['panca piana', 'bench press'], ['manubri', 'presa stretta'],
      [0.50, 0.75, 1.25, 1.75, 2.00, 2.40]),
  Alzata('squat', 'Squat', ['squat con bilanciere', 'back squat'], [],
      [0.75, 1.25, 1.75, 2.25, 2.75, 3.30]),
  Alzata('stacco', 'Stacco da terra', ['stacco da terra', 'stacco sumo', 'deadlift'], ['rumeno', 'manubri'],
      [1.00, 1.50, 2.00, 2.50, 3.00, 3.60]),
  Alzata('military', 'Military press', ['military press', 'overhead press', 'lento avanti'], ['manubri'],
      [0.35, 0.55, 0.80, 1.10, 1.40, 1.70]),
  Alzata('rematore', 'Rematore con bilanciere', ['rematore con bilanciere', 'barbell row', 'rematore yates'], [],
      [0.50, 0.75, 1.10, 1.50, 1.85, 2.20]),
];

class RisultatoAlzata {
  final Alzata alzata;
  final double? e1rm;
  final double? rapporto;
  final int livello; // 0..6
  final double progresso; // 0..1 verso il livello successivo
  final double? kgProssimo; // massimale stimato necessario per il livello successivo

  const RisultatoAlzata({
    required this.alzata,
    required this.e1rm,
    required this.rapporto,
    required this.livello,
    required this.progresso,
    required this.kgProssimo,
  });
}

class RangoStato {
  final double? peso;
  final bool donna;
  final List<RisultatoAlzata> alzate;
  final int livelloGenerale; // 0..6
  final double progressoGenerale; // 0..1
  final int alzateConDati;

  const RangoStato({
    required this.peso,
    required this.donna,
    required this.alzate,
    required this.livelloGenerale,
    required this.progressoGenerale,
    required this.alzateConDati,
  });

  LivelloRango get livello => livelliRango[livelloGenerale];
  LivelloRango? get prossimo => livelloGenerale >= livelliRango.length - 1 ? null : livelliRango[livelloGenerale + 1];
}

/// Calcola il rango dai massimali stimati delle alzate principali, in
/// rapporto al peso corporeo. Sono soglie indicative, pensate per il gioco.
Future<RangoStato> calcolaRango() async {
  final db = DatabaseHelper.instance;
  final pesi = await db.getPesi();
  final profilo = await db.getProfilo();
  double? peso;
  if (pesi.isNotEmpty) {
    peso = (pesi.last['peso_kg'] as num).toDouble();
  } else {
    peso = (profilo?['peso_kg'] as num?)?.toDouble();
  }
  if (peso != null && peso <= 0) peso = null;
  final sesso = ((profilo?['sesso'] as String?) ?? '').toLowerCase();
  final donna = sesso.startsWith('d') || sesso.startsWith('f');
  final fattore = donna ? 0.65 : 1.0;

  final righe = await db.getE1rmPerEsercizio();
  final risultati = <RisultatoAlzata>[];
  for (final a in alzatePrincipali) {
    double? migliore;
    for (final r in righe) {
      final nome = (r['nome'] as String).toLowerCase();
      if (!a.parole.any(nome.contains)) continue;
      if (a.escludi.any(nome.contains)) continue;
      final v = (r['e1rm'] as num?)?.toDouble();
      if (v != null && (migliore == null || v > migliore)) migliore = v;
    }
    if (migliore == null || peso == null) {
      risultati.add(RisultatoAlzata(
        alzata: a,
        e1rm: migliore,
        rapporto: null,
        livello: 0,
        progresso: 0,
        kgProssimo: null,
      ));
      continue;
    }
    final rapporto = migliore / peso / fattore;
    var livello = 0;
    for (var i = 0; i < a.soglie.length; i++) {
      if (rapporto >= a.soglie[i]) livello = i + 1;
    }
    double progresso = 1;
    double? kgProssimo;
    if (livello < a.soglie.length) {
      final sotto = livello == 0 ? 0.0 : a.soglie[livello - 1];
      final sopra = a.soglie[livello];
      progresso = ((rapporto - sotto) / (sopra - sotto)).clamp(0.0, 1.0).toDouble();
      kgProssimo = sopra * peso * fattore;
    }
    risultati.add(RisultatoAlzata(
      alzata: a,
      e1rm: migliore,
      rapporto: rapporto,
      livello: livello,
      progresso: progresso,
      kgProssimo: kgProssimo,
    ));
  }

  final conDati = risultati.where((r) => r.rapporto != null).toList();
  var generale = 0;
  var progGenerale = 0.0;
  if (conDati.isNotEmpty) {
    final media = conDati.map((r) => r.livello + r.progresso).reduce((a, b) => a + b) / conDati.length;
    generale = media.floor().clamp(0, livelliRango.length - 1);
    progGenerale = generale >= livelliRango.length - 1 ? 1.0 : (media - generale).clamp(0.0, 1.0).toDouble();
  }
  return RangoStato(
    peso: peso,
    donna: donna,
    alzate: risultati,
    livelloGenerale: generale,
    progressoGenerale: progGenerale,
    alzateConDati: conDati.length,
  );
}
