import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/pet.dart';
import '../theme/app_theme.dart';
import '../widgets/gorilla_painter.dart';

String testoUmore(UmorePet u) {
  switch (u) {
    case UmorePet.felice:
      return 'Felice';
    case UmorePet.contento:
      return 'Tranquillo';
    case UmorePet.affamato:
      return 'Ha fame di serie';
    case UmorePet.triste:
      return 'Triste';
  }
}

/// Il Gorilla: più ti alleni tu, più lui dimagrisce.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  StatoPet? _pet;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final p = await PetServizio.stato();
    if (!mounted) return;
    setState(() => _pet = p);
  }

  String _kg(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  Future<void> _rinomina() async {
    final controller = TextEditingController(text: _pet?.nome ?? '');
    final nuovo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Come si chiama il tuo Gorilla?'),
        content: TextField(controller: controller, autofocus: true, maxLength: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nuovo == null || nuovo.trim().isEmpty) return;
    await PetServizio.rinomina(nuovo);
    await _carica();
  }

  Widget _blocco({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _statistica(String valore, String etichetta) {
    return Expanded(
      child: Column(
        children: [
          Text(valore, style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(etichetta, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _traguardi(StatoPet p) {
    const tappe = [5, 15, 30, 40];
    const nomi = ['Dieta del Gorilla', 'Gorilla in forma', 'Gorilla scolpito', 'Gorilla Alpha'];
    return _blocco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRAGUARDI', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < tappe.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    p.maxKgPersi >= tappe[i] ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: p.maxKgPersi >= tappe[i] ? AppColors.accento : Colors.grey.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${nomi[i]} · ${tappe[i]} kg persi')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pet;
    return Scaffold(
      appBar: AppBar(title: const Text('Il tuo Gorilla')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _blocco(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: coloreChip(context), borderRadius: BorderRadius.circular(20)),
                          child: Text(p.frase, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 260,
                          width: 240,
                          child: CustomPaint(painter: GorillaPainter(grasso: p.grasso, umore: p.umore)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.nome.toUpperCase(), style: GoogleFonts.oswald(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                            IconButton(
                              onPressed: _rinomina,
                              icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade500),
                              tooltip: 'Cambia nome',
                            ),
                          ],
                        ),
                        Text(p.stadio, style: const TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text('${_kg(p.peso)} kg', style: GoogleFonts.oswald(fontSize: 44, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: p.progresso,
                            minHeight: 12,
                            backgroundColor: coloreChip(context),
                            color: AppColors.accento,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.peso <= petPesoObiettivo + 0.05
                              ? 'Peso forma raggiunto!'
                              : 'Mancano ${_kg(p.peso - petPesoObiettivo)} kg al peso forma (${petPesoObiettivo.round()} kg)',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _blocco(
                    child: Row(
                      children: [
                        _statistica('${p.serieOggi}', 'serie oggi'),
                        _statistica('-${_kg(p.kgOggi)} kg', 'perso oggi'),
                        _statistica('${p.giorniSenza}', 'giorni senza\nallenamento'),
                        _statistica(testoUmore(p.umore), 'umore'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _traguardi(p),
                  const SizedBox(height: 12),
                  _blocco(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COME FUNZIONA', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          '• Ogni serie che fai fa perdere ${(petKgPerSerie * 1000).round()} g a ${p.nome} (al massimo $petSerieMaxGiorno serie al giorno).\n'
                          '• Se salti più di $petGiorniDiGrazia giorni, rimette su ${(petKgRecuperatiAlGiorno * 1000).round()} g al giorno.\n'
                          '• Parte da ${petPesoIniziale.round()} kg e punta a ${petPesoObiettivo.round()} kg.\n'
                          '• Conta le serie fatte dal ${p.inizio.day}/${p.inizio.month}/${p.inizio.year}, il giorno in cui lo hai adottato.',
                          style: TextStyle(color: Colors.grey.shade400, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
