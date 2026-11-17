import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Versione di cui si mostrano le novità. A ogni aggiornamento si cambiano
/// versione ed elenco: si vedono SOLO le novità di questa versione.
const String versioneNovita = '3.4';
const String _chiave = 'novita_viste';

class _Novita {
  final IconData icona;
  final String titolo;
  final String testo;
  const _Novita(this.icona, this.titolo, this.testo);
}

const List<_Novita> _elenco = [
  _Novita(Icons.palette_outlined, 'Scegli il colore dell\'app',
      'Nel Profilo: lime (il nuovo predefinito, più morbido), verde fluo, menta, azzurro o arancio.'),
  _Novita(Icons.psychology_outlined, 'Coach più preciso',
      'Le serie a settimana per muscolo ora si calcolano dalle tue schede, non dagli ultimi giorni. '
          'Stalli e progressi mostrano le tue serie vere (kg × ripetizioni).'),
  _Novita(Icons.insights, 'Progressi più chiari',
      'In "Forza per esercizio" vedi la tua miglior serie dell\'ultimo mese al posto del massimale stimato.'),
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
