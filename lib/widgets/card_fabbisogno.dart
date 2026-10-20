import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fabbisogno.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

/// Stima del fabbisogno calorico e dei macro, calcolata con i dati salvati nel profilo.
class CardFabbisogno extends StatefulWidget {
  /// Cambia quando il profilo o il peso vengono aggiornati: la card si ricalcola.
  final int versione;
  const CardFabbisogno({super.key, this.versione = 0});

  @override
  State<CardFabbisogno> createState() => _CardFabbisognoState();
}

class _CardFabbisognoState extends State<CardFabbisogno> {
  bool _loading = true;
  Map<String, dynamic>? _profilo;
  int _livello = 1;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void didUpdateWidget(CardFabbisogno vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.versione != widget.versione) _carica();
  }

  Future<void> _carica() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    final presenze = await DatabaseHelper.instance.getGiorniPresenza();
    final prefs = await SharedPreferences.getInstance();
    final limite = DateTime.now().subtract(const Duration(days: 28));
    final recenti = presenze.where((d) => d.isAfter(limite)).length;
    final salvato = prefs.getInt('fabbisogno_attivita');
    if (!mounted) return;
    setState(() {
      _profilo = profilo;
      _livello = salvato ?? livelloAttivitaDaAllenamenti(recenti / 4);
      _loading = false;
    });
  }

  Future<void> _scegli(int i) async {
    setState(() => _livello = i);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fabbisogno_attivita', i);
    } catch (_) {}
  }

  String _migliaia(double v) =>
      v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  Widget _titolo() => const Text('FABBISOGNO CALORICO', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.3, fontSize: 13));

  Widget _contenitore(List<Widget> figli) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_titolo(), const SizedBox(height: 8), ...figli]),
    );
  }

  Widget _messaggio(String testo) => Text(testo, style: TextStyle(color: Colors.grey.shade500, height: 1.4, fontSize: 13));

  Widget _macro(String nome, double grammi, Color colore) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(color: coloreChip(context), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 22, height: 4, decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            Text('${grammi.round()} g', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(nome, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _contenitore([const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())]);

    final p = _profilo;
    final kg = (p?['peso_kg'] as num?)?.toDouble();
    final cm = (p?['altezza_cm'] as num?)?.toDouble();
    final eta = (p?['eta'] as num?)?.toInt();
    final sesso = p?['sesso'] as String?;
    var obiettivo = p?['obiettivo'] as String?;

    if (kg == null || cm == null || eta == null) {
      return _contenitore([_messaggio('Per la stima servono peso, altezza ed età: completali nel profilo e premi "Salva profilo".')]);
    }
    if (eta < 18) {
      return _contenitore([
        _messaggio('Il calcolo è disponibile dai 18 anni. Per i più giovani l\'alimentazione va valutata con il medico o il pediatra.'),
      ]);
    }
    if (kg < 30 || kg > 300 || cm < 120 || cm > 230 || eta > 100) {
      return _contenitore([_messaggio('I dati del profilo non sembrano corretti: controlla peso, altezza ed età.')]);
    }

    final note = <String>[];
    if (obiettivo == null) {
      note.add('Scegli un obiettivo nel profilo per una stima su misura: per ora considero il mantenimento.');
    }
    if (obiettivo == 'Dimagrimento' && dimagrimentoSconsigliato(kg, cm)) {
      note.add('Con il tuo peso e la tua altezza un dimagrimento non è consigliato: ti propongo il mantenimento. Per qualsiasi dubbio parlane con il medico.');
      obiettivo = 'Mantenimento';
    }
    final f = calcolaFabbisogno(kg: kg, cm: cm, eta: eta, sesso: sesso, livelloAttivita: _livello, obiettivo: obiettivo);
    if (f.limitato) {
      note.add('Per non scendere troppo con le calorie ho tenuto il valore al minimo ragionevole: un deficit più forte andrebbe seguito da un professionista.');
    }

    final etichettaVar = f.variazionePercento == 0 ? 'mantenimento' : '${f.variazionePercento > 0 ? '+' : ''}${f.variazionePercento}% rispetto al mantenimento';

    return _contenitore([
      _messaggio('Quanto ti muovi in una settimana normale?'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (var i = 0; i < nomiAttivita.length; i++)
            ChoiceChip(label: Text(nomiAttivita[i]), selected: _livello == i, onSelected: (_) => _scegli(i)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(descrizioniAttivita[_livello], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ),
      const SizedBox(height: 14),
      Text('${_migliaia(f.obiettivo)} kcal al giorno', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text(
        '$etichettaVar · mantenimento ${_migliaia(f.mantenimento)} · a riposo ${_migliaia(f.bmr)}',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _macro('Proteine', f.proteine, Colors.redAccent),
          _macro('Carboidrati', f.carboidrati, Colors.amber.shade600),
          _macro('Grassi', f.grassi, Colors.lightBlueAccent),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Calcolato con ${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1).replaceAll('.', ',')} kg, ${cm.round()} cm, $eta anni'
        '${sesso == null ? '' : ', $sesso'}. Se non sono giusti correggili sopra e salva il profilo.',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      for (final n in note)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(n, style: TextStyle(color: Colors.orange.shade700, fontSize: 12, height: 1.35))),
      const SizedBox(height: 12),
      _messaggio(
        'È una stima, con un margine d\'errore del 10-15%: non è una dieta né un consiglio medico. '
        'Controlla il peso ogni 2-3 settimane e aggiusta di conseguenza. '
        'In caso di gravidanza, patologie o disturbi alimentari rivolgiti a un medico o a un dietista.',
      ),
    ]);
  }
}
