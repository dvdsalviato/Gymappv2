import 'package:flutter/material.dart';
import '../data/alimenti.dart';
import '../data/fabbisogno.dart';
import '../db/database_helper.dart';
import '../services/alimentazione_ai.dart';
import '../services/obiettivo_nutrizionale.dart';
import '../theme/app_theme.dart';
import '../widgets/scelta_alimento.dart';
import 'menu_settimanale_screen.dart';

const List<String> _pasti = ['Colazione', 'Pranzo', 'Spuntino', 'Cena'];

DateTime _giornoOggi() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _pastoPerOra() {
  final h = DateTime.now().hour;
  if (h < 10) return 'Colazione';
  if (h < 15) return 'Pranzo';
  if (h < 18) return 'Spuntino';
  return 'Cena';
}

/// Diario alimentare: scrivi cosa hai mangiato e vedi calorie e macro del giorno.
class AlimentazioneScreen extends StatefulWidget {
  const AlimentazioneScreen({super.key});

  @override
  State<AlimentazioneScreen> createState() => _AlimentazioneScreenState();
}

class _AlimentazioneScreenState extends State<AlimentazioneScreen> {
  DateTime _giorno = _giornoOggi();
  List<Map<String, dynamic>> _righe = [];
  Fabbisogno? _obiettivo;
  bool _loading = true;
  bool _calcolando = false;
  String _pasto = _pastoPerOra();
  final _testoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _testoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final righe = await DatabaseHelper.instance.getDiarioGiorno(_giorno);
    final obiettivo = await caricaObiettivoNutrizionale();
    if (!mounted) return;
    setState(() {
      _righe = righe;
      _obiettivo = obiettivo;
      _loading = false;
    });
  }

  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  String _titoloGiorno() {
    final oggi = _giornoOggi();
    final diff = oggi.difference(_giorno).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    return '${_giorno.day}/${_giorno.month}/${_giorno.year}';
  }

  void _cambiaGiorno(int delta) {
    final nuovo = _giorno.add(Duration(days: delta));
    if (nuovo.isAfter(_giornoOggi())) return;
    setState(() {
      _giorno = DateTime(nuovo.year, nuovo.month, nuovo.day);
      _loading = true;
    });
    _carica();
  }

  Future<void> _salva(List<VoceCibo> voci) async {
    final adesso = DateTime.now();
    final quando = _giorno == _giornoOggi() ? adesso : DateTime(_giorno.year, _giorno.month, _giorno.day, 12);
    final righe = <Map<String, Object?>>[
      for (var i = 0; i < voci.length; i++)
        {
          'data': quando.add(Duration(seconds: i)).toIso8601String(),
          'pasto': _pasto,
          'nome': voci[i].nome,
          'quantita': voci[i].quantita,
          'kcal': voci[i].kcal,
          'proteine': voci[i].proteine,
          'carboidrati': voci[i].carboidrati,
          'grassi': voci[i].grassi,
          'stima': voci[i].stima ? 1 : 0,
        },
    ];
    await DatabaseHelper.instance.insertVociDiario(righe);
    await _carica();
  }

  Future<void> _calcola() async {
    final testo = _testoCtrl.text.trim();
    if (testo.isEmpty || _calcolando) return;
    FocusScope.of(context).unfocus();
    setState(() => _calcolando = true);
    RisultatoPasto risultato;
    try {
      risultato = await interpretaPasto(testo);
    } finally {
      if (mounted) setState(() => _calcolando = false);
    }
    if (!mounted) return;
    if (risultato.voci.isEmpty) {
      _messaggio('Non ho capito nessun alimento: prova con "120 g di pollo, 2 yogurt greco".');
      return;
    }
    final conferma = await confermaPasto(context, risultato.voci, avviso: risultato.avviso);
    if (conferma == null || conferma.isEmpty) return;
    await _salva(conferma);
    _testoCtrl.clear();
    _messaggio('Aggiunto al diario (${conferma.length} ${conferma.length == 1 ? 'voce' : 'voci'})');
  }

  Future<void> _aMano() async {
    final alimento = await scegliAlimento(context);
    if (alimento == null || !mounted) return;
    final quantita = await chiediQuantita(
      context,
      titolo: alimento.nome,
      unita: alimento.unita,
      iniziale: alimento.porzione > 0 ? alimento.porzione : 100,
    );
    if (quantita == null) return;
    await _salva([VoceCibo.daAlimento(alimento, quantita)]);
  }

  Future<void> _modifica(Map<String, dynamic> r) async {
    final vecchia = (r['quantita'] as num).toDouble();
    final nuova = await chiediQuantita(
      context,
      titolo: '${r['nome']}',
      unita: 'g/ml',
      iniziale: vecchia,
    );
    if (nuova == null || vecchia <= 0) return;
    final k = nuova / vecchia;
    await DatabaseHelper.instance.updateVoceDiario(r['id'] as int, {
      'quantita': nuova,
      'kcal': (r['kcal'] as num).toDouble() * k,
      'proteine': (r['proteine'] as num).toDouble() * k,
      'carboidrati': (r['carboidrati'] as num).toDouble() * k,
      'grassi': (r['grassi'] as num).toDouble() * k,
    });
    await _carica();
  }

  Future<void> _elimina(Map<String, dynamic> r) async {
    await DatabaseHelper.instance.deleteVoceDiario(r['id'] as int);
    await _carica();
    if (!mounted) return;
    final copia = Map<String, Object?>.from(r)..remove('id');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${r['nome']}" eliminato'),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () async {
            await DatabaseHelper.instance.insertVociDiario([copia]);
            await _carica();
          },
        ),
      ),
    );
  }

  double _somma(String chiave) => _righe.fold(0.0, (a, r) => a + (r[chiave] as num).toDouble());

  Widget _barra(String nome, double fatto, double? obiettivo, Color colore) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(nome, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: obiettivo == null || obiettivo <= 0 ? 0 : (fatto / obiettivo).clamp(0.0, 1.0),
                color: colore,
                backgroundColor: coloreChip(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              obiettivo == null ? '${fatto.round()} g' : '${fatto.round()} / ${obiettivo.round()} g',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riepilogo() {
    final kcal = _somma('kcal');
    final f = _obiettivo;
    final resto = f == null ? null : f.obiettivo - kcal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f == null ? '${kcal.round()} kcal' : '${kcal.round()} / ${f.obiettivo.round()} kcal',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (resto != null)
            Text(
              resto >= 0 ? 'Ti restano circa ${resto.round()} kcal' : 'Sopra l\'obiettivo di circa ${(-resto).round()} kcal',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          const SizedBox(height: 4),
          _barra('Proteine', _somma('proteine'), f?.proteine, Colors.redAccent),
          _barra('Carboidrati', _somma('carboidrati'), f?.carboidrati, Colors.amber.shade600),
          _barra('Grassi', _somma('grassi'), f?.grassi, Colors.lightBlueAccent),
          if (f == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Per vedere gli obiettivi completa peso, altezza ed età nel profilo (e salvalo).',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inserimento() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _testoCtrl,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Cosa hai mangiato? Es. 120 g di pollo, una birra media e 2 yogurt greco',
              border: InputBorder.none,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final p in _pasti)
                ChoiceChip(label: Text(p), selected: _pasto == p, onSelected: (_) => setState(() => _pasto = p)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _calcolando ? null : _calcola,
                  icon: _calcolando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_calcolando ? 'Leggo…' : 'Calcola'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _calcolando ? null : _aMano,
                icon: const Icon(Icons.search),
                label: const Text('A mano'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), shape: const StadiumBorder()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rigaDiario(Map<String, dynamic> r) {
    final stima = (r['stima'] as int?) == 1;
    final unita = ' ${trovaAlimento('${r['nome']}')?.unita ?? 'g'}';
    return InkWell(
      onTap: () => _modifica(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['nome']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${numero1((r['quantita'] as num).toDouble())}$unita · P ${numero1((r['proteine'] as num).toDouble())} · '
                    'C ${numero1((r['carboidrati'] as num).toDouble())} · G ${numero1((r['grassi'] as num).toDouble())}'
                    '${stima ? '  · stima' : ''}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text('${(r['kcal'] as num).round()} kcal', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(onPressed: () => _elimina(r), icon: const Icon(Icons.delete_outline, size: 20), tooltip: 'Elimina'),
          ],
        ),
      ),
    );
  }

  Widget _diario() {
    if (_righe.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Ancora niente in questo giorno.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    final gruppi = <String, List<Map<String, dynamic>>>{};
    for (final r in _righe) {
      final p = _pasti.contains(r['pasto']) ? r['pasto'] as String : 'Altro';
      gruppi.putIfAbsent(p, () => []).add(r);
    }
    final ordine = [..._pasti, 'Altro'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in ordine)
          if (gruppi.containsKey(p))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 6),
              decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accento)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${gruppi[p]!.fold<double>(0, (a, r) => a + (r['kcal'] as num).toDouble()).round()} kcal',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  for (final r in gruppi[p]!) _rigaDiario(r),
                ],
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _carica,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Cibo', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => _cambiaGiorno(-1), icon: const Icon(Icons.chevron_left)),
                Text(_titoloGiorno(), style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: _giorno.isBefore(_giornoOggi()) ? () => _cambiaGiorno(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())) else _riepilogo(),
            const SizedBox(height: 14),
            _inserimento(),
            const SizedBox(height: 16),
            if (!_loading) _diario(),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuSettimanaleScreen()));
                await _carica();
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Menu settimanale'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
            ),
            const SizedBox(height: 12),
            Text(
              'Valori indicativi, calcolati su alimenti medi: pesa gli alimenti quando puoi e correggi le quantità se serve. '
              'Non sostituisce il parere di un medico o di un dietista.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
