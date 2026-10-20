import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/catalogo_esercizi.dart';
import '../data/programmi_pronti.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

/// Elenco dei programmi pronti, con filtri per giorni, attrezzatura e obiettivo.
/// Si chiude restituendo true se è stato aggiunto qualcosa alle schede.
class ProgrammiScreen extends StatefulWidget {
  const ProgrammiScreen({super.key});

  @override
  State<ProgrammiScreen> createState() => _ProgrammiScreenState();
}

class _ProgrammiScreenState extends State<ProgrammiScreen> {
  int? _giorni; // null = tutti; 5 = "5 o più"
  String? _attrezzatura;
  String? _obiettivo;

  bool _vale(Programma p) {
    final g = _giorni;
    if (g != null) {
      final ok = g >= 5 ? p.giorni.any((x) => x >= 5) : p.giorni.contains(g);
      if (!ok) return false;
    }
    if (_attrezzatura != null && p.attrezzatura != _attrezzatura) return false;
    if (_obiettivo != null && p.obiettivo != _obiettivo) return false;
    return true;
  }

  Widget _gruppoFiltro<T>(String titolo, List<T> valori, T? selezionato, String Function(T) etichetta, void Function(T?) cambia) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(titolo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(label: const Text('Tutti'), selected: selezionato == null, onSelected: (_) => setState(() => cambia(null))),
            for (final v in valori)
              ChoiceChip(
                label: Text(etichetta(v)),
                selected: selezionato == v,
                onSelected: (_) => setState(() => cambia(v)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _etichettaPiccola(String testo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: coloreChip(context), borderRadius: BorderRadius.circular(20)),
        child: Text(testo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Future<void> _apri(Programma p) async {
    final aggiunto = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AnteprimaProgramma(programma: p)),
    );
    if (aggiunto == true && mounted) Navigator.pop(context, true);
  }

  Widget _card(Programma p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: () => _apri(p),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nome, style: GoogleFonts.oswald(fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _etichettaPiccola(p.livello),
                  _etichettaPiccola(p.giorni.length == 1 ? '${p.giorni.first} giorni/sett.' : '${p.giorni.join(' o ')} giorni/sett.'),
                  _etichettaPiccola(p.attrezzatura),
                  _etichettaPiccola(p.obiettivo),
                ],
              ),
              const SizedBox(height: 10),
              Text(p.descrizione, style: TextStyle(color: Colors.grey.shade500, height: 1.35, fontSize: 13)),
              const SizedBox(height: 10),
              Text(
                '${p.schede.length} ${p.schede.length == 1 ? 'scheda' : 'schede'} · ${p.numeroEsercizi} esercizi',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accento, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = programmiPronti.where(_vale).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Programmi pronti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Scegli un programma e aggiungilo alle tue schede: poi puoi cambiare esercizi, serie e recuperi come vuoi. '
            'Parti da quello con meno giorni che riesci a rispettare con costanza.',
            style: TextStyle(color: Colors.grey.shade500, height: 1.4),
          ),
          _gruppoFiltro<int>('GIORNI A SETTIMANA', const [2, 3, 4, 5], _giorni, (v) => v == 5 ? '5 o più' : '$v', (v) => _giorni = v),
          _gruppoFiltro<String>('DOVE TI ALLENI', const ['Palestra', 'Manubri', 'Corpo libero'], _attrezzatura, (v) => v, (v) => _attrezzatura = v),
          _gruppoFiltro<String>('OBIETTIVO', const ['Generale', 'Forza', 'Massa'], _obiettivo, (v) => v, (v) => _obiettivo = v),
          const SizedBox(height: 18),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'Nessun programma con questi filtri. Prova a togliere qualcosa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          for (final p in lista) _card(p),
        ],
      ),
    );
  }
}

class _AnteprimaProgramma extends StatefulWidget {
  final Programma programma;
  const _AnteprimaProgramma({required this.programma});

  @override
  State<_AnteprimaProgramma> createState() => _AnteprimaProgrammaState();
}

class _AnteprimaProgrammaState extends State<_AnteprimaProgramma> {
  bool _aggiungendo = false;

  Future<void> _aggiungi() async {
    setState(() => _aggiungendo = true);
    try {
      for (final giorno in widget.programma.schede) {
        await DatabaseHelper.instance.creaSchedaDaModello(giorno.nome, eserciziPerDatabase(giorno));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${widget.programma.nome}" aggiunto alle tue schede')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aggiungendo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Non sono riuscito ad aggiungerlo: $e')));
    }
  }

  String _obiettivo(EsercizioProgramma e) {
    var aTempo = false;
    for (final c in catalogoEsercizi) {
      if (c.nome == e.nome) {
        aTempo = c.durataSecondi > 0;
        break;
      }
    }
    return aTempo ? '${e.serie} × ${formattaDurata(e.rep)}' : '${e.serie} × ${e.rep}';
  }

  Widget _giorno(GiornoProgramma g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.nome, style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accento)),
          const SizedBox(height: 6),
          for (final e in g.esercizi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.superset != 0)
                          const Text(
                            'SUPERSET',
                            style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.2),
                          ),
                        Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text(_obiettivo(e), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.programma;
    return Scaffold(
      appBar: AppBar(title: Text(p.nome)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                Text(p.descrizione, style: TextStyle(color: Colors.grey.shade500, height: 1.4)),
                const SizedBox(height: 8),
                Text(
                  'Verranno create ${p.schede.length} ${p.schede.length == 1 ? 'scheda' : 'schede'}. '
                  'Il carico lo scegli tu: l\'app ti suggerisce quando salire.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final g in p.schede) _giorno(g),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: FilledButton.icon(
                onPressed: _aggiungendo ? null : _aggiungi,
                icon: const Icon(Icons.add),
                label: Text(_aggiungendo ? 'Aggiungo…' : 'Aggiungi alle mie schede'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
