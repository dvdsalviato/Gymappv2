import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'statistiche.dart';

class Medaglia {
  final String id;
  final String titolo;
  final String descrizione;
  final IconData icona;
  final int soglia;
  final String tipo; // allenamenti | serie | settimane | pesi

  const Medaglia(this.id, this.titolo, this.descrizione, this.icona, this.soglia, this.tipo);
}

const List<Medaglia> medaglie = [
  Medaglia('primo', 'Si parte', 'Il tuo primo allenamento', Icons.flag, 1, 'allenamenti'),
  Medaglia('dieci', 'Costanza', '10 allenamenti', Icons.local_fire_department, 10, 'allenamenti'),
  Medaglia('venticinque', 'In forma', '25 allenamenti', Icons.bolt, 25, 'allenamenti'),
  Medaglia('cinquanta', 'Veterano', '50 allenamenti', Icons.military_tech, 50, 'allenamenti'),
  Medaglia('cento', 'Leggenda', '100 allenamenti', Icons.emoji_events, 100, 'allenamenti'),
  Medaglia('serie100', 'Cento serie', '100 serie fatte', Icons.fitness_center, 100, 'serie'),
  Medaglia('serie500', 'Cinquecento', '500 serie fatte', Icons.fitness_center, 500, 'serie'),
  Medaglia('serie1000', 'Mille serie', '1000 serie fatte', Icons.fitness_center, 1000, 'serie'),
  Medaglia('sett2', 'Doppietta', '2 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 2, 'settimane'),
  Medaglia('sett4', 'Un mese di ferro', '4 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 4, 'settimane'),
  Medaglia('sett8', 'Inarrestabile', '8 settimane di fila con obiettivo raggiunto', Icons.calendar_month, 8, 'settimane'),
  Medaglia('peso1', 'Sulla bilancia', 'Registra il tuo primo peso', Icons.monitor_weight, 1, 'pesi'),
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
