import 'package:flutter/material.dart';
import '../data/catalogo_esercizi.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../theme/app_theme.dart';
import '../widgets/selettore_catalogo.dart';

class EditEsercizioScreen extends StatefulWidget {
  final int schedaId;
  final Esercizio? esercizio;
  final int ordineSuggerito;

  const EditEsercizioScreen({
    super.key,
    required this.schedaId,
    this.esercizio,
    required this.ordineSuggerito,
  });

  @override
  State<EditEsercizioScreen> createState() => _EditEsercizioScreenState();
}

class _EditEsercizioScreenState extends State<EditEsercizioScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _serieCtrl;
  late TextEditingController _repCtrl;
  late TextEditingController _riposoCtrl;
  late TextEditingController _noteCtrl;
  late String _categoria;
  late bool _aTempo;
  late TextEditingController _minCtrl;
  late TextEditingController _secCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.esercizio;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _serieCtrl = TextEditingController(text: e != null ? e.serieTotali.toString() : '');
    _repCtrl = TextEditingController(text: e != null ? e.repTarget.toString() : '');
    _riposoCtrl = TextEditingController(text: e != null ? e.riposoSecondi.toString() : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _categoria = e?.categoria ?? 'Altro';
    _aTempo = e?.aTempo ?? false;
    final durata = (e != null && e.aTempo) ? e.repTarget : 60;
    _minCtrl = TextEditingController(text: (durata ~/ 60).toString());
    _secCtrl = TextEditingController(text: (durata % 60).toString());
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _serieCtrl.dispose();
    _repCtrl.dispose();
    _riposoCtrl.dispose();
    _noteCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;

    final testoNote = _noteCtrl.text.trim();

    var target = 0;
    if (_aTempo) {
      final minuti = int.tryParse(_minCtrl.text.trim()) ?? 0;
      final secondi = int.tryParse(_secCtrl.text.trim()) ?? 0;
      target = minuti * 60 + secondi;
      if (target < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La durata deve essere di almeno 5 secondi')),
        );
        return;
      }
    } else {
      target = int.parse(_repCtrl.text);
    }

    final nuovo = Esercizio(
      id: widget.esercizio?.id,
      schedaId: widget.schedaId,
      nome: _nomeCtrl.text.trim(),
      ordine: widget.esercizio?.ordine ?? widget.ordineSuggerito,
      serieTotali: int.parse(_serieCtrl.text),
      repTarget: target,
      riposoSecondi: int.parse(_riposoCtrl.text),
      note: testoNote.isEmpty ? null : testoNote,
      categoria: _categoria,
      aTempo: _aTempo,
    );

    if (widget.esercizio == null) {
      await DatabaseHelper.instance.insertEsercizio(nuovo);
    } else {
      await DatabaseHelper.instance.updateEsercizio(nuovo);
    }

    if (mounted) Navigator.pop(context, true);
  }

  String? _validaIntero(String? valore, {int min = 1}) {
    if (valore == null || valore.trim().isEmpty) return 'Obbligatorio';
    final n = int.tryParse(valore);
    if (n == null || n < min) return 'Numero non valido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esercizio == null ? 'Nuovo esercizio' : 'Modifica esercizio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome esercizio',
                  hintText: 'es. Panca piana',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.list_alt),
                    tooltip: 'Scegli dal catalogo',
                    onPressed: () async {
                      final scelto = await mostraCatalogoEsercizi(context);
                      if (scelto != null) {
                        setState(() {
                          _nomeCtrl.text = scelto.nome;
                          _categoria = scelto.categoria;
                          _aTempo = scelto.durataSecondi > 0;
                          if (_aTempo) {
                            _minCtrl.text = (scelto.durataSecondi ~/ 60).toString();
                            _secCtrl.text = (scelto.durataSecondi % 60).toString();
                          }
                        });
                      }
                    },
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 14),
              Text('Categoria muscolare', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categorieEsercizio.map((c) {
                  final selezionata = c == _categoria;
                  return GestureDetector(
                    onTap: () => setState(() => _categoria = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selezionata ? AppColors.accento.withOpacity(0.15) : coloreChip(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selezionata ? AppColors.accento : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(c),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _serieCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numero serie',
                  hintText: 'es. 3',
                ),
                keyboardType: TextInputType.number,
                validator: _validaIntero,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Ripetizioni'), icon: Icon(Icons.repeat)),
                    ButtonSegment(value: true, label: Text('A tempo'), icon: Icon(Icons.timer_outlined)),
                  ],
                  selected: {_aTempo},
                  onSelectionChanged: (s) => setState(() => _aTempo = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.accento,
                    selectedForegroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_aTempo)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minCtrl,
                        decoration: const InputDecoration(labelText: 'Minuti', hintText: 'es. 5'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _secCtrl,
                        decoration: const InputDecoration(labelText: 'Secondi', hintText: 'es. 45'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                )
              else
                TextFormField(
                  controller: _repCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ripetizioni target',
                    hintText: 'es. 10',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validaIntero,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _riposoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Riposo (secondi)',
                  hintText: 'es. 90',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _validaIntero(v, min: 0),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (facoltativo)',
                  hintText: 'es. gomiti stretti, non bloccare le ginocchia...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _salva,
                child: const Text('Salva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
