import 'package:flutter/material.dart';
import '../data/alimenti.dart';
import '../theme/app_theme.dart';

/// Un decimale con la virgola e senza ",0" inutile: 12,5 / 7.
String numero1(double v) => v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',');

/// Finestra per cercare e scegliere un alimento dalla tabella.
Future<Alimento?> scegliAlimento(BuildContext context, {String iniziale = ''}) {
  return showModalBottomSheet<Alimento>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SceltaAlimento(iniziale: iniziale),
  );
}

class _SceltaAlimento extends StatefulWidget {
  final String iniziale;
  const _SceltaAlimento({required this.iniziale});

  @override
  State<_SceltaAlimento> createState() => _SceltaAlimentoState();
}

class _SceltaAlimentoState extends State<_SceltaAlimento> {
  late final TextEditingController _ctrl;
  List<Alimento> _risultati = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.iniziale);
    _risultati = cercaAlimenti(widget.iniziale);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final altezza = MediaQuery.of(context).size.height * 0.8;
    final tastiera = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: tastiera),
      child: SizedBox(
        height: altezza,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Cerca un alimento', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _risultati = cercaAlimenti(v)),
              ),
            ),
            Expanded(
              child: _risultati.isEmpty
                  ? Center(child: Text('Nessun alimento trovato.', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      itemCount: _risultati.length > 60 ? 60 : _risultati.length,
                      itemBuilder: (context, i) {
                        final a = _risultati[i];
                        return ListTile(
                          title: Text(a.nome),
                          subtitle: Text(
                            '${a.kcal.round()} kcal · P ${numero1(a.p)} · C ${numero1(a.c)} · G ${numero1(a.g)}  (per 100 ${a.unita})',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chiede una quantità (g o ml). Restituisce null se annulli.
Future<double?> chiediQuantita(BuildContext context, {required String titolo, required String unita, required double iniziale}) async {
  final ctrl = TextEditingController(text: numero1(iniziale));
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titolo),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Quantità', suffixText: unita),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
  if (v == null || v <= 0 || v > 5000) return null;
  return v;
}

/// Mostra le voci lette da una frase e lascia correggerle prima di aggiungerle
/// al diario. Restituisce le voci confermate, o null se annulli.
Future<List<VoceCibo>?> confermaPasto(BuildContext context, List<VoceCibo> voci, {String? avviso}) {
  return showModalBottomSheet<List<VoceCibo>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ConfermaPasto(voci: voci, avviso: avviso),
  );
}

class _ConfermaPasto extends StatefulWidget {
  final List<VoceCibo> voci;
  final String? avviso;
  const _ConfermaPasto({required this.voci, this.avviso});

  @override
  State<_ConfermaPasto> createState() => _ConfermaPastoState();
}

class _ConfermaPastoState extends State<_ConfermaPasto> {
  late final List<VoceCibo> _voci;
  late final List<TextEditingController> _ctrl;
  // Campi tolti dall'elenco: si liberano alla chiusura, non subito, per non toccare un campo ancora a schermo.
  final List<TextEditingController> _scartati = [];

  @override
  void initState() {
    super.initState();
    _voci = [...widget.voci];
    _ctrl = [for (final v in _voci) TextEditingController(text: numero1(v.quantita))];
  }

  @override
  void dispose() {
    for (final c in [..._ctrl, ..._scartati]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cambia(int i) async {
    final a = await scegliAlimento(context, iniziale: _voci[i].nome);
    if (a == null) return;
    setState(() => _voci[i].usa(a));
  }

  void _togli(int i) {
    setState(() {
      _voci.removeAt(i);
      _scartati.add(_ctrl.removeAt(i));
    });
  }

  bool get _pronto => _voci.isNotEmpty && _voci.every((v) => !v.nonTrovato && v.quantita > 0);

  Widget _riga(int i) {
    final v = _voci[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _cambia(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (v.nonTrovato)
                    Text('Non riconosciuto: tocca per sceglierlo', style: TextStyle(color: Colors.red.shade400, fontSize: 12))
                  else
                    Text(
                      '${v.kcal.round()} kcal · P ${numero1(v.proteine)} · C ${numero1(v.carboidrati)} · G ${numero1(v.grassi)}'
                      '${v.stima ? '  · stima AI' : ''}',
                      style: TextStyle(color: v.stima ? Colors.orange.shade600 : Colors.grey.shade500, fontSize: 12),
                    ),
                  Text('Tocca il nome per cambiare alimento (es. crudo o cotto)', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: TextField(
              controller: _ctrl[i],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(isDense: true, suffixText: v.unita),
              onChanged: (t) => setState(() => v.quantita = double.tryParse(t.trim().replaceAll(',', '.')) ?? 0),
            ),
          ),
          IconButton(onPressed: () => _togli(i), icon: const Icon(Icons.close, size: 20), tooltip: 'Togli'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final altezza = MediaQuery.of(context).size.height * 0.85;
    final tastiera = MediaQuery.of(context).viewInsets.bottom;
    var kcal = 0.0;
    var p = 0.0;
    var c = 0.0;
    var g = 0.0;
    for (final v in _voci) {
      kcal += v.kcal;
      p += v.proteine;
      c += v.carboidrati;
      g += v.grassi;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: tastiera),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altezza),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ho capito questo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Controlla gli alimenti e le quantità prima di aggiungerli.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              if (widget.avviso != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(widget.avviso!, style: TextStyle(color: Colors.orange.shade700, fontSize: 12, height: 1.3)),
                ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (var i = 0; i < _voci.length; i++) _riga(i)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Totale: ${kcal.round()} kcal · P ${numero1(p)} g · C ${numero1(c)} g · G ${numero1(g)} g',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_voci.any((v) => v.nonTrovato))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Scegli o togli le voci in rosso per continuare.', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _pronto ? () => Navigator.pop(context, _voci) : null,
                      child: const Text('Aggiungi al diario'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
