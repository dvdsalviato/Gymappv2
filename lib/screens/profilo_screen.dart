import 'package:flutter/material.dart';
import 'account_screen.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_numero.dart';
import 'peso_screen.dart';

class ProfiloScreen extends StatefulWidget {
  /// Se true la schermata non ha una propria barra in alto (è una scheda
  /// della barra principale).
  final bool incorporata;
  final VoidCallback? onSalvato;

  const ProfiloScreen({super.key, this.incorporata = false, this.onSalvato});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  bool _loading = true;
  late TextEditingController _nomeCtrl;

  double _altezzaIniziale = 175;
  double? _pesoAttuale;
  int _sezione = 0; // 0 = dati personali, 1 = peso
  double _etaIniziale = 30;

  String? _sesso;
  String? _obiettivo;

  final _altezzaKey = GlobalKey<CampoNumeroState>();
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
      _pesoAttuale = (profilo['peso_kg'] as num?)?.toDouble();
      _etaIniziale = (profilo['eta'] as num?)?.toDouble() ?? _etaIniziale;
      _sesso = profilo['sesso'] as String?;
      _obiettivo = profilo['obiettivo'] as String?;
    }
    setState(() => _loading = false);
  }

  /// Rilegge solo il peso (dopo una registrazione o un'eliminazione nella
  /// sezione Peso), senza toccare ciò che stai modificando nei dati.
  Future<void> _ricaricaPeso() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    if (!mounted) return;
    setState(() => _pesoAttuale = (profilo?['peso_kg'] as num?)?.toDouble());
  }

  Future<void> _salva() async {
    // Si parte dal profilo salvato così il peso (che si gestisce nella
    // sezione Peso) non viene mai sovrascritto da qui.
    final attuale = await DatabaseHelper.instance.getProfilo() ?? {};
    await DatabaseHelper.instance.salvaProfilo({
      ...attuale,
      'nome': _nomeCtrl.text.trim(),
      'altezza_cm': (_altezzaKey.currentState?.valore ?? _altezzaIniziale).round(),
      'eta': (_etaKey.currentState?.valore ?? _etaIniziale).round(),
      'sesso': _sesso,
      'obiettivo': _obiettivo,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato')),
      );
      widget.onSalvato?.call();
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

  /// Il peso si registra e si guarda nella sezione "Peso": qui è solo un riepilogo.
  Widget _cardPesoAttuale() {
    final peso = _pesoAttuale;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PESO ATTUALE',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  peso == null ? '--' : '${peso.toStringAsFixed(1).replaceAll('.', ',')} kg',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _sezione = 1),
            child: const Text('Registra'),
          ),
        ],
      ),
    );
  }

  Widget _sezioneDati() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'es. Davide',
          ),
        ),
        const SizedBox(height: 24),
        _cardPesoAttuale(),
        const SizedBox(height: 24),
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
              key: _etaKey,
              etichetta: 'Età',
              valoreIniziale: _etaIniziale,
              step: 1,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final corpo = _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Dati'), icon: Icon(Icons.person_outline)),
                        ButtonSegment(value: 1, label: Text('Peso'), icon: Icon(Icons.monitor_weight_outlined)),
                      ],
                      selected: {_sezione},
                      onSelectionChanged: (s) => setState(() => _sezione = s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.accento,
                        selectedForegroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Le due sezioni restano entrambe vive: cambiando scheda non
                  // perdi quello che stavi modificando.
                  Offstage(
                    offstage: _sezione != 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountScreen()),
                          ),
                          icon: const Icon(Icons.cloud_sync_outlined),
                          label: const Text('Account Google e backup'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _sezioneDati(),
                      ],
                    ),
                  ),
                  Offstage(
                    offstage: _sezione != 1,
                    child: PesoScreen(incorporato: true, onCambiato: _ricaricaPeso),
                  ),
                ],
              ),
            ),
          );
    if (widget.incorporata) return corpo;
    return Scaffold(
      appBar: AppBar(title: const Text('Il mio profilo')),
      body: corpo,
    );
  }
}
