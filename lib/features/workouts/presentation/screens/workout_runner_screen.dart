import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/routine_model.dart';

class WorkoutRunnerScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutRunnerScreen({super.key, required this.routine});

  @override
  State<WorkoutRunnerScreen> createState() => _WorkoutRunnerScreenState();
}

class _WorkoutRunnerScreenState extends State<WorkoutRunnerScreen> {
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 1;
  bool _isResting = false;
  int _restSecondsLeft = 0;
  Timer? _timer;

  static const neonGreen = Color(0xFF00FF66);

  RoutineExercise get _currentExercise => widget.routine.exercises[_currentExerciseIndex];

  double _weight = 20.0;
  int _repsDone = 10;

  void _startRestTimer(int duration) {
    setState(() {
      _isResting = true;
      _restSecondsLeft = duration;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsLeft > 1) {
        setState(() => _restSecondsLeft--);
      } else {
        _timer?.cancel();
        _nextSetOrExercise();
      }
    });
  }

  void _nextSetOrExercise() {
    _timer?.cancel();
    setState(() {
      _isResting = false;
      if (_currentSetIndex < _currentExercise.sets) {
        _currentSetIndex++;
      } else {
        if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
          _currentExerciseIndex++;
          _currentSetIndex = 1;
        } else {
          _finishWorkout();
        }
      }
    });
  }

  void _finishWorkout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Allenamento Completato! 🎉', style: TextStyle(color: neonGreen)),
        content: const Text('Ottimo lavoro! La sessione è stata salvata nello storico.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: neonGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openRecordSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RecordSetSheet(
          initialWeight: _weight,
          initialReps: _currentExercise.reps,
        ),
      ),
    );

    if (result != null) {
      _weight = result['weight'];
      _repsDone = result['reps'];
      _startRestTimer(_currentExercise.restSeconds);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routine.exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.routine.name)),
        body: const Center(
          child: Text('Aggiungi almeno un esercizio per iniziare l\'allenamento.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.name.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause, color: neonGreen),
            onPressed: () {},
          ),
        ],
      ),
      body: _isResting
          ? _buildRestView()
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: neonGreen.withOpacity(0.4)),
                    ),
                    child: Text(
                      'SERIE $_currentSetIndex DI ${_currentExercise.sets}',
                      style: const TextStyle(
                        color: neonGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Icon(Icons.fitness_center, size: 72, color: neonGreen),
                  const SizedBox(height: 20),
                  Text(
                    _currentExercise.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Obiettivo: ${_currentExercise.reps} reps · ${_currentExercise.category}',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  if (_currentExercise.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Note: ${_currentExercise.notes}',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _openRecordSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('▶ REGISTRA E CONTINUA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildRestView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('RECUPERO IN CORSO', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: _restSecondsLeft / _currentExercise.restSeconds,
                  strokeWidth: 12,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(neonGreen),
                ),
              ),
              Text(
                '${_restSecondsLeft}s',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: neonGreen),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _restSecondsLeft += 30),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: neonGreen),
                  foregroundColor: neonGreen,
                ),
                child: const Text('+30s', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {
                  if (_restSecondsLeft > 10) {
                    setState(() => _restSecondsLeft -= 10);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: neonGreen),
                  foregroundColor: neonGreen,
                ),
                child: const Text('-10s', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Spacer(),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: neonGreen, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.next_plan, color: neonGreen, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAlignment: CrossAlignment.start,
                      children: [
                        const Text('PROSSIMO ESERCIZIO:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(_currentExercise.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _nextSetOrExercise,
            child: const Text('Salta riposo ⏩', style: TextStyle(color: neonGreen, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class RecordSetSheet extends StatefulWidget {
  final double initialWeight;
  final int initialReps;

  const RecordSetSheet({
    super.key,
    required this.initialWeight,
    required this.initialReps,
  });

  @override
  State<RecordSetSheet> createState() => _RecordSetSheetState();
}

class _RecordSetSheetState extends State<RecordSetSheet> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  static const neonGreen = Color(0xFF00FF66);

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.initialWeight.toString());
    _repsController = TextEditingController(text: widget.initialReps.toString());
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _adjustWeight(double delta) {
    double current = double.tryParse(_weightController.text) ?? 0.0;
    current += delta;
    if (current < 0) current = 0;
    _weightController.text = current.toStringAsFixed(current % 1 == 0 ? 0 : 1);
  }

  void _adjustReps(int delta) {
    int current = int.tryParse(_repsController.text) ?? 0;
    current += delta;
    if (current < 1) current = 1;
    _repsController.text = current.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('REGISTRA SERIE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: neonGreen, letterSpacing: 1)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEditableBox(
                label: 'Carico (kg)',
                controller: _weightController,
                isDecimal: true,
                onDecrement: () => _adjustWeight(-0.5),
                onIncrement: () => _adjustWeight(0.5),
              ),
              _buildEditableBox(
                label: 'Reps',
                controller: _repsController,
                isDecimal: false,
                onDecrement: () => _adjustReps(-1),
                onIncrement: () => _adjustReps(1),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final weight = double.tryParse(_weightController.text) ?? 0.0;
                final reps = int.tryParse(_repsController.text) ?? 1;
                Navigator.pop(context, {'weight': weight, 'reps': reps});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('CONFERMA SERIE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableBox({
    required String label,
    required TextEditingController controller,
    required bool isDecimal,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: neonGreen, size: 28),
              onPressed: onDecrement,
            ),
            SizedBox(
              width: 85,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    isDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
                  ),
                ],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  fillColor: Colors.black,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: neonGreen, width: 2),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: neonGreen, size: 28),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}
