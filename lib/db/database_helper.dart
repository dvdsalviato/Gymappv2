import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scheda.dart';
import '../models/esercizio.dart';
import '../models/storico.dart';

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
      },
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS profilo');
        await db.execute('DROP TABLE IF EXISTS sessioni');
        await db.execute('DROP TABLE IF EXISTS storico');
        await db.execute('DROP TABLE IF EXISTS esercizi');
        await db.execute('DROP TABLE IF EXISTS schede');
        await _onCreate(db, newVersion);
      },
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
    return await db.update(
      'esercizi',
      esercizio.toMap(),
      where: 'id = ?',
      whereArgs: [esercizio.id],
    );
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
             COUNT(*) AS serie, MAX(storico.carico) AS carico_max
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

  Future<List<Map<String, dynamic>>> getStoricoConNome() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT storico.*, esercizi.nome as esercizio_nome, schede.nome as scheda_nome
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
      SELECT storico.*, esercizi.nome as esercizio_nome, schede.nome as scheda_nome
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
