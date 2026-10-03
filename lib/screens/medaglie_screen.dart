import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/medaglie.dart';
import '../data/statistiche.dart';
import '../theme/app_theme.dart';

/// Elenco dei traguardi: quelli raggiunti e quanto manca agli altri.
class MedaglieScreen extends StatefulWidget {
  const MedaglieScreen({super.key});

  @override
  State<MedaglieScreen> createState() => _MedaglieScreenState();
}

class _MedaglieScreenState extends State<MedaglieScreen> {
  StatisticheUtente? _stat;
  Set<String> _sbloccate = {};

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final stat = await caricaStatistiche();
    final esito = await aggiornaMedaglie(stat);
    if (!mounted) return;
    setState(() {
      _stat = stat;
      _sbloccate = esito.sbloccate;
    });
  }

  Widget _tessera(Medaglia m, StatisticheUtente s) {
    final sbloccata = _sbloccate.contains(m.id);
    final valore = valoreMedaglia(m, s);
    final progresso = (valore / m.soglia).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sbloccata ? AppColors.accento.withOpacity(0.6) : Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: sbloccata ? AppColors.accento : coloreChip(context),
              shape: BoxShape.circle,
            ),
            child: Icon(m.icona, color: sbloccata ? Colors.black : Colors.grey.shade600, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            m.titolo,
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            m.descrizione,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (sbloccata)
            const Text('SBLOCCATA', style: TextStyle(color: AppColors.accento, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 6,
                backgroundColor: coloreChip(context),
                color: AppColors.accento,
              ),
            ),
            const SizedBox(height: 4),
            Text('${valore > m.soglia ? m.soglia : valore}/${m.soglia}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stat;
    return Scaffold(
      appBar: AppBar(title: const Text('Medaglie')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: coloreSuperficie(context),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department, color: Colors.black, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.settimane == 0
                                  ? 'Inizia la tua serie'
                                  : '${s.settimane} ${s.settimane == 1 ? 'settimana' : 'settimane'} di fila',
                              style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Obiettivo: ${s.obiettivo} allenamenti a settimana',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _riga('${s.allenamenti}', 'allenamenti'),
                    const SizedBox(width: 10),
                    _riga('${s.serie}', 'serie'),
                    const SizedBox(width: 10),
                    _riga('${_sbloccate.length}/${medaglie.length}', 'medaglie'),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                  children: [for (final m in medaglie) _tessera(m, s)],
                ),
              ],
            ),
    );
  }

  Widget _riga(String valore, String etichetta) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: coloreSuperficie(context),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Text(valore, style: GoogleFonts.oswald(fontSize: 26, fontWeight: FontWeight.w700)),
            Text(etichetta, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
