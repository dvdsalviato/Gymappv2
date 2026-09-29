import 'package:flutter/material.dart';
import '../../data/exercise_catalog.dart';
import '../domain/routine_model.dart';
import 'exercise_selection_sheet.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Petto';
  int _sets = 3;
  int _reps = 12;
  int _restSeconds = 60;

  final List<String> _categories = [
    'Petto',
    'Schiena',
    'Gambe',
    'Spalle',
    'Bicipiti',
    'Tricipiti',
    'Core',
    'Altro',
  ];

  void _openCatalog() async {
    final CatalogExercise? selected = await showModalBottomSheet<CatalogExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExerciseSelectionSheet(),
    );

    if (selected != null) {
      setState(() {
        _nameController.text = selected.name;
        _selectedCategory = selected.category;
      });
    }
  }

  void _saveExercise() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome dell\'esercizio')),
      );
      return;
    }

    final newExercise = RoutineExercise(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      sets: _sets,
      reps: _reps,
      restSeconds: _restSeconds,
      notes: _notesController.text.trim(),
    );

    Navigator.pop(context, newExercise);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo Esercizio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome esercizio',
                hintText: 'es. Panca piana',
                prefixIcon: const Icon(Icons.fitness_center),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.menu_book_outlined, color: Colors.deepOrange),
                  tooltip: 'Scegli dal catalogo',
                  onPressed: _openCatalog,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Categoria Muscolare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildNumberCounter(
                    label: 'Serie',
                    value: _sets,
                    onDecrement: _sets > 1 ? () => setState(() => _sets--) : null,
                    onIncrement: () => setState(() => _sets++),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberCounter(
                    label: 'Reps Target',
                    value: _reps,
                    onDecrement: _reps > 1 ? () => setState(() => _reps--) : null,
                    onIncrement: () => setState(() => _reps++),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNumberCounter(
              label: 'Riposo (secondi)',
              value: _restSeconds,
              step: 5,
              onDecrement: _restSeconds > 5 ? () => setState(() => _restSeconds -= 5) : null,
              onIncrement: () => setState(() => _restSeconds += 5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (opzionale)',
                hintText: 'es. Focus sull\'eccentrica',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Salva Esercizio', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberCounter({
    required String label,
    required int value,
    int step = 1,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onDecrement,
                color: Colors.deepOrange,
              ),
              Text(
                '$value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onIncrement,
                color: Colors.deepOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
