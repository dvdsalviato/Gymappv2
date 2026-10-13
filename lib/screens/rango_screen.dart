import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/rango.dart';
import '../theme/app_theme.dart';
import '../widgets/emblema_rango.dart';

/// Il tuo rango di forza, in base ai massimali stimati delle alzate principali.
class RangoScreen extends StatefulWidget {
  const RangoScreen({super.key});

  @override
  State<RangoScreen> createState() => _RangoScreenState();
}

class _RangoScreenState extends State<RangoScreen> {
  RangoStato? _rango;
  bool _caricamento = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final r = await calcolaRango();
    if (!mounted) return;
    setState(() {
      _rango = r;
      _caricamento = false;
    });
  }

  String _kg(double v) => v.round().toString();

  Widget _blocco({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _barra(double valore, Color colore, {double altezza = 10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valore.clamp(0.0, 1.0).toDouble(),
        minHeight: altezza,
        backgroundColor: coloreChip(context),
        color: colore,
      ),
    );
  }

  Widget _intestazione(RangoStato r) {
    final l = r.livello;
    final p = r.prossimo;
    return _blocco(
      child: Column(
        children: [
          EmblemaRango(livello: r.livelloGenerale, dimensione: 120),
          const SizedBox(height: 10),
          Text('IL TUO RANGO', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
          Text(
            l.nome.toUpperCase(),
            style: GoogleFonts.oswald(fontSize: 42, fontWeight: FontWeight.w700, color: l.colore, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),
          if (r.alzateConDati == 0)
            Text(
              'Registra almeno una delle alzate principali per ottenere un rango.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            )
          else ...[
            if (p != null) ...[
              _barra(r.progressoGenerale, p.colore),
              const SizedBox(height: 6),
              Text(
                'Verso ${p.nome}: ${(r.progressoGenerale * 100).round()}%',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ] else
              const Text('Hai raggiunto il livello massimo!', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Calcolato su ${r.alzateConDati} alzate su ${r.alzate.length}'
              '${r.alzateConDati < r.alzate.length ? ': registra le altre per un rango più preciso.' : '.'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scala(RangoStato r) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < livelliRango.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: i == r.livelloGenerale ? livelliRango[i].colore : coloreChip(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              livelliRango[i].nome,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: i == r.livelloGenerale
                    ? Colors.black
                    : (i <= r.livelloGenerale ? livelliRango[i].colore : Colors.grey.shade600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _riga(RisultatoAlzata a) {
    final livello = livelliRango[a.livello];
    final prossimo = a.livello >= livelliRango.length - 1 ? null : livelliRango[a.livello + 1];
    final registrata = a.rapporto != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          registrata
              ? EmblemaRango(livello: a.livello, dimensione: 46)
              : Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: coloreChip(context), shape: BoxShape.circle),
                  child: Icon(Icons.help_outline, color: Colors.grey.shade600),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(a.alzata.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    if (registrata)
                      Text(livello.nome, style: TextStyle(color: livello.colore, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 2),
                if (!registrata)
                  Text(
                    a.e1rm == null ? 'Non ancora registrata' : 'Serve il tuo peso corporeo',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  )
                else ...[
                  Text(
                    'Massimale stimato ${_kg(a.e1rm!)} kg · ${a.rapporto!.toStringAsFixed(2).replaceAll('.', ',')}× il peso',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _barra(a.progresso, (prossimo ?? livello).colore, altezza: 8),
                  const SizedBox(height: 4),
                  Text(
                    prossimo == null
                        ? 'Livello massimo!'
                        : '${prossimo.nome} a circa ${_kg(a.kgProssimo ?? 0)} kg di massimale',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _rango;
    return Scaffold(
      appBar: AppBar(title: const Text('Rango')),
      body: _caricamento || r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _intestazione(r),
                  if (r.peso == null) ...[
                    const SizedBox(height: 12),
                    _blocco(
                      child: Row(
                        children: [
                          const Icon(Icons.monitor_weight_outlined, color: AppColors.accento),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Per calcolare il rango serve il tuo peso: registralo nella scheda Peso.',
                              style: TextStyle(color: Colors.grey.shade400, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _scala(r),
                  const SizedBox(height: 14),
                  _blocco(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Column(children: [for (final a in r.alzate) _riga(a)]),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Come funziona: per ognuna delle 5 alzate principali stimo il tuo massimale (formula di Epley, dalle tue serie migliori) '
                    'e lo confronto con il peso corporeo. Le soglie sono indicative e pensate per il gioco'
                    '${r.donna ? ' (per le donne sono ridotte del 35%)' : ''}.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
    );
  }
}
