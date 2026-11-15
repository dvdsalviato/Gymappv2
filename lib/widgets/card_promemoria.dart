import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/promemoria.dart';
import '../theme/app_theme.dart';

/// Card per scegliere i giorni e l'ora dei promemoria di allenamento.
class CardPromemoria extends StatefulWidget {
  const CardPromemoria({super.key});

  @override
  State<CardPromemoria> createState() => _CardPromemoriaState();
}

class _CardPromemoriaState extends State<CardPromemoria> {
  static const _nomi = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
  Set<int> _giorni = {};
  TimeOfDay _ora = const TimeOfDay(hour: 18, minute: 0);
  bool _caricato = false;

  @override
  void initState() {
    super.initState();
    Promemoria.carica().then((imp) {
      if (!mounted) return;
      setState(() {
        _giorni = {...imp.giorni};
        _ora = imp.ora;
        _caricato = true;
      });
    });
  }

  Future<void> _salva() async {
    await Promemoria.salva(ImpostazioniPromemoria({..._giorni}, _ora));
  }

  Future<void> _scegliOra() async {
    final scelta = await showTimePicker(
      context: context,
      initialTime: _ora,
      helpText: 'Ora del promemoria',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (scelta == null) return;
    setState(() => _ora = scelta);
    await _salva();
  }

  String get _oraTesto =>
      '${_ora.hour.toString().padLeft(2, '0')}:${_ora.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: AppColors.accento),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Promemoria allenamento',
                  style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _giorni.isEmpty
                ? 'Scegli i giorni: ti avviso a che ora allenarti e quale scheda tocca.'
                : 'Ti avviso alle $_oraTesto con la scheda che tocca.',
            style: TextStyle(color: Colors.grey.shade500, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(builder: (context) {
                  final giorno = i + 1;
                  final attivo = _giorni.contains(giorno);
                  return GestureDetector(
                    onTap: !_caricato
                        ? null
                        : () async {
                            setState(() => attivo ? _giorni.remove(giorno) : _giorni.add(giorno));
                            await _salva();
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: attivo ? AppColors.accento : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: attivo
                              ? AppColors.accento
                              : (scuro ? Colors.white : Colors.black).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        _nomi[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: attivo ? Colors.black : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _caricato ? _scegliOra : null,
            icon: const Icon(Icons.schedule),
            label: Text('Ora: $_oraTesto'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              foregroundColor: AppColors.accento,
              side: BorderSide(color: AppColors.accento.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
