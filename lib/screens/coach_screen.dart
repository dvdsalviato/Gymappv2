import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/coach.dart';
import '../services/coach_servizio.dart';
import '../theme/app_theme.dart';
import 'assistente_screen.dart';
import 'storico_esercizio_screen.dart';

IconData iconaConsiglio(TipoConsiglio t) {
  switch (t) {
    case TipoConsiglio.stallo:
      return Icons.horizontal_rule_rounded;
    case TipoConsiglio.scarico:
      return Icons.battery_charging_full_rounded;
    case TipoConsiglio.volumeBasso:
      return Icons.add_chart;
    case TipoConsiglio.volumeAlto:
      return Icons.warning_amber_rounded;
    case TipoConsiglio.progresso:
      return Icons.trending_up_rounded;
    case TipoConsiglio.costanza:
      return Icons.event_available_outlined;
    case TipoConsiglio.inizio:
      return Icons.school_outlined;
  }
}

Color coloreConsiglio(TipoConsiglio t) {
  switch (t) {
    case TipoConsiglio.stallo:
    case TipoConsiglio.volumeAlto:
      return Colors.orange.shade400;
    case TipoConsiglio.scarico:
      return Colors.lightBlue.shade300;
    default:
      return AppColors.accento;
  }
}

/// Un consiglio del coach come card (usata anche in Home).
class CardConsiglio extends StatelessWidget {
  final ConsiglioCoach consiglio;
  final bool compatta;
  const CardConsiglio({super.key, required this.consiglio, this.compatta = false});

  bool get _apribile =>
      consiglio.esercizio != null &&
      (consiglio.tipo == TipoConsiglio.stallo || consiglio.tipo == TipoConsiglio.progresso);

  @override
  Widget build(BuildContext context) {
    final colore = coloreConsiglio(consiglio.tipo);
    return Material(
      color: coloreSuperficie(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _apribile
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoricoEsercizioScreen(nome: consiglio.esercizio!)),
                )
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colore.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colore.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(iconaConsiglio(consiglio.tipo), color: colore, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(consiglio.titolo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      consiglio.testo,
                      maxLines: compatta ? 3 : null,
                      overflow: compatta ? TextOverflow.ellipsis : null,
                      style: TextStyle(color: Colors.grey.shade500, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (_apribile) Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il coach: tutti i consigli, dal più importante.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  List<ConsiglioCoach>? _consigli;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final c = await consigliDelCoach();
    if (mounted) setState(() => _consigli = c);
  }

  @override
  Widget build(BuildContext context) {
    final consigli = _consigli;
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: consigli == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Text(
                    'Consigli in base ai tuoi allenamenti, aggiornati a ogni sessione.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  for (final c in consigli)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CardConsiglio(consiglio: c),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: coloreCard(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Come ragiona il coach', style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          '• Stallo: massimale stimato fermo da circa 3 settimane.\n'
                          '• Scarico: molte settimane di fila e prestazioni in calo.\n'
                          '• Volume: serie a settimana per muscolo; la zona utile è 10–20.\n'
                          '• Costanza: allenamenti fatti rispetto al tuo obiettivo settimanale.',
                          style: TextStyle(color: Colors.grey.shade500, height: 1.45, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssistenteScreen()),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Hai una domanda? Chiedi all\'assistente AI'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
