import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_numero.dart';

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  bool _loading = true;
  late TextEditingController _nomeCtrl;

  double _altezzaIniziale = 175;
  double _pesoIniziale = 75;
  double _massaGrassaIniziale = 0;
  double _etaIniziale = 30;

  String? _sesso;
  String? _obiettivo;

  final _altezzaKey = GlobalKey<CampoNumeroState>();
  final _pesoKey = GlobalKey<CampoNumeroState>();
  final _massaGrassaKey = GlobalKey<CampoNumeroState>();
  final _etaKey = GlobalKey<CampoNumeroState>();

  static const _opzioniSesso = ['Uomo', 'Donna', 'Altro'];
  static const _opzioniObiettivo = ['Dimagrimento', 'Massa muscolare', 'Mantenimento', 'Forza'];

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController();
    _carica();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    if (profilo != null) {
      _nomeCtrl.text = (profilo['nome'] as String?) ?? '';
      _altezzaIniziale = (profilo['altezza_cm'] as num?)?.toDouble() ?? _altezzaIniziale;
      _pesoIniziale = (profilo['peso_kg'] as num?)?.toDouble() ?? _pesoIniziale;
      _massaGrassaIniziale = (profilo['massa_grassa_percento'] as num?)?.toDouble() ?? 0;
      _etaIniziale = (profilo['eta'] as num?)?.toDouble() ?? _etaIniziale;
      _sesso = profilo['sesso'] as String?;
      _obiettivo = profilo['obiettivo'] as String?;
    }
    setState(() => _loading = false);
  }

  Future<void> _salva() async {
    await DatabaseHelper.instance.salvaProfilo({
      'nome': _nomeCtrl.text.trim(),
      'altezza_cm': (_altezzaKey.currentState?.valore ?? _altezzaIniziale).round(),
      'peso_kg': _pesoKey.currentState?.valore ?? _pesoIniziale,
      'massa_grassa_percento': _massaGrassaKey.currentState?.valore ?? _massaGrassaIniziale,
      'eta': (_etaKey.currentState?.valore ?? _etaIniziale).round(),
      'sesso': _sesso,
      'obiettivo': _obiettivo,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato')),
      );
    }
  }

  Widget _selettoreTesto(String titolo, List<String> opzioni, String? selezionata, ValueChanged<String> onSeleziona) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: opzioni.map((o) {
            final selezionato = o == selezionata;
            return GestureDetector(
              onTap: () => onSeleziona(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selezionato ? AppColors.accento.withOpacity(0.15) : coloreChip(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selezionato ? AppColors.accento : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(o),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Il mio profilo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'es. Davide',
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CampoNumero(
                          key: _altezzaKey,
                          etichetta: 'Altezza (cm)',
                          valoreIniziale: _altezzaIniziale,
                          step: 1,
                        ),
                        CampoNumero(
                          key: _pesoKey,
                          etichetta: 'Peso (kg)',
                          valoreIniziale: _pesoIniziale,
                          step: 0.5,
                          decimali: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CampoNumero(
                          key: _etaKey,
                          etichetta: 'Età',
                          valoreIniziale: _etaIniziale,
                          step: 1,
                        ),
                        CampoNumero(
                          key: _massaGrassaKey,
                          etichetta: 'Massa grassa %',
                          valoreIniziale: _massaGrassaIniziale,
                          step: 0.5,
                          decimali: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _selettoreTesto('Sesso', _opzioniSesso, _sesso, (v) => setState(() => _sesso = v)),
                    _selettoreTesto(
                      'Obiettivo',
                      _opzioniObiettivo,
                      _obiettivo,
                      (v) => setState(() => _obiettivo = v),
                    ),
                    FilledButton.icon(
                      onPressed: _salva,
                      icon: const Icon(Icons.check),
                      label: const Text('Salva profilo'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
