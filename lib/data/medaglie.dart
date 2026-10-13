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
  // Rango
  Medaglia('rango1', 'Rango Bronzo', 'Raggiungi il rango Bronzo', Icons.shield, 1, 'rango', 'bronzo'),
  Medaglia('rango2', 'Rango Argento', 'Raggiungi il rango Argento', Icons.shield, 2, 'rango', 'argento'),
  Medaglia('rango3', 'Rango Oro', 'Raggiungi il rango Oro', Icons.shield, 3, 'rango', 'oro'),
  Medaglia('rango4', 'Rango Platino', 'Raggiungi il rango Platino', Icons.shield, 4, 'rango', 'platino'),
  Medaglia('rango5', 'Rango Diamante', 'Raggiungi il rango Diamante', Icons.diamond, 5, 'rango', 'platino'),
  Medaglia('rango6', 'Rango Leggenda', 'Raggiungi il rango Leggenda', Icons.auto_awesome, 6, 'rango', 'platino'),
  // Gorilla
  Medaglia('pet5', 'Dieta del Gorilla', 'Il tuo Gorilla ha perso 5 kg', Icons.pets, 5, 'pet', 'bronzo'),
  Medaglia('pet15', 'Gorilla in forma', 'Il tuo Gorilla ha perso 15 kg', Icons.pets, 15, 'pet', 'argento'),
  Medaglia('pet30', 'Gorilla scolpito', 'Il tuo Gorilla ha perso 30 kg', Icons.pets, 30, 'pet', 'oro'),
  Medaglia('pet40', 'Gorilla Alpha', 'Il tuo Gorilla ha raggiunto il peso forma', Icons.pets, 40, 'pet', 'platino'),
];

int valoreMedaglia(Medaglia m, StatisticheUtente s) {
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
    case 'rango':
      return s.rango;
    case 'pet':
      return s.kgGorilla;
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
  final prima = (prefs.getStringList(_chiaveSbloccate) ?? <String>[]).toSet();
  final ora = Set<String>.of(prima);
  final nuove = <Medaglia>[];
  for (final m in medaglie) {
    if (valoreMedaglia(m, s) >= m.soglia && !ora.contains(m.id)) {
      ora.add(m.id);
      nuove.add(m);
    }
  }
  if (nuove.isNotEmpty) await prefs.setStringList(_chiaveSbloccate, ora.toList());
  return EsitoMedaglie(ora, nuove);
}
