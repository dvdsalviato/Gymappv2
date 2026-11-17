import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const String versioneNovita = '3.1';
const String _chiave = 'novita_viste';

class _Novita {
  final IconData icona;
  final String titolo;
  final String testo;
  const _Novita(this.icona, this.titolo, this.testo);
}

const List<_Novita> _elenco = [
  _Novita(Icons.precision_manufacturing_outlined, 'Macchinari distinti',
      'Indica il marchio (Technogym, Panatta, Matrix…) per macchine e cavi: ogni macchina ha il suo storico, '
          'i suoi record e il suo carico consigliato, perché le resistenze non sono uguali.'),
  _Novita(Icons.psychology_outlined, 'Il coach',
      'Legge i tuoi allenamenti e ti avvisa se sei fermo su un esercizio, se serve una settimana di scarico '
          'o se un muscolo fa troppe poche serie. Lo trovi in Home.'),
  _Novita(Icons.insights, 'Progressi',
      'Al posto di Cibo: costanza delle ultime 12 settimane, serie per muscolo, massimali stimati e record.'),
  _Novita(Icons.link, 'Lo storico non si perde più',
      'Ogni esercizio esiste una volta sola: rinominalo quando vuoi, i progressi lo seguono. Eliminare un '
          'esercizio o una scheda non cancella più le serie fatte.'),
  _Novita(Icons.auto_awesome, 'Prossimo allenamento in Home',
      'La Home ti propone la scheda che tocca, seguendo il tuo ordine. Un tocco e parti.'),
  _Novita(Icons.photo_library_outlined, 'Foto degli esercizi',
      'Vedi come si esegue il movimento, anche durante il riposo per il prossimo esercizio. '
          'Toccala per vederla a schermo intero.'),
  _Novita(Icons.linear_scale, 'Notifica con la barra',
      'Durante il riposo la notifica mostra il tempo che scorre su una barra, come un brano su Spotify.'),
  _Novita(Icons.table_rows_outlined, 'Serie della sessione',
      'Durante l\'allenamento apri la tabella di tutte le serie fatte e correggi un carico o una ripetizione al volo.'),
  _Novita(Icons.local_fire_department_outlined, 'Riscaldamento e dischi',
      'Alla prima serie trovi le serie di avvicinamento e il calcolo dei dischi da caricare per lato.'),
  _Novita(Icons.ios_share, 'Riepilogo da condividere',
      'A fine allenamento vedi il confronto con l\'ultima volta e condividi la card come immagine.'),
  _Novita(Icons.notifications_active_outlined, 'Promemoria e riepilogo della domenica',
      'Scegli giorni e ora nel Profilo: ti avviso quando è ora di allenarti e quale scheda tocca.'),
  _Novita(Icons.archive_outlined, 'Archivio e schede su misura',
      'Archivia le schede che non usi, riordinale tenendole premute, rinominale dalla matita.'),
];

/// Mostra le novità una sola volta per versione. [primoAvvio] true: chi
/// installa ora l'app non vede le novità (non ha niente da confrontare).
Future<void> mostraNovitaSeServe(BuildContext context, {required bool primoAvvio}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_chiave) == versioneNovita) return;
  await prefs.setString(_chiave, versioneNovita);
  if (primoAvvio || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'GYMAPP $versioneNovita',
            style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w800, letterSpacing: 1.6),
          ),
          Text('Le novità', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final n in _elenco)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accento.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(n.icona, color: AppColors.accento, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.titolo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(n.testo, style: TextStyle(color: Colors.grey.shade500, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Andiamo'),
          ),
        ],
      ),
    ),
  );
}
