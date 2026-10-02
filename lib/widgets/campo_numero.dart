import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Campo numerico "a stepper": frecce su/giù + trascinamento verticale
/// sul numero per farlo salire o scendere, senza dover aprire la tastiera.
/// Condiviso tra la schermata allenamento (carico/rep) e il profilo
/// (altezza/peso).
class CampoNumero extends StatefulWidget {
  final String etichetta;
  final double valoreIniziale;
  final double step;
  final bool decimali;

  const CampoNumero({
    super.key,
    required this.etichetta,
    required this.valoreIniziale,
    required this.step,
    this.decimali = false,
  });

  @override
  State<CampoNumero> createState() => CampoNumeroState();
}

class CampoNumeroState extends State<CampoNumero> {
  late double _valore;
  double _dragAccumulato = 0;

  @override
  void initState() {
    super.initState();
    _valore = widget.valoreIniziale;
  }

  double get valore => _valore;

  void _incrementa() {
    setState(() => _valore = (_valore + widget.step).clamp(0.0, 9999.0));
  }

  void _decrementa() {
    setState(() => _valore = (_valore - widget.step).clamp(0.0, 9999.0));
  }

  void _onDrag(DragUpdateDetails d) {
    _dragAccumulato -= d.delta.dy;
    const soglia = 14.0;
    if (_dragAccumulato.abs() >= soglia) {
      final scatti = (_dragAccumulato / soglia).truncate();
      setState(() => _valore = (_valore + scatti * widget.step).clamp(0.0, 9999.0));
      _dragAccumulato -= scatti * soglia;
    }
  }

  /// Doppio tap sul numero: si apre la tastiera per scrivere il valore a mano.
  Future<void> _modificaAMano() async {
    final controller = TextEditingController(text: _testo);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final risultato = await showDialog<double>(
      context: context,
      builder: (ctx) {
        void conferma() {
          final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
          Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: Text(widget.etichetta),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            onSubmitted: (_) => conferma(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: conferma,
              style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (risultato == null || !mounted) return;
    final v = widget.decimali ? risultato : risultato.roundToDouble();
    setState(() => _valore = v.clamp(0.0, 9999.0));
  }

  String get _testo {
    if (widget.decimali) {
      return _valore == _valore.roundToDouble()
          ? _valore.toInt().toString()
          : _valore.toStringAsFixed(1);
    }
    return _valore.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.etichetta,
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: _incrementa,
          icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.accento),
        ),
        GestureDetector(
          onVerticalDragUpdate: _onDrag,
          onDoubleTap: _modificaAMano,
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: coloreChip(context),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(_testo, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ),
        ),
        IconButton(
          onPressed: _decrementa,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.accento),
        ),
      ],
    );
  }
}
