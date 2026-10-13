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
  Medaglia('duecentocinquanta', 'Titano', '250 allenamenti', Icons.workspace_premium, 250, 'allenamenti', 'platino'),
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
  // Volume sollevato
  Medaglia('vol10', 'Sollevatore', '10 tonnellate sollevate in totale', Icons.scale, 10000, 'volume', 'bronzo'),
  Medaglia('vol50', 'Gru umana', '50 tonnellate sollevate in totale', Icons.scale, 50000, 'volume', 'argento'),
  Medaglia('vol100', 'Camion di ghisa', '100 tonnellate sollevate in totale', Icons.scale, 100000, 'volume', 'oro'),
  Medaglia('vol500', 'Montagna', '500 tonnellate sollevate in totale', Icons.landscape, 500000, 'volume', 'platino'),
  // Record
  Medaglia('rec1', 'Record!', 'Batti il tuo primo record di carico', Icons.trending_up, 1, 'record', 'bronzo'),
  Medaglia('rec10', 'Cacciatore di record', '10 record di carico battuti', Icons.trending_up, 10, 'record', 'argento'),
  Medaglia('rec50', 'Sempre più su', '50 record di carico battuti', Icons.trending_up, 50, 'record', 'oro'),
  // Abitudini
  Medaglia('mattina', 'Mattiniero', 'Allenati prima delle 7 del mattino', Icons.wb_twilight, 1, 'mattina', 'bronzo'),
  Medaglia('sera', 'Nottambulo', 'Allenati dopo le 22', Icons.nightlight_round, 1, 'sera', 'bronzo'),
  Medaglia('tempo10', 'Fiato d\'acciaio', '10 serie a tempo', Icons.timer, 10, 'tempo', 'bronzo'),
  Medaglia('tempo50', 'Resistenza', '50 serie a tempo', Icons.timer, 50, 'tempo', 'argento'),
  Medaglia('muscoli8', 'Corpo intero', 'Allena 8 muscoli diversi in una settimana', Icons.accessibility_new, 8, 'muscoli', 'argento'),
  Medaglia('muscoli12', 'Tutto il corpo', 'Allena tutti i 12 muscoli in una settimana', Icons.accessibility_new, 12, 'muscoli', 'oro'),
  // Corpo e amici
  Medaglia('peso1', 'Sulla bilancia', 'Registra il tuo primo peso', Icons.monitor_weight, 1, 'pesi', 'bronzo'),
  Medaglia('peso10', 'Controllo costante', '10 pesi registrati', Icons.monitor_weight, 10, 'pesi', 'argento'),
  Medaglia('peso30', 'Occhio alla bilancia', '30 pesi registrati', Icons.monitor_weight, 30, 'pesi', 'oro'),
  Medaglia('amico1', 'In compagnia', 'Aggiungi il tuo primo amico', Icons.group, 1, 'amici', 'bronzo'),
  Medaglia('amici5', 'Squadra', '5 amici in palestra', Icons.groups, 5, 'amici', 'argento'),
  // Allenamenti (altri traguardi)
  Medaglia('cinque', 'Ci stai prendendo gusto', '5 allenamenti', Icons.thumb_up, 5, 'allenamenti', 'bronzo'),
  Medaglia('cinquecento', 'Immortale', '500 allenamenti', Icons.stars, 500, 'allenamenti', 'platino'),
  Medaglia('serie5000', 'Instancabile', '5000 serie fatte', Icons.fitness_center, 5000, 'serie', 'platino'),
  // Costanza nel lungo periodo
  Medaglia('sett26', 'Mezzo anno', '26 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 26, 'settimane', 'platino'),
  Medaglia('sett52', 'Un anno intero', '52 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 52, 'settimane', 'platino'),
  Medaglia('mese12', 'Mese pieno', '12 allenamenti in un solo mese', Icons.date_range, 12, 'mese', 'argento'),
  Medaglia('mese20', 'Mese da record', '20 allenamenti in un solo mese', Icons.date_range, 20, 'mese', 'oro'),
  Medaglia('consec3', 'Tris di giorni', 'Allenati 3 giorni di fila', Icons.looks_3, 3, 'consecutivi', 'bronzo'),
  Medaglia('weekend', 'Guerriero del weekend', 'Allenati sia sabato sia domenica', Icons.weekend, 1, 'weekend', 'argento'),
  Medaglia('domenica', 'Domenica di ferro', 'Allenati di domenica', Icons.wb_sunny, 1, 'domeniche', 'bronzo'),
  Medaglia('mattina10', 'Alba di ferro', '10 allenamenti prima delle 7', Icons.wb_twilight, 10, 'mattina', 'argento'),
  Medaglia('sera10', 'Gufo notturno', '10 allenamenti dopo le 22', Icons.nightlight_round, 10, 'sera', 'argento'),
  // Volume e record (altri traguardi)
  Medaglia('vol1000', 'Cargo', '1000 tonnellate sollevate in totale', Icons.landscape, 1000000, 'volume', 'platino'),
  Medaglia('rec100', 'Fuori scala', '100 record di carico battuti', Icons.trending_up, 100, 'record', 'platino'),
  // Una singola sessione
  Medaglia('serie20g', 'Sessione intensa', '20 serie in un solo giorno', Icons.local_fire_department, 20, 'serieGiorno', 'bronzo'),
  Medaglia('serie35g', 'Maratona', '35 serie in un solo giorno', Icons.local_fire_department, 35, 'serieGiorno', 'argento'),
  Medaglia('volg5', 'Sessione pesante', '5 tonnellate sollevate in un solo allenamento', Icons.scale, 5000, 'volumeGiorno', 'argento'),
  Medaglia('volg10', 'Giornata di ghisa', '10 tonnellate sollevate in un solo allenamento', Icons.scale, 10000, 'volumeGiorno', 'oro'),
  // Varietà e schede
  Medaglia('var10', 'Curioso', '10 esercizi diversi provati', Icons.explore, 10, 'varieta', 'bronzo'),
  Medaglia('var30', 'Esploratore', '30 esercizi diversi provati', Icons.explore, 30, 'varieta', 'argento'),
  Medaglia('var60', 'Enciclopedia', '60 esercizi diversi provati', Icons.menu_book, 60, 'varieta', 'oro'),
  Medaglia('schede1', 'Il piano', 'Crea la tua prima scheda', Icons.assignment, 1, 'schede', 'bronzo'),
  Medaglia('schede5', 'Programmatore', 'Crea 5 schede', Icons.assignment, 5, 'schede', 'argento'),
  // Giorni per gruppo muscolare
  Medaglia('gambe10', 'Giorno gambe', '10 allenamenti con le gambe', Icons.directions_run, 10, 'gruppo:gambe', 'bronzo'),
  Medaglia('gambe30', 'Mai saltare il leg day', '30 allenamenti con le gambe', Icons.directions_run, 30, 'gruppo:gambe', 'argento'),
  Medaglia('petto25', 'Petto in fuori', '25 allenamenti con il petto', Icons.accessibility_new, 25, 'gruppo:petto', 'argento'),
  Medaglia('schiena25', 'Schiena larga', '25 allenamenti con la schiena', Icons.accessibility_new, 25, 'gruppo:schiena', 'argento'),
  Medaglia('spalle25', 'Spalle a boccia', '25 allenamenti con le spalle', Icons.accessibility_new, 25, 'gruppo:spalle', 'argento'),
  Medaglia('braccia25', 'Braccia d\'acciaio', '25 allenamenti con le braccia', Icons.fitness_center, 25, 'gruppo:braccia', 'argento'),
  Medaglia('core25', 'Core solido', '25 allenamenti con il core', Icons.accessibility_new, 25, 'gruppo:core', 'argento'),
  // Resistenza, corpo e amici (altri traguardi)
  Medaglia('tempo100', 'Maratoneta', '100 serie a tempo', Icons.timer, 100, 'tempo', 'oro'),
  Medaglia('peso60', 'Diario del peso', '60 pesi registrati', Icons.monitor_weight, 60, 'pesi', 'platino'),
  Medaglia('amici10', 'Compagnia numerosa', '10 amici in palestra', Icons.groups, 10, 'amici', 'oro'),
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
    case 'serieGiorno':
      return s.maxSerieGiorno;
    case 'volumeGiorno':
      return s.maxVolumeGiorno.round();
    case 'schede':
      return s.schede;
    case 'consecutivi':
      return s.consecutivi;
    case 'mese':
      return s.maxMese;
    case 'weekend':
      return s.weekend;
    case 'domeniche':
      return s.domeniche;
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
