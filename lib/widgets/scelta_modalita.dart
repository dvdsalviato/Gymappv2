import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/esercizio.dart';
import '../screens/allenamento_tabella_screen.dart';
import '../screens/workout_screen.dart';
import '../theme/app_theme.dart';

/// Modalità tabella (in prova): se spenta dal Profilo, l'app si comporta
/// esattamente come prima (solo allenamento guidato).
const String chiaveTabellaAttiva = 'modalita_tabella_attiva';
const String _chiaveUltima = 'modalita_allenamento';

/// Avvia l'allenamento chiedendo la modalità (se la tabella è attiva).
Future<void> avviaAllenamento(
  BuildContext context, {
  required List<Esercizio> esercizi,
  required String nomeScheda,
}) async {
  final prefs = await SharedPreferences.getInstance();
  var modalita = 'guidato';
  if (prefs.getBool(chiaveTabellaAttiva) ?? true) {
    if (!context.mounted) return;
    final ultima = prefs.getString(_chiaveUltima) ?? 'guidato';
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Come ti alleni oggi?', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _Opzione(
                icona: Icons.play_circle_outline,
                titolo: 'Guidato',
                testo: 'Una serie alla volta: l\'app ti accompagna con foto, consigli e recupero.',
                evidenziata: ultima == 'guidato',
                onTap: () => Navigator.pop(ctx, 'guidato'),
              ),
              const SizedBox(height: 10),
              _Opzione(
                icona: Icons.table_rows_outlined,
                titolo: 'Tabella',
                testo: 'Tutto in una pagina: spunti le serie, cambi ordine, aggiungi serie quando vuoi.',
                evidenziata: ultima == 'tabella',
                onTap: () => Navigator.pop(ctx, 'tabella'),
              ),
            ],
          ),
        ),
      ),
    );
    if (scelta == null) return;
    modalita = scelta;
    await prefs.setString(_chiaveUltima, scelta);
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => modalita == 'tabella'
          ? AllenamentoTabellaScreen(esercizi: esercizi, nomeScheda: nomeScheda)
          : WorkoutScreen(esercizi: esercizi, nomeScheda: nomeScheda),
    ),
  );
}

class _Opzione extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String testo;
  final bool evidenziata;
  final VoidCallback onTap;
  const _Opzione({
    required this.icona,
    required this.titolo,
    required this.testo,
    required this.evidenziata,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: evidenziata ? AppColors.accento.withValues(alpha: 0.14) : coloreCard(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: evidenziata ? AppColors.accento : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icona, color: AppColors.accento, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titolo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(testo, style: TextStyle(color: Colors.grey.shade500, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interruttore nel Profilo: spegne la modalità tabella (torna tutto come prima).
class InterruttoreTabella extends StatefulWidget {
  const InterruttoreTabella({super.key});

  @override
  State<InterruttoreTabella> createState() => _InterruttoreTabellaState();
}

class _InterruttoreTabellaState extends State<InterruttoreTabella> {
  bool? _attiva;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _attiva = p.getBool(chiaveTabellaAttiva) ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: SwitchListTile(
        value: _attiva ?? true,
        onChanged: _attiva == null
            ? null
            : (v) async {
                setState(() => _attiva = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool(chiaveTabellaAttiva, v);
              },
        title: const Text('Modalità tabella (in prova)', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Se attiva, all\'inizio scegli tra allenamento guidato e tabella. Spenta: solo guidato, come prima.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ),
    );
  }
}
