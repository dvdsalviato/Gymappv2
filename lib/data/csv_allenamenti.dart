/// Esportazione e importazione dello storico in CSV.
///
/// Il file esportato ha le colonne dell'esportazione di Strong, così si può
/// portare altrove. In lettura si riconoscono anche i file di Hevy e di altre
/// app, cercando le colonne per nome.

class RigaAllenamento {
  final DateTime data;
  final String allenamento;
  final String esercizio;
  final int serie;
  final double carico;

  /// Ripetizioni, oppure secondi se [aTempo].
  final int rep;
  final bool aTempo;

  const RigaAllenamento({
    required this.data,
    required this.allenamento,
    required this.esercizio,
    required this.serie,
    required this.carico,
    required this.rep,
    required this.aTempo,
  });
}

class RisultatoLettura {
  final List<RigaAllenamento> righe;

  /// Righe non utilizzabili (data o esercizio mancanti, nessuna ripetizione...).
  final int scartate;

  /// Serie di riscaldamento, non importate.
  final int riscaldamento;

  /// Vero se i pesi erano in libbre e sono stati convertiti in kg.
  final bool inLibbre;

  const RisultatoLettura(this.righe, this.scartate, this.riscaldamento, this.inLibbre);
}

class RisultatoImport {
  final int schedeNuove;
  final int eserciziNuovi;
  final int serieImportate;
  final int doppioni;
  const RisultatoImport(this.schedeNuove, this.eserciziNuovi, this.serieImportate, this.doppioni);
}

// ------------------------------------------------------------------ lettura

/// Sceglie il separatore (virgola, punto e virgola o tabulazione) guardando la prima riga.
String rilevaDelimitatore(String testo) {
  final fine = testo.indexOf('\n');
  final prima = fine < 0 ? testo : testo.substring(0, fine);
  var virgole = 0;
  var puntoVirgola = 0;
  var tab = 0;
  var tra = false;
  for (final c in prima.split('')) {
    if (c == '"') tra = !tra;
    if (tra) continue;
    if (c == ',') virgole++;
    if (c == ';') puntoVirgola++;
    if (c == '\t') tab++;
  }
  if (puntoVirgola > virgole && puntoVirgola >= tab) return ';';
  if (tab > virgole && tab > puntoVirgola) return '\t';
  return ',';
}

/// Legge un CSV (anche con campi tra virgolette, virgolette doppie e a capo dentro i campi).
List<List<String>> leggiCsv(String testo) {
  var t = testo;
  if (t.startsWith('\uFEFF')) t = t.substring(1);
  final d = rilevaDelimitatore(t);
  final righe = <List<String>>[];
  var riga = <String>[];
  final campo = StringBuffer();
  var tra = false;

  void chiudiRiga() {
    riga.add(campo.toString());
    campo.clear();
    if (riga.length > 1 || riga.first.trim().isNotEmpty) righe.add(riga);
    riga = <String>[];
  }

  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (tra) {
      if (c == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          campo.write('"');
          i++;
        } else {
          tra = false;
        }
      } else {
        campo.write(c);
      }
    } else if (c == '"') {
      tra = true;
    } else if (c == d) {
      riga.add(campo.toString());
      campo.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      chiudiRiga();
    } else {
      campo.write(c);
    }
  }
  if (campo.isNotEmpty || riga.isNotEmpty) chiudiRiga();
  return righe;
}

/// Capisce la data in vari formati: "2024-08-13 08:47:00", ISO, "13 Aug 2024, 08:47".
DateTime? leggiDataCsv(String testo) {
  final t = testo.trim();
  if (t.isEmpty) return null;
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso.isUtc ? iso.toLocal() : iso;
  final m = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4}),?\s+(\d{1,2}):(\d{2})').firstMatch(t);
  if (m != null) {
    const mesi = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final i = mesi.indexOf(m.group(2)!.toLowerCase().substring(0, 3));
    if (i >= 0) {
      return DateTime(
        int.parse(m.group(3)!),
        i + 1,
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    }
  }
  return null;
}

