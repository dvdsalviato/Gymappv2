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
