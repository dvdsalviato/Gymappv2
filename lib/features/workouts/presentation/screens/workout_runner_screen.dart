import 'dart:async';
import 'package:flutter/material.dart';
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
              Navigator.pop(context); // Chiude dialog
              Navigator.pop(context); // Torna alla home
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
      builder: (_) => RecordSetSheet(
        initialWeight: _weight,
        initialReps: _currentExercise.reps,
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
                      crossAxisAlignment: CrossAlignment.start,
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
  late double _weight;
  late int _reps;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeight;
    _reps = widget.initialReps;
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
              _buildSelector(
                label: 'Carico (kg)',
                value: '$_weight',
                onDecrement: () => setState(() { if (_weight >= 0.5) _weight -= 0.5; }),
                onIncrement: () => setState(() => _weight += 0.5),
              ),
              _buildSelector(
                label: 'Reps',
                value: '$_reps',
                onDecrement: () => setState(() { if (_reps > 1) _reps--; }),
                onIncrement: () => setState(() => _reps++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(label: const Text('+1 kg'), onPressed: () => setState(() => _weight += 1)),
              ActionChip(label: const Text('+2.5 kg'), onPressed: () => setState(() => _weight += 2.5)),
              ActionChip(label: const Text('+5 kg'), onPressed: () => setState(() => _weight += 5)),
              ActionChip(label: const Text('-2.5 kg'), onPressed: () => setState(() { if (_weight >= 2.5) _weight -= 2.5; })),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {'weight': _weight, 'reps': _reps});
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

  Widget _buildSelector({
    required String label,
    required String value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange), onPressed: onDecrement),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange), onPressed: onIncrement),
          ],
        ),
      ],
    );
  }
}
