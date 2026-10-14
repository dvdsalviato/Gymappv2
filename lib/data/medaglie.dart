import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'statistiche.dart';

class Medaglia {
  final String id;
  final String titolo;
  final String descrizione;
  final IconData icona;
  final int soglia;
  final String tipo;
  final String tier; // bronzo | argento | oro | platino

  const Medaglia(this.id, this.titolo, this.descrizione, this.icona, this.soglia, this.tipo, this.tier);
}

Color coloreTier(String tier) {
  switch (tier) {
    case 'bronzo':
      return const Color(0xFFCD7F32);
    case 'argento':
      return const Color(0xFFC9D1D9);
    case 'oro':
      return const Color(0xFFFFC83D);
    default:
      return const Color(0xFF5EE6D8);
  }
}

const List<Medaglia> medaglie = [
  // Allenamenti
  Medaglia('primo', 'Si parte', 'Il tuo primo allenamento', Icons.flag, 1, 'allenamenti', 'bronzo'),
  Medaglia('dieci', 'Costanza', '10 allenamenti', Icons.local_fire_department, 10, 'allenamenti', 'bronzo'),
  Medaglia('venticinque', 'In forma', '25 allenamenti', Icons.bolt, 25, 'allenamenti', 'argento'),
  Medaglia('cinquanta', 'Veterano', '50 allenamenti', Icons.military_tech, 50, 'allenamenti', 'oro'),
  Medaglia('cento', 'Leggenda', '100 allenamenti', Icons.emoji_events, 100, 'allenamenti', 'platino'),
  // Serie
  Medaglia('serie100', 'Cento serie', '100 serie fatte', Icons.fitness_center, 100, 'serie', 'bronzo'),
  Medaglia('serie500', 'Cinquecento', '500 serie fatte', Icons.fitness_center, 500, 'serie', 'argento'),
  Medaglia('serie1000', 'Mille serie', '1000 serie fatte', Icons.fitness_center, 1000, 'serie', 'oro'),
  Medaglia('serie2500', 'Macchina da serie', '2500 serie fatte', Icons.fitness_center, 2500, 'serie', 'platino'),
  // Costanza
  Medaglia('sett2', 'Doppietta', '2 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 2, 'settimane', 'bronzo'),
  Medaglia('sett4', 'Un mese di ferro', '4 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 4, 'settimane', 'argento'),
  Medaglia('sett8', 'Inarrestabile', '8 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 8, 'settimane', 'oro'),
  Medaglia('sett12', 'Trimestre perfetto', '12 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 12, 'settimane', 'platino'),
  Medaglia('sett52', 'Un anno intero', '52 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 52, 'settimane', 'platino'),
  Medaglia('mese12', 'Mese pieno', '12 allenamenti in un solo mese', Icons.date_range, 12, 'mese', 'argento'),
  Medaglia('weekend', 'Guerriero del weekend', 'Allenati sia sabato sia domenica', Icons.weekend, 1, 'weekend', 'argento'),
  // Volume totale
  Medaglia('vol10', 'Sollevatore', '10 tonnellate sollevate in totale', Icons.scale, 10000, 'volume', 'bronzo'),
  Medaglia('vol100', 'Camion di ghisa', '100 tonnellate sollevate in totale', Icons.scale, 100000, 'volume', 'oro'),
  Medaglia('vol500', 'Montagna', '500 tonnellate sollevate in totale', Icons.landscape, 500000, 'volume', 'platino'),
  // Record
  Medaglia('rec1', 'Record!', 'Batti il tuo primo record di carico', Icons.trending_up, 1, 'record', 'bronzo'),
  Medaglia('rec10', 'Cacciatore di record', '10 record di carico battuti', Icons.trending_up, 10, 'record', 'argento'),
  Medaglia('rec50', 'Sempre più su', '50 record di carico battuti', Icons.trending_up, 50, 'record', 'oro'),
  // Abitudini e varietà
  Medaglia('mattina', 'Mattiniero', 'Allenati prima delle 7 del mattino', Icons.wb_twilight, 1, 'mattina', 'bronzo'),
  Medaglia('sera', 'Nottambulo', 'Allenati dopo le 22', Icons.nightlight_round, 1, 'sera', 'bronzo'),
  Medaglia('tempo10', 'Fiato d\'acciaio', '10 serie a tempo', Icons.timer, 10, 'tempo', 'bronzo'),
  Medaglia('tempo50', 'Resistenza', '50 serie a tempo', Icons.timer, 50, 'tempo', 'argento'),
  Medaglia('muscoli8', 'Corpo intero', 'Allena 8 muscoli diversi in una settimana', Icons.accessibility_new, 8, 'muscoli', 'argento'),
  Medaglia('muscoli12', 'Tutto il corpo', 'Allena tutti i 12 muscoli in una settimana', Icons.accessibility_new, 12, 'muscoli', 'oro'),
  Medaglia('var10', 'Curioso', '10 esercizi diversi provati', Icons.explore, 10, 'varieta', 'bronzo'),
  Medaglia('var30', 'Esploratore', '30 esercizi diversi provati', Icons.explore, 30, 'varieta', 'argento'),
  Medaglia('schede1', 'Il piano', 'Crea la tua prima scheda', Icons.assignment, 1, 'schede', 'bronzo'),
  Medaglia('schede5', 'Programmatore', 'Crea 5 schede', Icons.assignment, 5, 'schede', 'argento'),
  Medaglia('gambe10', 'Giorno gambe', '10 allenamenti con le gambe', Icons.directions_run, 10, 'gruppo:gambe', 'bronzo'),
  Medaglia('gambe30', 'Mai saltare il leg day', '30 allenamenti con le gambe', Icons.directions_run, 30, 'gruppo:gambe', 'argento'),
  // Corpo e amici
  Medaglia('peso1', 'Sulla bilancia', 'Registra il tuo primo peso', Icons.monitor_weight, 1, 'pesi', 'bronzo'),
  Medaglia('peso10', 'Controllo costante', '10 pesi registrati', Icons.monitor_weight, 10, 'pesi', 'argento'),
  Medaglia('peso30', 'Occhio alla bilancia', '30 pesi registrati', Icons.monitor_weight, 30, 'pesi', 'oro'),
  Medaglia('amico1', 'In compagnia', 'Aggiungi il tuo primo amico', Icons.group, 1, 'amici', 'bronzo'),
  Medaglia('amici5', 'Squadra', '5 amici in palestra', Icons.groups, 5, 'amici', 'argento'),
];

int valoreMedaglia(Medaglia m, StatisticheUtente s) {
  if (m.tipo.startsWith('gruppo:')) return s.giorniGruppo[m.tipo.substring(7)] ?? 0;
  switch (m.tipo) {
    case 'allenamenti':
      return s.allenamenti;
    case 'serie':
      return s.serie;
    case 'settimane':
      return s.settimane;
    case 'pesi':
      return s.pesi;
    case 'volume':
      return s.volumeKg.round();
    case 'record':
      return s.record;
    case 'mattina':
      return s.mattiniero;
    case 'sera':
      return s.nottambulo;
    case 'tempo':
      return s.serieATempo;
    case 'muscoli':
      return s.muscoliSettimana;
    case 'amici':
      return s.amici;
    case 'varieta':
      return s.eserciziDiversi;
    case 'schede':
      return s.schede;
    case 'mese':
      return s.maxMese;
    case 'weekend':
      return s.weekend;
  }
  return 0;
}

const _chiaveSbloccate = 'medaglie_sbloccate';

class EsitoMedaglie {
  final Set<String> sbloccate;
  final List<Medaglia> nuove;
  const EsitoMedaglie(this.sbloccate, this.nuove);
}

/// Calcola le medaglie raggiunte, le ricorda (una medaglia non si perde
/// anche se poi la serie si interrompe) e dice quali sono nuove.
Future<EsitoMedaglie> aggiornaMedaglie(StatisticheUtente s) async {
  final prefs = await SharedPreferences.getInstance();
  // Si scartano gli id di medaglie che non esistono più (es. rango e gorilla).
  final validi = medaglie.map((m) => m.id).toSet();
  final salvate = prefs.getStringList(_chiaveSbloccate) ?? <String>[];
  final prima = salvate.where(validi.contains).toSet();
  final ora = Set<String>.of(prima);
  final nuove = <Medaglia>[];
  for (final m in medaglie) {
    if (valoreMedaglia(m, s) >= m.soglia && !ora.contains(m.id)) {
      ora.add(m.id);
      nuove.add(m);
    }
  }
  if (nuove.isNotEmpty || prima.length != salvate.length) {
    await prefs.setStringList(_chiaveSbloccate, ora.toList());
  }
  return EsitoMedaglie(ora, nuove);
}
