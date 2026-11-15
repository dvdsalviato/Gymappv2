import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/progressione.dart';
import '../theme/app_theme.dart';

/// Una serie di avvicinamento: carico e ripetizioni.
class SerieRiscaldamento {
  final double carico;
  final int rep;
  const SerieRiscaldamento(this.carico, this.rep);
}

double _arrotonda(double v, double passo) => (v / passo).round() * passo;

/// Serie di avvicinamento verso [carico]: 50% × 8, 70% × 5, 85% × 3,
/// arrotondate a 2,5 kg. Sotto i 20 kg non servono.
List<SerieRiscaldamento> serieRiscaldamento(double carico) {
  if (carico < 20) return const [];
  const schema = [(0.5, 8), (0.7, 5), (0.85, 3)];
  final risultato = <SerieRiscaldamento>[];
  for (final (percentuale, rep) in schema) {
    final kg = _arrotonda(carico * percentuale, 2.5);
    if (kg <= 0 || kg >= carico) continue;
    if (risultato.isNotEmpty && risultato.last.carico == kg) continue;
    risultato.add(SerieRiscaldamento(kg, rep));
  }
  return risultato;
}

/// Dischi da caricare su ogni lato per arrivare a [totale] con un bilanciere
/// da [bilanciere] kg. Restituisce i dischi (dal più pesante) e quanto manca
/// se il peso non si può comporre esattamente.
(List<double>, double) dischiPerLato(
  double totale,
  double bilanciere, {
  List<double> disponibili = const [25, 20, 15, 10, 5, 2.5, 1.25],
}) {
  var perLato = (totale - bilanciere) / 2;
  final dischi = <double>[];
  if (perLato <= 0) return (dischi, 0);
  for (final d in disponibili) {
    while (perLato >= d - 0.001) {
      dischi.add(d);
      perLato -= d;
    }
  }
  return (dischi, perLato < 0.01 ? 0 : perLato * 2);
}

/// Card con le serie di riscaldamento e il pulsante per il calcolo dei dischi.
class CardRiscaldamento extends StatelessWidget {
  final double carico;
  const CardRiscaldamento({super.key, required this.carico});

  @override
  Widget build(BuildContext context) {
    final serie = serieRiscaldamento(carico);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_outlined, color: AppColors.accento, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Riscaldamento', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  serie.isEmpty
                      ? 'Carico leggero: basta una serie a vuoto'
                      : serie.map((s) => '${formatKg(s.carico)}×${s.rep}').join('  ·  '),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => mostraCalcolatoreDischi(context, carico),
            icon: const Icon(Icons.album_outlined, size: 18),
            label: const Text('Dischi'),
          ),
        ],
      ),
    );
  }
}

/// Foglio dal basso: scegli carico e bilanciere, vedi i dischi per lato.
Future<void> mostraCalcolatoreDischi(BuildContext context, double carico) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CalcolatoreDischi(caricoIniziale: carico),
  );
}

class _CalcolatoreDischi extends StatefulWidget {
  final double caricoIniziale;
  const _CalcolatoreDischi({required this.caricoIniziale});

  @override
  State<_CalcolatoreDischi> createState() => _CalcolatoreDischiState();
}

class _CalcolatoreDischiState extends State<_CalcolatoreDischi> {
  late double _carico = widget.caricoIniziale <= 0 ? 60 : widget.caricoIniziale;
  double _bilanciere = 20;

  static const _bilancieri = [20.0, 15.0, 10.0, 0.0];

  Color _coloreDisco(double d) {
    if (d >= 25) return const Color(0xFFE53935);
    if (d >= 20) return const Color(0xFF1E88E5);
    if (d >= 15) return const Color(0xFFFDD835);
    if (d >= 10) return const Color(0xFF43A047);
    if (d >= 5) return const Color(0xFFEEEEEE);
    return const Color(0xFF9E9E9E);
  }

  Widget _disegnoDischi(List<double> dischi) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // manicotto del bilanciere
          Container(width: 34, height: 12, color: scuro ? Colors.grey.shade600 : Colors.grey.shade400),
          Container(width: 8, height: 30, color: scuro ? Colors.grey.shade500 : Colors.grey.shade500),
          for (final d in dischi)
            Container(
              width: d >= 10 ? 16 : 11,
              height: 40 + d * 3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _coloreDisco(d),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          Container(width: 40, height: 12, color: scuro ? Colors.grey.shade600 : Colors.grey.shade400),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (dischi, avanzo) = dischiPerLato(_carico, _bilanciere);
    final raggruppati = <double, int>{};
    for (final d in dischi) {
      raggruppati[d] = (raggruppati[d] ?? 0) + 1;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calcolo dischi', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _carico > 2.5 ? () => setState(() => _carico -= 2.5) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '${formatKg(_carico)} kg',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(fontSize: 40, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _carico += 2.5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Bilanciere', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final b in _bilancieri)
                  ChoiceChip(
                    label: Text(b == 0 ? 'Nessuno' : '${formatKg(b)} kg'),
                    selected: _bilanciere == b,
                    selectedColor: AppColors.accento,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _bilanciere == b ? Colors.black : null,
                    ),
                    onSelected: (_) => setState(() => _bilanciere = b),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_carico <= _bilanciere)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Basta il bilanciere',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else ...[
              _disegnoDischi(dischi),
              Text(
                'Per lato: ${raggruppati.entries.map((e) => '${e.value}×${formatKg(e.key)}').join('  +  ')}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (avanzo > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Mancano ${formatKg(avanzo)} kg per arrivare esatti: usa il carico più vicino.',
                    style: TextStyle(color: Colors.orange.shade300, fontSize: 13),
                  ),
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
