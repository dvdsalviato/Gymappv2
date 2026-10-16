import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/progressione.dart' show formatKg;

const List<double> _tuttiIDischi = [25, 20, 15, 10, 5, 2.5, 1.25];
const List<double> _barre = [20, 15, 10];

/// Dischi da mettere su ogni lato e quanto resta (per lato) se il carico non è realizzabile.
class RisultatoDischi {
  final List<double> dischi;
  final double restoPerLato;
  const RisultatoDischi(this.dischi, this.restoPerLato);
}

/// Calcolo "goloso": si parte dal disco più grande disponibile. Le misure sono
/// in quarti di chilo per evitare errori di arrotondamento.
RisultatoDischi calcolaDischi(double carico, double barra, List<double> disponibili) {
  var resto = (((carico - barra) / 2) * 4).round();
  final ordinati = [...disponibili]..sort((a, b) => b.compareTo(a));
  final scelti = <double>[];
  for (final d in ordinati) {
    final unita = (d * 4).round();
    while (unita > 0 && resto >= unita) {
      scelti.add(d);
      resto -= unita;
    }
  }
  return RisultatoDischi(scelti, resto / 4);
}

Color _coloreDisco(double d) {
  if (d >= 25) return const Color(0xFFD32F2F);
  if (d >= 20) return const Color(0xFF1976D2);
  if (d >= 15) return const Color(0xFFFBC02D);
  if (d >= 10) return const Color(0xFF388E3C);
  if (d >= 5) return const Color(0xFFEEEEEE);
  return const Color(0xFF9E9E9E);
}

/// Apre il calcolatore per il carico indicato.
Future<void> mostraCalcolatoreDischi(BuildContext context, double carico) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DischiSheet(carico: carico),
  );
}

class _DischiSheet extends StatefulWidget {
  final double carico;
  const _DischiSheet({required this.carico});

  @override
  State<_DischiSheet> createState() => _DischiSheetState();
}

class _DischiSheetState extends State<_DischiSheet> {
  double _barra = 20;
  Set<double> _disponibili = {25, 20, 15, 10, 5, 2.5, 1.25};

  @override
  void initState() {
    super.initState();
    _caricaPreferenze();
  }

  Future<void> _caricaPreferenze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final barra = prefs.getDouble('dischi_barra');
      final dischi = prefs.getStringList('dischi_disponibili');
      if (!mounted) return;
      setState(() {
        if (barra != null && _barre.contains(barra)) _barra = barra;
        if (dischi != null) {
          final letti = dischi.map(double.tryParse).whereType<double>().where(_tuttiIDischi.contains).toSet();
          if (letti.isNotEmpty) _disponibili = letti;
        }
      });
    } catch (_) {}
  }

  Future<void> _salvaPreferenze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('dischi_barra', _barra);
      await prefs.setStringList('dischi_disponibili', _disponibili.map((d) => d.toString()).toList());
    } catch (_) {}
  }

  Widget _disco(double d) {
    final dim = d >= 20 ? 54.0 : (d >= 10 ? 46.0 : (d >= 5 ? 40.0 : 34.0));
    final colore = _coloreDisco(d);
    return Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
      child: Text(
        formatKg(d),
        style: TextStyle(
          color: colore.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: dim > 40 ? 15 : 12,
        ),
      ),
    );
  }

  Widget _risultato() {
    if (_disponibili.isEmpty) {
      return const Text('Seleziona almeno un disco tra quelli che hai in palestra.');
    }
    if (widget.carico < _barra) {
      return Text('Il carico (${formatKg(widget.carico)} kg) è inferiore al bilanciere (${formatKg(_barra)} kg).');
    }
    final r = calcolaDischi(widget.carico, _barra, _disponibili.toList());
    if (r.dischi.isEmpty && r.restoPerLato == 0) {
      return const Text('Solo il bilanciere, nessun disco.');
    }
    final caricabile = widget.carico - 2 * r.restoPerLato;
    final piuPiccolo = _disponibili.reduce((a, b) => a < b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.dischi.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [for (final d in r.dischi) _disco(d)]),
          const SizedBox(height: 10),
          Text(
            'Per lato: ${r.dischi.map(formatKg).join(' + ')}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
        if (r.restoPerLato > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Con questi dischi non si arriva esattamente a ${formatKg(widget.carico)} kg: '
            'restano ${formatKg(r.restoPerLato)} kg per lato. '
            'I carichi più vicini sono ${formatKg(caricabile)} e ${formatKg(caricabile + 2 * piuPiccolo)} kg.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fondo = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, fondo + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dischi per lato', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${formatKg(widget.carico)} kg in totale', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final b in _barre)
                ChoiceChip(
                  label: Text('Bilanciere ${formatKg(b)} kg'),
                  selected: _barra == b,
                  onSelected: (_) {
                    setState(() => _barra = b);
                    _salvaPreferenze();
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          _risultato(),
          const SizedBox(height: 22),
          Text('Dischi che hai in palestra', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final d in _tuttiIDischi)
                FilterChip(
                  label: Text(formatKg(d)),
                  selected: _disponibili.contains(d),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _disponibili = {..._disponibili, d};
                      } else {
                        _disponibili = _disponibili.where((x) => x != d).toSet();
                      }
                    });
                    _salvaPreferenze();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
