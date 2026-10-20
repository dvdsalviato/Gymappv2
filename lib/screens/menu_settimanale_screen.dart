import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fabbisogno.dart';
import '../data/menu_settimanale.dart';
import '../db/database_helper.dart';
import '../services/alimentazione_ai.dart';
import '../services/obiettivo_nutrizionale.dart';
import '../theme/app_theme.dart';

const String _chiaveMenu = 'menu_settimanale_v1';
const List<String> _giorniSettimana = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

/// Menu di esempio per 7 giorni, calcolato sui tuoi obiettivi di calorie e macro.
class MenuSettimanaleScreen extends StatefulWidget {
  const MenuSettimanaleScreen({super.key});

  @override
  State<MenuSettimanaleScreen> createState() => _MenuSettimanaleScreenState();
}

class _MenuSettimanaleScreenState extends State<MenuSettimanaleScreen> {
  Fabbisogno? _obiettivo;
  List<GiornoMenu> _giorni = [];
  bool _loading = true;
  bool _generando = false;
  bool _daAi = false;
  int _pasti = 4;
  String _tipo = 'Onnivoro';
  final _esclusioniCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _esclusioniCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final obiettivo = await caricaObiettivoNutrizionale();
    final prefs = await SharedPreferences.getInstance();
    final salvato = prefs.getString(_chiaveMenu);
    var giorni = <GiornoMenu>[];
    if (salvato != null) {
      try {
        final m = jsonDecode(salvato) as Map<String, dynamic>;
        _pasti = (m['pasti'] as num?)?.toInt() ?? _pasti;
        _tipo = (m['tipo'] as String?) ?? _tipo;
        _esclusioniCtrl.text = (m['esclusioni'] as String?) ?? '';
        _daAi = m['daAi'] == true;
        for (final g in (m['giorni'] as List)) {
          final giorno = giornoDaJson(g);
          if (giorno != null) giorni.add(giorno);
        }
        if (giorni.length != 7) giorni = [];
      } catch (_) {
        giorni = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _obiettivo = obiettivo;
      _giorni = giorni;
      _loading = false;
    });
  }

  Future<void> _salvaMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chiaveMenu,
        jsonEncode({
          'creato': DateTime.now().toIso8601String(),
          'pasti': _pasti,
          'tipo': _tipo,
          'esclusioni': _esclusioniCtrl.text,
          'daAi': _daAi,
          'giorni': [for (final g in _giorni) giornoInJson(g)],
        }),
      );
    } catch (_) {}
  }

  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _genera() async {
    final f = _obiettivo;
    if (f == null || _generando) return;
    FocusScope.of(context).unfocus();
    setState(() => _generando = true);
    try {
      var giorni = await generaMenuConAi(pasti: _pasti, tipoDieta: _tipo, esclusioni: _esclusioniCtrl.text);
      final daAi = giorni != null;
      giorni ??= menuDaModelli(
        pasti: _pasti,
        tipoDieta: _tipo,
        esclusioni: _esclusioniCtrl.text,
        sfasamento: math.Random().nextInt(50),
      );
      if (giorni.isEmpty) {
        _messaggio('Con queste esclusioni non riesco a comporre un menu: prova a toglierne qualcuna.');
        return;
      }
      for (final g in giorni) {
        scalaGiorno(
          g,
          proteine: f.proteine,
          carboidrati: f.carboidrati,
          grassi: f.grassi,
          tipoDieta: _tipo,
          esclusioni: _esclusioniCtrl.text,
        );
      }
      _giorni = giorni;
      _daAi = daAi;
      await _salvaMenu();
    } catch (e) {
      _messaggio('Non sono riuscito a creare il menu: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _mangiato(PastoMenu p) async {
    final ora = DateTime.now();
    final pasto = p.nome.startsWith('Spuntino') ? 'Spuntino' : p.nome;
    final righe = <Map<String, Object?>>[
      for (var i = 0; i < p.items.length; i++)
        {
          'data': ora.add(Duration(seconds: i)).toIso8601String(),
          'pasto': pasto,
          'nome': p.items[i].alimento.nome,
          'quantita': p.items[i].grammi,
          'kcal': p.items[i].kcal,
          'proteine': p.items[i].proteine,
          'carboidrati': p.items[i].carboidrati,
          'grassi': p.items[i].grassi,
          'stima': 0,
        },
    ];
    await DatabaseHelper.instance.insertVociDiario(righe);
    _messaggio('"${p.nome}" aggiunto al diario di oggi');
  }

  void _listaSpesa() {
    final lista = listaSpesa(_giorni);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
              child: Row(
                children: [
                  const Expanded(child: Text('Lista della spesa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: listaSpesaTesto(lista)));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _messaggio('Lista copiata: incollala dove vuoi');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copia'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('Quantità per 7 giorni, come nel menu (peso a crudo dove indicato).', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  for (final e in lista.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accento)),
                    ),
                    for (final v in e.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(v.alimento.nome)),
                            Text(quantitaTesto(v.grammi, v.alimento.unita), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _impostazioni(Fabbisogno f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Obiettivo giornaliero: ${f.obiettivo.round()} kcal',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          Text(
            'Proteine ${f.proteine.round()} g · Carboidrati ${f.carboidrati.round()} g · Grassi ${f.grassi.round()} g',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text('Pasti al giorno', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 5, label: Text('5')),
              ],
              selected: {_pasti},
              onSelectionChanged: (v) => setState(() => _pasti = v.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.accento, selectedForegroundColor: Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final t in const ['Onnivoro', 'Vegetariano', 'Vegano'])
                ChoiceChip(label: Text(t), selected: _tipo == t, onSelected: (_) => setState(() => _tipo = t)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _esclusioniCtrl,
            decoration: const InputDecoration(
              labelText: 'Da evitare (facoltativo)',
              hintText: 'es. pesce, latticini, glutine, noci',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _generando ? null : _genera,
            icon: _generando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_generando ? 'Preparo il menu…' : (_giorni.isEmpty ? 'Crea il menu' : 'Crea un nuovo menu')),
          ),
        ],
      ),
    );
  }

  Widget _giorno(int i, GiornoMenu g, Fabbisogno f) {
    final t = g.totali;
    final proteineBasse = t.proteine < f.proteine * 0.85;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('menu-giorno-$i'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(_giorniSettimana[i], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accento)),
          subtitle: Text(
            '${t.kcal.round()} kcal · P ${t.proteine.round()} · C ${t.carboidrati.round()} · G ${t.grassi.round()}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          children: [
            if (proteineBasse)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Le proteine restano sotto l\'obiettivo (${t.proteine.round()} g su ${f.proteine.round()} g): con questi alimenti è difficile arrivarci.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ),
            for (final p in g.pasti)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${p.nome} · ${p.totali.kcal.round()} kcal', style: const TextStyle(fontWeight: FontWeight.w700))),
                        TextButton(onPressed: () => _mangiato(p), child: const Text('Mangiato')),
                      ],
                    ),
                    for (final it in p.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(it.alimento.nome, style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                            Text(quantitaTesto(it.grammi, it.alimento.unita), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _obiettivo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu settimanale'),
        actions: [
          if (_giorni.isNotEmpty)
            IconButton(onPressed: _listaSpesa, icon: const Icon(Icons.shopping_basket_outlined), tooltip: 'Lista della spesa'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (f == null)
                  Text(
                    'Per creare il menu servono peso, altezza ed età nel profilo (salvato) e almeno 18 anni.',
                    style: TextStyle(color: Colors.grey.shade500, height: 1.4),
                  )
                else ...[
                  _impostazioni(f),
                  const SizedBox(height: 14),
                  if (_giorni.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _daAi
                            ? 'Menu proposto dall\'AI, con le quantità calcolate dall\'app per i tuoi macro.'
                            : 'Menu composto da pasti già pronti, con le quantità calcolate per i tuoi macro. (Con la chiave Gemini e internet lo crea l\'AI.)',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.35),
                      ),
                    ),
                  for (var i = 0; i < _giorni.length; i++) _giorno(i, _giorni[i], f),
                ],
                const SizedBox(height: 12),
                Text(
                  'È un menu di esempio generato automaticamente per i tuoi obiettivi di calorie e macro: non è una dieta personalizzata né un consiglio medico. '
                  'Se hai patologie, allergie, intolleranze, sei in gravidanza o hai un disturbo alimentare, rivolgiti a un medico o a un dietista, e controlla sempre gli ingredienti.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.35),
                ),
              ],
            ),
    );
  }
}
