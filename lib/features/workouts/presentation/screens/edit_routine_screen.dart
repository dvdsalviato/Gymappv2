import 'package:flutter/material.dart';
import '../domain/routine_model.dart';
import 'add_exercise_screen.dart';

class EditRoutineScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const EditRoutineScreen({super.key, required this.routine});

  @override
  State<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  late TextEditingController _titleController;
  late List<RoutineExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.name);
    _exercises = List.from(widget.routine.exercises);
  }

  void _addNewExercise() async {
    final RoutineExercise? newEx = await Navigator.push<RoutineExercise>(
      context,
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );

    if (newEx != null) {
      setState(() {
        _exercises.add(newEx);
      });
    }
  }

  void _saveRoutine() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per la scheda')),
      );
      return;
    }

    final updatedRoutine = WorkoutRoutine(
      id: widget.routine.id,
      name: _titleController.text.trim(),
      exercises: _exercises,
    );

    Navigator.pop(context, updatedRoutine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Scheda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.deepOrange),
            onPressed: _saveRoutine,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Titolo scheda',
                hintText: 'es. Spinta A / Gambe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Esercizi (${_exercises.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Tieni premuta la maniglia per riordinare',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _exercises.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun esercizio presente.\nPremi "+" in basso per aggiungerne uno.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: _exercises.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _exercises.removeAt(oldIndex);
                          _exercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final ex = _exercises[index];
                        return Card(
                          key: ValueKey('${ex.name}_$index'),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                            title: Text(
                              ex.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${ex.sets} serie x ${ex.reps} rep · riposo ${ex.restSeconds}s',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _exercises.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewExercise,
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
