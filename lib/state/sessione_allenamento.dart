import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/esercizio.dart';

enum FaseAllenamento { pronto, inCorso, riposo, completato }

/// Un esercizio in coda durante l'allenamento, con la prossima serie da
/// fare. Permette di saltare/spostarsi tra esercizi e ritrovarli più avanti
/// nella coda senza perdere il punto in cui si era arrivati con ciascuno.
class VoceCoda {
  final Esercizio esercizio;
  int numeroSerie;

  VoceCoda(this.esercizio, this.numeroSerie);
}

/// Istantanea di un allenamento messo in pausa: l'intera coda rimanente,
/// la scheda a cui appartiene, e — se si era a metà di un riposo — quanti
/// secondi restavano, così il countdown riprende da dove era rimasto
/// invece di ripartire da capo o saltare all'esercizio successivo.
/// Vive solo in memoria finché l'app resta aperta: lo storico già salvato
/// non si perde comunque.
class SessioneAllenamentoInPausa {
  final List<VoceCoda> coda;
  final String nomeScheda;
  final FaseAllenamento fase;
  final int secondiRimanenti;
  final int secondiTotali;

  SessioneAllenamentoInPausa({
    required this.coda,
    required this.nomeScheda,
    this.fase = FaseAllenamento.pronto,
    this.secondiRimanenti = 0,
    this.secondiTotali = 0,
  });

  Map<String, dynamic> toJson() => {
        'nomeScheda': nomeScheda,
        'fase': fase.name,
        'secondiRimanenti': secondiRimanenti,
        'secondiTotali': secondiTotali,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'coda': [
          for (final v in coda) {'e': v.esercizio.toMap(), 'n': v.numeroSerie},
        ],
      };

  static SessioneAllenamentoInPausa? daJson(Map<String, dynamic> m) {
    final righe = (m['coda'] as List?) ?? const [];
    final coda = <VoceCoda>[];
    for (final r in righe) {
      if (r is! Map) continue;
      final e = Map<String, dynamic>.from(r['e'] as Map);
      coda.add(VoceCoda(Esercizio.fromMap(e), (r['n'] as num?)?.toInt() ?? 1));
    }
    if (coda.isEmpty) return null;
    var fase = FaseAllenamento.values.firstWhere(
      (f) => f.name == m['fase'],
      orElse: () => FaseAllenamento.pronto,
    );
    var rimanenti = (m['secondiRimanenti'] as num?)?.toInt() ?? 0;
    final totali = (m['secondiTotali'] as num?)?.toInt() ?? 0;
    if (fase == FaseAllenamento.riposo) {
      // Il tempo è passato mentre l'app era chiusa.
      final salvatoMs = (m['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      final trascorsi = ((DateTime.now().millisecondsSinceEpoch - salvatoMs) / 1000).floor();
      rimanenti -= trascorsi;
      if (rimanenti <= 0) {
        fase = FaseAllenamento.pronto;
        rimanenti = 0;
      }
    } else {
      fase = FaseAllenamento.pronto;
    }
    return SessioneAllenamentoInPausa(
      coda: coda,
      nomeScheda: (m['nomeScheda'] as String?) ?? 'Allenamento',
      fase: fase,
      secondiRimanenti: rimanenti,
      secondiTotali: totali,
    );
  }
}

class GestoreSessione {
  static SessioneAllenamentoInPausa? inPausa;

  /// Quando è iniziato l'allenamento attuale (anche se in pausa). Serve alla
  /// Home per mostrare il timer. Torna a null quando l'allenamento finisce.
  static DateTime? inizioAllenamento;

  static const _chiave = 'sessione_salvata';
  static const _chiaveInizio = 'sessione_inizio';

  /// Salva su disco lo stato dell'allenamento: se l'app viene chiusa, al
  /// prossimo avvio si può riprendere da dove eri.
  static Future<void> salva(SessioneAllenamentoInPausa s) async {
    final testo = jsonEncode(s.toJson());
    final inizio = inizioAllenamento;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiave, testo);
    if (inizio != null) await prefs.setInt(_chiaveInizio, inizio.millisecondsSinceEpoch);
  }

  static Future<void> cancellaSalvata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chiave);
    await prefs.remove(_chiaveInizio);
  }

  /// All'avvio dell'app: ripristina un allenamento rimasto a metà.
  /// Restituisce true se ne ha trovato uno.
  static Future<bool> caricaDaDisco() async {
    if (inPausa != null) return false;
    final prefs = await SharedPreferences.getInstance();
    final testo = prefs.getString(_chiave);
    if (testo == null) return false;
    try {
      final m = jsonDecode(testo) as Map<String, dynamic>;
      final ts = (m['ts'] as num?)?.toInt() ?? 0;
      // Dopo 18 ore l'allenamento si considera abbandonato.
      if (DateTime.now().millisecondsSinceEpoch - ts > 18 * 3600 * 1000) {
        await cancellaSalvata();
        return false;
      }
      final s = SessioneAllenamentoInPausa.daJson(m);
      if (s == null) {
        await cancellaSalvata();
        return false;
      }
      inPausa = s;
      final ms = prefs.getInt(_chiaveInizio);
      inizioAllenamento = ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms);
      return true;
    } catch (_) {
      await cancellaSalvata();
      return false;
    }
  }
}