String _normalizza(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

int _colonna(List<String> intestazioni, bool Function(String) vale) {
  for (var i = 0; i < intestazioni.length; i++) {
    if (vale(intestazioni[i])) return i;
  }
  return -1;
}

String _cella(List<String> riga, int i) => (i >= 0 && i < riga.length) ? riga[i].trim() : '';

/// Interpreta il testo di un CSV di allenamenti. Lancia [FormatException]
/// se mancano le colonne indispensabili (data, esercizio, ripetizioni o secondi).
RisultatoLettura interpretaCsv(String testo) {
  final tabella = leggiCsv(testo);
  if (tabella.length < 2) throw const FormatException('Il file è vuoto o non è un CSV.');
  final h = tabella.first.map(_normalizza).toList();

  final iData = _colonna(h, (x) => x == 'date' || x.startsWith('date ') || x == 'start time' || x.startsWith('start time'));
  final iAll = _colonna(h, (x) => x == 'workout name' || x == 'title' || x == 'workout');
  final iEs = _colonna(h, (x) => x == 'exercise name' || x == 'exercise title' || x == 'exercise');
  final iPeso = _colonna(h, (x) => x.startsWith('weight'));
  final iRep = _colonna(h, (x) => x == 'reps' || x.startsWith('reps '));
  final iSec = _colonna(h, (x) => x == 'seconds' || x == 'duration seconds');
  final iTipo = _colonna(h, (x) => x == 'set type');
  final iOrdine = _colonna(h, (x) => x == 'set order');

  if (iData < 0 || iEs < 0 || (iRep < 0 && iSec < 0)) {
    throw const FormatException(
      'Non riconosco le colonne. Servono almeno data, nome esercizio e ripetizioni (come nei file di Strong o Hevy).',
    );
  }
  final inLibbre = iPeso >= 0 && (h[iPeso].contains('lb'));

  final righe = <RigaAllenamento>[];
  final contatori = <String, int>{};
  var scartate = 0;
  var riscaldamento = 0;

  for (var r = 1; r < tabella.length; r++) {
    final riga = tabella[r];
    final data = leggiDataCsv(_cella(riga, iData));
    final esercizio = _cella(riga, iEs);
    if (data == null || esercizio.isEmpty) {
      scartate++;
      continue;
    }
    final tipo = _cella(riga, iTipo).toLowerCase();
    final ordine = _cella(riga, iOrdine).toUpperCase();
    if (tipo.contains('warm') || ordine == 'W') {
      riscaldamento++;
      continue;
    }
    var peso = double.tryParse(_cella(riga, iPeso).replaceAll(',', '.')) ?? 0;
    if (inLibbre) peso = double.parse((peso * 0.45359237).toStringAsFixed(2));
    final rep = double.tryParse(_cella(riga, iRep).replaceAll(',', '.'))?.round() ?? 0;
    final sec = double.tryParse(_cella(riga, iSec).replaceAll(',', '.'))?.round() ?? 0;
    final aTempo = rep <= 0 && sec > 0;
    if (rep <= 0 && sec <= 0) {
      scartate++;
      continue;
    }
    // La numerazione delle serie si ricava dall'ordine nel file (Hevy parte da 0, Strong da 1).
    final chiave = '${data.millisecondsSinceEpoch}|${esercizio.toLowerCase()}';
    final numero = (contatori[chiave] ?? 0) + 1;
    contatori[chiave] = numero;
    righe.add(RigaAllenamento(
      data: data,
      allenamento: _cella(riga, iAll),
      esercizio: esercizio,
      serie: numero,
      carico: peso < 0 ? 0 : peso,
      rep: aTempo ? sec : rep,
      aTempo: aTempo,
    ));
  }
  return RisultatoLettura(righe, scartate, riscaldamento, inLibbre);
}

// ---------------------------------------------------------------- scrittura

String _campoCsv(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _numero(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String _dueCifre(int n) => n.toString().padLeft(2, '0');

String _dataStrong(DateTime d) =>
    '${d.year}-${_dueCifre(d.month)}-${_dueCifre(d.day)} ${_dueCifre(d.hour)}:${_dueCifre(d.minute)}:${_dueCifre(d.second)}';

String _durata(Duration d) {
  final minuti = d.inMinutes;
  if (minuti >= 60) return '${minuti ~/ 60}h ${minuti % 60}m';
  return '${minuti}m';
}

/// Crea il CSV con le colonne di Strong a partire dalle serie dello storico
/// (le righe di `getStoricoCompleto`). Un allenamento è l'insieme delle serie
/// di una scheda in uno stesso giorno.
String creaCsvStrong(List<Map<String, dynamic>> serie) {
  final allenamenti = <String, List<Map<String, dynamic>>>{};
  for (final s in serie) {
    final chiave = '${(s['data'] as String).substring(0, 10)}|${s['scheda_nome']}';
    allenamenti.putIfAbsent(chiave, () => []).add(s);
  }
  final elenco = allenamenti.values.toList();
  elenco.sort((a, b) {
    final da = a.map((s) => s['data'] as String).reduce((x, y) => x.compareTo(y) <= 0 ? x : y);
    final db = b.map((s) => s['data'] as String).reduce((x, y) => x.compareTo(y) <= 0 ? x : y);
    return da.compareTo(db);
  });

  final out = StringBuffer('Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE\n');
  for (final righe in elenco) {
    final ordinate = [...righe]..sort((a, b) {
        final c = (a['data'] as String).compareTo(b['data'] as String);
        return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
      });
    final inizio = DateTime.tryParse(ordinate.first['data'] as String) ?? DateTime.now();
    final fine = DateTime.tryParse(ordinate.last['data'] as String) ?? inizio;
    final durata = _durata(fine.difference(inizio));
    final nomeScheda = '${ordinate.first['scheda_nome']}';

    final perEsercizio = <String, List<Map<String, dynamic>>>{};
    for (final s in ordinate) {
      perEsercizio.putIfAbsent('${s['esercizio_nome']}', () => []).add(s);
    }
    for (final e in perEsercizio.entries) {
      final serieEs = [...e.value]..sort((a, b) => (a['serie_numero'] as int).compareTo(b['serie_numero'] as int));
      for (final s in serieEs) {
        final aTempo = (s['a_tempo'] as int?) == 1;
        final rep = (s['rep'] as num).toInt();
        out.writeln([
          _dataStrong(inizio),
          _campoCsv(nomeScheda),
          durata,
          _campoCsv(e.key),
          '${s['serie_numero']}',
          _numero((s['carico'] as num).toDouble()),
          aTempo ? '' : '$rep',
          '',
          aTempo ? '$rep' : '',
          '',
          '',
          '',
        ].join(','));
      }
    }
  }
  return out.toString();
}
