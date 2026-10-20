import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/csv_allenamenti.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';

/// Backup e CSV su file: i dati restano dell'utente, senza passare da nessun server.
class ServizioFile {
  static String _dataOggi() {
    final n = DateTime.now();
    String d(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${d(n.month)}${d(n.day)}';
  }

  static Future<File> _scrivi(String nome, String contenuto) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nome');
    await file.writeAsString(contenuto, flush: true);
    return file;
  }

  /// Crea il backup completo (schede, esercizi, storico, presenze, peso, profilo) e lo condivide come file.
  static Future<void> condividiBackup() async {
    final dati = await DatabaseHelper.instance.esportaTutto();
    final prefs = await SharedPreferences.getInstance();
    final testo = jsonEncode({
      'app': 'gymapp',
      'versione': 1,
      'creato': DateTime.now().toIso8601String(),
      'dati': dati,
      'extra': {
        'obiettivo': prefs.getInt(chiaveObiettivoSettimanale),
        'medaglie': prefs.getStringList('medaglie_sbloccate') ?? <String>[],
      },
    });
    final file = await _scrivi('gymapp_backup_${_dataOggi()}.json', testo);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], subject: 'Backup Gymapp');
  }

  static Object? _decodifica(String testo) {
    try {
      return jsonDecode(testo);
    } catch (_) {
      throw const FormatException('Il file non è un backup valido.');
    }
  }

  /// Sostituisce i dati di questo telefono con quelli del file di backup.
  /// Lancia [FormatException] se il file non è un backup di questa app.
  static Future<void> ripristinaDaTesto(String testo) async {
    final m = _decodifica(testo);
    if (m is! Map || m['app'] != 'gymapp' || m['dati'] is! Map) {
      throw const FormatException('Il file non è un backup di questa app.');
    }
    final dati = <String, List<Map<String, dynamic>>>{};
    (m['dati'] as Map).forEach((k, v) {
      dati['$k'] = ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
    await DatabaseHelper.instance.importaTutto(dati);

    final extra = (m['extra'] is Map) ? Map<String, dynamic>.from(m['extra'] as Map) : <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    if (extra['obiettivo'] is num) await prefs.setInt(chiaveObiettivoSettimanale, (extra['obiettivo'] as num).toInt());
    if (extra['medaglie'] is List) {
      await prefs.setStringList('medaglie_sbloccate', (extra['medaglie'] as List).map((e) => '$e').toList());
    }
  }

  /// Esporta tutto lo storico in CSV (colonne di Strong) e lo condivide.
  static Future<void> condividiCsv() async {
    final righe = await DatabaseHelper.instance.getStoricoCompleto();
    if (righe.isEmpty) throw const FormatException('Non c\'è ancora nessuno storico da esportare.');
    final file = await _scrivi('gymapp_storico_${_dataOggi()}.csv', creaCsvStrong(righe));
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], subject: 'Storico Gymapp');
  }

  /// Fa scegliere un file e ne restituisce il testo (null se annulli).
  static Future<String?> scegliFileTesto() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r == null || r.files.isEmpty) return null;
    final percorso = r.files.single.path;
    if (percorso == null) return null;
    final byte = await File(percorso).readAsBytes();
    return utf8.decode(byte, allowMalformed: true);
  }
}
