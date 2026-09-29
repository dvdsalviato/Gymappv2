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
        title: const Text('Allenamento Completato! 🎉'),
        content: const Text('Ottimo lavoro! La sessione è stata salvata nello storico.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
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
        title: Text(widget.routine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'SERIE $_currentSetIndex DI ${_currentExercise.sets}',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.fitness_center, size: 64, color: Colors.deepOrange),
                  const SizedBox(height: 16),
                  Text(
                    _currentExercise.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _openRecordSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('▶ Vai', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          const Text('Recupero in corso', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: _restSecondsLeft / _currentExercise.restSeconds,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                ),
              ),
              Text(
                '${_restSecondsLeft}s',
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _restSecondsLeft += 30),
                child: const Text('+30s'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  if (_restSecondsLeft > 10) {
                    setState(() => _restSecondsLeft -= 10);
                  }
                },
                child: const Text('-10s'),
              ),
            ],
          ),
          const Spacer(),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.next_plan, color: Colors.deepOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAlignment: CrossAlignment.start,
                      children: [
                        const Text('Prossimo Esercizio/Serie:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_currentExercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('Salta riposo', style: TextStyle(color: Colors.deepOrange, fontSize: 16)),
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Registra Serie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final weight = double.tryParse(_weightController.text) ?? 0.0;
                final reps = int.tryParse(_repsController.text) ?? 1;
                Navigator.pop(context, {'weight': weight, 'reps': reps});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Conferma serie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
              onPressed: onDecrement,
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    isDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
                  ),
                ],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}
