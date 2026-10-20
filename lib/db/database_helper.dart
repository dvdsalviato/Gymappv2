import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scheda.dart';
import '../models/esercizio.dart';
import '../models/storico.dart';
import '../data/classificatore.dart';
import '../data/csv_allenamenti.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'scheda_palestra.db');
    return await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS peso_storico ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'peso_kg REAL NOT NULL, '
          'data TEXT NOT NULL)',
        );
        // Diario alimentare: una riga per ogni alimento mangiato, con i valori già calcolati.
        await db.execute(
          'CREATE TABLE IF NOT EXISTS diario_alimenti ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'data TEXT NOT NULL, '
          'pasto TEXT NOT NULL, '
          'nome TEXT NOT NULL, '
          'quantita REAL NOT NULL, '
          'kcal REAL NOT NULL, '
          'proteine REAL NOT NULL, '
          'carboidrati REAL NOT NULL, '
          'grassi REAL NOT NULL, '
          'stima INTEGER NOT NULL DEFAULT 0)',
        );
        // Esercizi a tempo: colonna aggiunta senza toccare i dati esistenti.
        final colonne = await db.rawQuery('PRAGMA table_info(esercizi)');
        final haATempo = colonne.any((c) => c['name'] == 'a_tempo');
        if (!haATempo) {
          await db.execute('ALTER TABLE esercizi ADD COLUMN a_tempo INTEGER NOT NULL DEFAULT 0');
        }
        // Superset: stessa idea, colonna aggiunta senza toccare i dati.
        final haSuperset = colonne.any((c) => c['name'] == 'superset');
        if (!haSuperset) {
          await db.execute('ALTER TABLE esercizi ADD COLUMN superset INTEGER NOT NULL DEFAULT 0');
        }
      },
      onCreate: _onCreate,
      // Nessuna cancellazione: le modifiche allo schema vanno fatte in modo
      // additivo (come per a_tempo in onOpen) per non perdere schede e storico.
      onUpgrade: (db, oldVersion, newVersion) async {},
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schede (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        data_creazione TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE esercizi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheda_id INTEGER NOT NULL,
        nome TEXT NOT NULL,
        ordine INTEGER NOT NULL,
        serie_totali INTEGER NOT NULL,
        rep_target INTEGER NOT NULL,
        riposo_secondi INTEGER NOT NULL,
        note TEXT,
        categoria TEXT NOT NULL DEFAULT 'Altro',
        FOREIGN KEY (scheda_id) REFERENCES schede (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE storico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        esercizio_id INTEGER NOT NULL,
        serie_numero INTEGER NOT NULL,
        carico REAL NOT NULL,
        rep INTEGER NOT NULL,
        data TEXT NOT NULL,
        FOREIGN KEY (esercizio_id) REFERENCES esercizi (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE sessioni (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheda_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        FOREIGN KEY (scheda_id) REFERENCES schede (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE profilo (
        id INTEGER PRIMARY KEY,
        nome TEXT,
        altezza_cm INTEGER,
        peso_kg REAL,
        massa_grassa_percento REAL,
        eta INTEGER,
        sesso TEXT,
        obiettivo TEXT
      )
    ''');
  }

  // ---- SCHEDE ----

  Future<int> insertScheda(Scheda scheda) async {
    final db = await database;
    final map = scheda.toMap()..remove('id');
    return await db.insert('schede', map);
  }

  Future<int> updateScheda(Scheda scheda) async {
    final db = await database;
    return await db.update('schede', scheda.toMap(), where: 'id = ?', whereArgs: [scheda.id]);
  }

  /// Crea una scheda con i suoi esercizi in un colpo solo (per i programmi pronti).
  /// Se il nome esiste già aggiunge "(2)", "(3)"... Restituisce l'id della scheda.
  Future<int> creaSchedaDaModello(String nome, List<Map<String, Object?>> esercizi) async {
    final db = await database;
    return await db.transaction((txn) async {
      final esistenti = (await txn.query('schede', columns: ['nome'])).map((r) => r['nome'] as String).toSet();
      var nomeFinale = nome;
      var n = 2;
      while (esistenti.contains(nomeFinale)) {
        nomeFinale = '$nome ($n)';
        n++;
      }
      final id = await txn.insert('schede', {
        'nome': nomeFinale,
        'data_creazione': DateTime.now().toIso8601String(),
      });
      var ordine = 0;
      for (final e in esercizi) {
        await txn.insert('esercizi', {
          'scheda_id': id,
          'nome': e['nome'],
          'ordine': ordine++,
          'serie_totali': e['serie'],
          'rep_target': e['rep'],
          'riposo_secondi': e['riposo'],
          'note': null,
          'categoria': e['categoria'] ?? 'Altro',
          'a_tempo': e['aTempo'] == true ? 1 : 0,
          'superset': e['superset'] ?? 0,
        });
      }
      return id;
    });
  }

  /// Crea una copia della scheda con tutti i suoi esercizi (lo storico non si copia).
  /// Restituisce l'id della nuova scheda, oppure -1 se la scheda non esiste.
  Future<int> duplicaScheda(int schedaId) async {
    final db = await database;
    return await db.transaction((txn) async {
      final righe = await txn.query('schede', where: 'id = ?', whereArgs: [schedaId]);
      if (righe.isEmpty) return -1;
      final esistenti = (await txn.query('schede', columns: ['nome'])).map((r) => r['nome'] as String).toSet();
      final base = righe.first['nome'] as String;
      var nome = '$base (copia)';
      var n = 2;
      while (esistenti.contains(nome)) {
        nome = '$base (copia $n)';
        n++;
      }
      final scheda = Map<String, Object?>.from(righe.first)
        ..remove('id')
        ..['nome'] = nome
        ..['data_creazione'] = DateTime.now().toIso8601String();
      final nuovoId = await txn.insert('schede', scheda);
      final esercizi = await txn.query('esercizi', where: 'scheda_id = ?', whereArgs: [schedaId], orderBy: 'ordine ASC');
      for (final e in esercizi) {
        final copia = Map<String, Object?>.from(e)
          ..remove('id')
          ..['scheda_id'] = nuovoId;
        await txn.insert('esercizi', copia);
      }
      return nuovoId;
    });
  }

  Future<int> deleteScheda(int id) async {
    final db = await database;
    return await db.delete('schede', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Scheda>> getSchede() async {
    final db = await database;
    final maps = await db.query('schede', orderBy: 'id ASC');
    return maps.map((m) => Scheda.fromMap(m)).toList();
  }

  Future<int> contaEsercizi(int schedaId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM esercizi WHERE scheda_id = ?',
      [schedaId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---- ESERCIZI ----

  Future<int> insertEsercizio(Esercizio esercizio) async {
    final db = await database;
    final map = esercizio.toMap()..remove('id');
    return await db.insert('esercizi', map);
  }

  Future<int> updateEsercizio(Esercizio esercizio) async {
    final db = await database;
    // Il superset si cambia solo con setSuperset: una modifica o un riordino
    // non lo deve mai azzerare per sbaglio.
    final campi = esercizio.toMap()..remove('superset');
    return await db.update(
      'esercizi',
      campi,
      where: 'id = ?',
      whereArgs: [esercizio.id],
    );
  }

  /// Imposta il superset di un esercizio (0 = nessuno).
  Future<void> setSuperset(int esercizioId, int supersetId) async {
    final db = await database;
    await db.update('esercizi', {'superset': supersetId}, where: 'id = ?', whereArgs: [esercizioId]);
  }

  Future<int> deleteEsercizio(int id) async {
    final db = await database;
    return await db.delete('esercizi', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Esercizio>> getEsercizi(int schedaId) async {
    final db = await database;
    final maps = await db.query(
      'esercizi',
      where: 'scheda_id = ?',
      whereArgs: [schedaId],
      orderBy: 'ordine ASC',
    );
    return maps.map((m) => Esercizio.fromMap(m)).toList();
  }

  // ---- STORICO ----

  Future<int> insertStorico(StoricoEntry entry) async {
    final db = await database;
    final map = entry.toMap()..remove('id');
    return await db.insert('storico', map);
  }

  Future<StoricoEntry?> getUltimoStorico(int esercizioId) async {
    final db = await database;
    final maps = await db.query(
      'storico',
      where: 'esercizio_id = ?',
      whereArgs: [esercizioId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return StoricoEntry.fromMap(maps.first);
  }

  // ---- PESO CORPOREO ----

  Future<int> insertPeso(double kg, DateTime data) async {
    final db = await database;
    return await db.insert('peso_storico', {'peso_kg': kg, 'data': data.toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> getPesi() async {
    final db = await database;
    return await db.query('peso_storico', orderBy: 'data ASC, id ASC');
  }

  Future<void> deletePeso(int id) async {
    final db = await database;
    await db.delete('peso_storico', where: 'id = ?', whereArgs: [id]);
  }

  /// Le serie dell'allenamento precedente in cui è stato fatto questo
  /// esercizio (prima dell'allenamento in corso), in ordine di serie.
  Future<List<StoricoEntry>> getSerieUltimaVolta(int esercizioId, {DateTime? prima}) async {
    final db = await database;
    // "Prima" = l'inizio dell'allenamento in corso: così si vede sempre
    // l'allenamento precedente, anche se lo ripeti più volte nello stesso giorno.
    final limite = (prima ?? DateTime.now()).toIso8601String();
    final ultima = await db.rawQuery(
      'SELECT MAX(data) AS d FROM storico WHERE esercizio_id = ? AND data < ?',
      [esercizioId, limite],
    );
    final fineTesto = ultima.isEmpty ? null : ultima.first['d'] as String?;
    if (fineTesto == null) return [];
    final fine = DateTime.tryParse(fineTesto);
    if (fine == null) return [];
    final inizioFinestra = fine.subtract(const Duration(hours: 3)).toIso8601String();
    final maps = await db.rawQuery(
      '''
      SELECT * FROM storico
      WHERE esercizio_id = ? AND data > ? AND data <= ?
      ORDER BY serie_numero ASC, id ASC
      ''',
      [esercizioId, inizioFinestra, fineTesto],
    );
    // Una sola riga per numero di serie (l'ultima registrata).
    final perSerie = <int, StoricoEntry>{};
    for (final m in maps) {
      final e = StoricoEntry.fromMap(m);
      perSerie[e.serieNumero] = e;
    }
    final lista = perSerie.values.toList();
    lista.sort((a, b) => a.serieNumero.compareTo(b.serieNumero));
    return lista;
  }

  static const List<String> _tabelleBackup = [
    'schede',
    'esercizi',
    'storico',
    'sessioni',
    'peso_storico',
    'profilo',
    'diario_alimenti',
  ];

  /// Tutte le righe di tutte le tabelle (per il backup).
  Future<Map<String, List<Map<String, dynamic>>>> esportaTutto() async {
    final db = await database;
    final risultato = <String, List<Map<String, dynamic>>>{};
    for (final t in _tabelleBackup) {
      final righe = await db.query(t);
      risultato[t] = righe.map((r) => Map<String, dynamic>.from(r)).toList();
    }
    return risultato;
  }

  /// Sostituisce tutti i dati con quelli di un backup.
  Future<void> importaTutto(Map<String, List<Map<String, dynamic>>> dati) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in ['storico', 'sessioni', 'esercizi', 'schede', 'peso_storico', 'profilo']) {
        await txn.delete(t);
      }
      // Il diario alimentare si sostituisce solo se il backup lo contiene
      // (i backup più vecchi, o quelli sul cloud, non ce l'hanno).
      if (dati.containsKey('diario_alimenti')) await txn.delete('diario_alimenti');
      for (final t in _tabelleBackup) {
        for (final riga in dati[t] ?? const <Map<String, dynamic>>[]) {
          await txn.insert(t, riga, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  /// Il carico massimo registrato per ogni esercizio (esclusi quelli a tempo).
  Future<List<Map<String, dynamic>>> getRecordPerEsercizio({int limite = 40}) async {
    final db = await database;
    return await db.rawQuery(
      """
      SELECT esercizi.nome AS nome, MAX(storico.carico) AS kg
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      WHERE esercizi.a_tempo = 0
      GROUP BY esercizi.nome
      HAVING MAX(storico.carico) > 0
      ORDER BY kg DESC
      LIMIT ?
      """,
      [limite],
    );
  }

  // ---- CATEGORIE ----

  /// Assegna la categoria agli esercizi rimasti "Altro" quando il nome li
  /// rende riconoscibili (es. "Hyperxtension" diventa Schiena). Tocca solo
  /// quelli in "Altro". Restituisce quanti ne ha aggiornati.
  Future<int> riclassificaAltro() async {
    final db = await database;
    final righe = await db.query(
      'esercizi',
      columns: ['id', 'nome'],
      where: 'categoria = ?',
      whereArgs: ['Altro'],
    );
    var aggiornati = 0;
    final batch = db.batch();
    for (final r in righe) {
      final c = classificaEsercizio(r['nome'] as String);
      if (c != null && c != 'Altro') {
        batch.update('esercizi', {'categoria': c}, where: 'id = ?', whereArgs: [r['id']]);
        aggiornati++;
      }
    }
    if (aggiornati > 0) await batch.commit(noResult: true);
    return aggiornati;
  }

  // ---- STATISTICHE ----

  /// Quanti esercizi diversi (per nome) hai già fatto almeno una volta.
  Future<int> getEserciziDistinti() async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(DISTINCT esercizi.nome) AS c FROM storico JOIN esercizi ON esercizi.id = storico.esercizio_id',
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Giorno, nome e categoria di ogni esercizio fatto (una riga per giorno e esercizio).
  Future<List<Map<String, dynamic>>> getGiorniEsercizi() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT DISTINCT substr(storico.data, 1, 10) AS giorno, esercizi.nome AS nome, esercizi.categoria AS categoria '
      'FROM storico JOIN esercizi ON esercizi.id = storico.esercizio_id',
    );
  }

  /// Chilogrammi totali sollevati (carico x ripetizioni).
  Future<double> getVolumeTotale() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COALESCE(SUM(carico * rep), 0) AS v FROM storico');
    return (r.first['v'] as num?)?.toDouble() ?? 0;
  }

  /// Giorni distinti con almeno una serie registrata tra le ore [da] e [a].
  Future<int> getGiorniConOra(int da, int a) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(DISTINCT substr(data, 1, 10)) AS c FROM storico '
      'WHERE CAST(substr(data, 12, 2) AS INTEGER) BETWEEN ? AND ?',
      [da, a],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Serie a tempo registrate.
  Future<int> getSerieATempo() async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM storico JOIN esercizi ON esercizi.id = storico.esercizio_id WHERE esercizi.a_tempo = 1',
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ---- ELIMINAZIONE DELLO STORICO ----

  Future<void> _pulisciSessioneGiorno(Database db, String giorno) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM storico WHERE substr(data, 1, 10) = ?',
      [giorno],
    );
    if ((Sqflite.firstIntValue(r) ?? 0) == 0) {
      await db.delete('sessioni', where: 'substr(data, 1, 10) = ?', whereArgs: [giorno]);
    }
  }

  /// Elimina una singola serie dallo storico (e il giorno dal calendario se
  /// non restano altre serie quel giorno).
  Future<void> deleteStorico(int id) async {
    final db = await database;
    final righe = await db.query('storico', columns: ['data'], where: 'id = ?', whereArgs: [id]);
    await db.delete('storico', where: 'id = ?', whereArgs: [id]);
    if (righe.isNotEmpty) {
      await _pulisciSessioneGiorno(db, (righe.first['data'] as String).substring(0, 10));
    }
  }

  /// Elimina tutte le serie di un giorno (formato "aaaa-mm-gg") e la presenza
  /// nel calendario.
  Future<void> deleteStoricoGiorno(String giorno) async {
    final db = await database;
    await db.delete('storico', where: 'substr(data, 1, 10) = ?', whereArgs: [giorno]);
    await db.delete('sessioni', where: 'substr(data, 1, 10) = ?', whereArgs: [giorno]);
  }

  /// Elimina quello che è stato registrato da [inizio] in poi (un allenamento
  /// interrotto).
  Future<void> eliminaDaData(DateTime inizio) async {
    final db = await database;
    final iso = inizio.toIso8601String();
    await db.delete('storico', where: 'data >= ?', whereArgs: [iso]);
    await db.delete('sessioni', where: 'data >= ?', whereArgs: [iso]);
  }

  /// Numero totale di serie registrate.
  Future<int> getTotaleSerie() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM storico');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Esercizi fatti da [inizio] in poi (l'allenamento appena concluso), con
  /// il massimo carico che avevi prima, per riconoscere i record.
  Future<List<Map<String, dynamic>>> getEserciziDaData(DateTime inizio) async {
    final db = await database;
    final iso = inizio.toIso8601String();
    return await db.rawQuery(
      '''
      SELECT esercizi.nome AS nome, esercizi.categoria AS categoria,
             COUNT(*) AS serie, MAX(storico.carico) AS carico_max,
             SUM(storico.carico * storico.rep) AS volume,
             MAX(esercizi.a_tempo) AS a_tempo, SUM(storico.rep) AS rep_tot,
             (SELECT MAX(s2.carico) FROM storico s2
                JOIN esercizi e2 ON e2.id = s2.esercizio_id
               WHERE e2.nome = esercizi.nome AND s2.data < ?) AS record_prima
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      WHERE storico.data >= ?
      GROUP BY esercizi.nome, esercizi.categoria
      ORDER BY MIN(storico.data) ASC
      ''',
      [iso, iso],
    );
  }

  /// Esercizi fatti negli ultimi [giorni] giorni, con numero di serie e
  /// carico massimo (raggruppati per nome).
  Future<List<Map<String, dynamic>>> getEserciziRecenti({int giorni = 7}) async {
    final db = await database;
    final daData = DateTime.now().subtract(Duration(days: giorni)).toIso8601String();
    return await db.rawQuery(
      '''
      SELECT esercizi.nome AS nome, esercizi.categoria AS categoria,
             COUNT(*) AS serie, MAX(storico.carico) AS carico_max,
             MAX(esercizi.a_tempo) AS a_tempo, SUM(storico.rep) AS rep_tot
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      WHERE storico.data >= ?
      GROUP BY esercizi.nome, esercizi.categoria
      ORDER BY serie DESC
      ''',
      [daData],
    );
  }

  /// Il carico più alto mai registrato per questo esercizio (record personale).
  Future<StoricoEntry?> getRecordPersonale(int esercizioId) async {
    final db = await database;
    final maps = await db.query(
      'storico',
      where: 'esercizio_id = ?',
      whereArgs: [esercizioId],
      orderBy: 'carico DESC, rep DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return StoricoEntry.fromMap(maps.first);
  }

  // ---- DIARIO ALIMENTARE ----

  Future<void> insertVociDiario(List<Map<String, Object?>> voci) async {
    final db = await database;
    final batch = db.batch();
    for (final v in voci) {
      batch.insert('diario_alimenti', v);
    }
    await batch.commit(noResult: true);
  }

  /// Le voci di un giorno, nell'ordine in cui sono state inserite.
  Future<List<Map<String, dynamic>>> getDiarioGiorno(DateTime giorno) async {
    final db = await database;
    final chiave = giorno.toIso8601String().substring(0, 10);
    return await db.query(
      'diario_alimenti',
      where: 'substr(data, 1, 10) = ?',
      whereArgs: [chiave],
      orderBy: 'data ASC, id ASC',
    );
  }

  Future<void> updateVoceDiario(int id, Map<String, Object?> valori) async {
    final db = await database;
    await db.update('diario_alimenti', valori, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteVoceDiario(int id) async {
    final db = await database;
    await db.delete('diario_alimenti', where: 'id = ?', whereArgs: [id]);
  }

  /// Data dell'ultimo allenamento di ogni scheda (id scheda -> data).
  Future<Map<int, DateTime>> getUltimaSessionePerScheda() async {
    final db = await database;
    final righe = await db.rawQuery('SELECT scheda_id AS id, MAX(data) AS ultima FROM sessioni GROUP BY scheda_id');
    final mappa = <int, DateTime>{};
    for (final r in righe) {
      final d = DateTime.tryParse('${r['ultima']}');
      if (d != null) mappa[r['id'] as int] = d;
    }
    return mappa;
  }

  /// Importa allenamenti letti da un CSV. Ogni nome di allenamento diventa una
  /// scheda (se esiste già con lo stesso nome si riusa) e ogni esercizio viene
  /// creato se manca. Le serie già presenti non vengono duplicate, quindi si
  /// può importare lo stesso file più volte senza danni.
  Future<RisultatoImport> importaAllenamenti(List<RigaAllenamento> righe) async {
    final db = await database;
    var schedeNuove = 0;
    var eserciziNuovi = 0;
    var importate = 0;
    var doppioni = 0;

    await db.transaction((txn) async {
      final perScheda = <String, List<RigaAllenamento>>{};
      for (final r in righe) {
        perScheda.putIfAbsent(r.allenamento.isEmpty ? 'Importato' : r.allenamento, () => []).add(r);
      }

      for (final voce in perScheda.entries) {
        final rs = voce.value;
        final trovata = await txn.query('schede', where: 'nome = ?', whereArgs: [voce.key], limit: 1);
        final int schedaId;
        if (trovata.isNotEmpty) {
          schedaId = trovata.first['id'] as int;
        } else {
          schedaId = await txn.insert('schede', {
            'nome': voce.key,
            'data_creazione': DateTime.now().toIso8601String(),
          });
          schedeNuove++;
        }

        final esistenti = await txn.query('esercizi', where: 'scheda_id = ?', whereArgs: [schedaId]);
        final idPerNome = <String, int>{
          for (final e in esistenti) (e['nome'] as String).toLowerCase(): e['id'] as int,
        };
        var ordine = esistenti.length;

        // Gli esercizi nuovi, nell'ordine in cui compaiono nel file.
        final perEsercizio = <String, List<RigaAllenamento>>{};
        for (final r in rs) {
          perEsercizio.putIfAbsent(r.esercizio, () => []).add(r);
        }
        for (final e in perEsercizio.entries) {
          if (idPerNome.containsKey(e.key.toLowerCase())) continue;
          final serieEs = e.value;
          final aTempo = serieEs.first.aTempo;
          final perGiorno = <int, int>{};
          final frequenza = <int, int>{};
          for (final r in serieEs) {
            final k = r.data.millisecondsSinceEpoch;
            perGiorno[k] = (perGiorno[k] ?? 0) + 1;
            frequenza[r.rep] = (frequenza[r.rep] ?? 0) + 1;
          }
          var serieTotali = perGiorno.values.reduce((a, b) => a > b ? a : b);
          if (serieTotali > 8) serieTotali = 8;
          var repTarget = frequenza.entries.reduce((a, b) => b.value > a.value ? b : a).key;
          if (repTarget < 1) repTarget = aTempo ? 30 : 10;
          final id = await txn.insert('esercizi', {
            'scheda_id': schedaId,
            'nome': e.key,
            'ordine': ordine++,
            'serie_totali': serieTotali,
            'rep_target': repTarget,
            'riposo_secondi': 90,
            'note': null,
            'categoria': classificaEsercizio(e.key) ?? 'Altro',
            'a_tempo': aTempo ? 1 : 0,
            'superset': 0,
          });
          idPerNome[e.key.toLowerCase()] = id;
          eserciziNuovi++;
        }

        // Serie già presenti, per non duplicarle.
        final ids = idPerNome.values.toList();
        final presenti = <String>{};
        if (ids.isNotEmpty) {
          final segnaposto = List.filled(ids.length, '?').join(',');
          final gia = await txn.rawQuery(
            'SELECT esercizio_id, serie_numero, carico, rep, data FROM storico WHERE esercizio_id IN ($segnaposto)',
            ids,
          );
          for (final g in gia) {
            presenti.add('${g['esercizio_id']}|${g['data']}|${g['serie_numero']}|${(g['carico'] as num).toDouble()}|${g['rep']}');
          }
        }

        final batch = txn.batch();
        final progressivo = <int, int>{};
        final giorniConSessione = <String, DateTime>{};
        for (final r in rs) {
          final id = idPerNome[r.esercizio.toLowerCase()]!;
          final k = r.data.millisecondsSinceEpoch;
          final n = progressivo[k] ?? 0;
          progressivo[k] = n + 1;
          // Un secondo in più per ogni serie dello stesso allenamento: tiene l'ordine.
          final quando = r.data.add(Duration(seconds: n)).toIso8601String();
          final chiave = '$id|$quando|${r.serie}|${r.carico}|${r.rep}';
          if (presenti.contains(chiave)) {
            doppioni++;
            continue;
          }
          presenti.add(chiave);
          batch.insert('storico', {
            'esercizio_id': id,
            'serie_numero': r.serie,
            'carico': r.carico,
            'rep': r.rep,
            'data': quando,
          });
          importate++;
          final giorno = quando.substring(0, 10);
          final precedente = giorniConSessione[giorno];
          if (precedente == null || r.data.isBefore(precedente)) giorniConSessione[giorno] = r.data;
        }
        await batch.commit(noResult: true);

        // Una presenza nel calendario per ogni giorno importato.
        for (final g in giorniConSessione.entries) {
          final c = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM sessioni WHERE scheda_id = ? AND substr(data, 1, 10) = ?',
            [schedaId, g.key],
          );
          if (((c.first['c'] as num?) ?? 0) == 0) {
            await txn.insert('sessioni', {'scheda_id': schedaId, 'data': g.value.toIso8601String()});
          }
        }
      }
    });
    return RisultatoImport(schedeNuove, eserciziNuovi, importate, doppioni);
  }

  /// Tutte le serie registrate, senza limite, con scheda, esercizio e categoria.
  Future<List<Map<String, dynamic>>> getStoricoCompleto() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT storico.id AS id, storico.serie_numero AS serie_numero, storico.carico AS carico,
             storico.rep AS rep, storico.data AS data, esercizi.nome AS esercizio_nome,
             esercizi.a_tempo AS a_tempo, esercizi.categoria AS categoria, schede.nome AS scheda_nome
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      JOIN schede ON schede.id = esercizi.scheda_id
      ORDER BY storico.data DESC, storico.id DESC
    ''');
  }

  /// Tutte le serie di un esercizio (per nome, anche se è in più schede).
  Future<List<Map<String, dynamic>>> getStoricoEsercizio(String nome) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT storico.id AS id, storico.serie_numero AS serie_numero, storico.carico AS carico,
             storico.rep AS rep, storico.data AS data, esercizi.nome AS esercizio_nome,
             esercizi.a_tempo AS a_tempo, esercizi.categoria AS categoria, schede.nome AS scheda_nome
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      JOIN schede ON schede.id = esercizi.scheda_id
      WHERE esercizi.nome = ? COLLATE NOCASE
      ORDER BY storico.data DESC, storico.id DESC
    ''', [nome]);
  }

  /// Corregge carico e ripetizioni (o durata) di una serie già registrata.
  Future<void> updateStorico(int id, {required double carico, required int rep}) async {
    final db = await database;
    await db.update('storico', {'carico': carico, 'rep': rep}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getStoricoConNome() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT storico.*, esercizi.nome as esercizio_nome, schede.nome as scheda_nome, esercizi.a_tempo as a_tempo
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      JOIN schede ON schede.id = esercizi.scheda_id
      ORDER BY storico.id DESC
      LIMIT 300
    ''');
  }

  /// Le serie registrate da mezzanotte di oggi, usate dall'assistente AI
  /// per commentare l'allenamento appena fatto.
  Future<List<Map<String, dynamic>>> getStoricoOggi() async {
    final db = await database;
    final oggi = DateTime.now();
    final inizioGiorno = DateTime(oggi.year, oggi.month, oggi.day).toIso8601String();
    return await db.rawQuery(
      '''
      SELECT storico.*, esercizi.nome as esercizio_nome, schede.nome as scheda_nome, esercizi.a_tempo as a_tempo
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      JOIN schede ON schede.id = esercizi.scheda_id
      WHERE storico.data >= ?
      ORDER BY storico.id ASC
      ''',
      [inizioGiorno],
    );
  }

  /// Numero di serie fatte negli ultimi [giorni] giorni per ogni categoria
  /// muscolare (usato dalla mappa muscolare).
  Future<Map<String, int>> getVolumePerCategoria({int giorni = 7}) async {
    final db = await database;
    final daData = DateTime.now().subtract(Duration(days: giorni)).toIso8601String();
    final righe = await db.rawQuery(
      '''
      SELECT esercizi.categoria as categoria, COUNT(*) as conteggio
      FROM storico
      JOIN esercizi ON esercizi.id = storico.esercizio_id
      WHERE storico.data >= ?
      GROUP BY esercizi.categoria
      ''',
      [daData],
    );
    final risultato = <String, int>{};
    for (final r in righe) {
      risultato[r['categoria'] as String] = r['conteggio'] as int;
    }
    return risultato;
  }

  // ---- SESSIONI (per il calendario presenze) ----

  Future<int> insertSessione(int schedaId) async {
    final db = await database;
    return await db.insert('sessioni', {
      'scheda_id': schedaId,
      'data': DateTime.now().toIso8601String(),
    });
  }

  Future<Set<DateTime>> getGiorniPresenza() async {
    final db = await database;
    final maps = await db.query('sessioni', columns: ['data']);
    return maps.map((m) {
      final d = DateTime.parse(m['data'] as String);
      return DateTime(d.year, d.month, d.day);
    }).toSet();
  }

  // ---- PROFILO ----

  Future<void> salvaProfilo(Map<String, dynamic> dati) async {
    final db = await database;
    final map = {...dati, 'id': 1};
    await db.insert('profilo', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfilo() async {
    final db = await database;
    final maps = await db.query('profilo', where: 'id = ?', whereArgs: [1]);
    if (maps.isEmpty) return null;
    return maps.first;
  }
}
