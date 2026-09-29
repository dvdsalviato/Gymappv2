import 'package:flutter/material.dart';
import '../domain/routine_model.dart';
import 'edit_routine_screen.dart';
import 'workout_runner_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  final List<WorkoutRoutine> _routines = [
    WorkoutRoutine(
      id: '1',
      name: 'test',
      exercises: [
        RoutineExercise(
          name: 'Panca piana con manubri',
          category: 'Petto',
          sets: 3,
          reps: 12,
          restSeconds: 60,
        ),
      ],
    ),
  ];

  void _startWorkout(WorkoutRoutine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutRunnerScreen(routine: routine),
      ),
    );
  }

  void _openEditRoutine(WorkoutRoutine routine, int index) async {
    final WorkoutRoutine? updated = await Navigator.push<WorkoutRoutine>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRoutineScreen(routine: routine),
      ),
    );

    if (updated != null) {
      setState(() {
        _routines[index] = updated;
      });
    }
  }

  void _createNewRoutine() async {
    final newRoutine = WorkoutRoutine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Nuova Scheda',
      exercises: [],
    );

    final WorkoutRoutine? created = await Navigator.push<WorkoutRoutine>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRoutineScreen(routine: newRoutine),
      ),
    );

    if (created != null) {
      setState(() {
        _routines.add(created);
      });
    }
  }

  void _deleteRoutine(int index) {
    setState(() {
      _routines.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SchedePage(
        routines: _routines,
        onStart: _startWorkout,
        onEdit: _openEditRoutine,
        onCreate: _createNewRoutine,
        onDelete: _deleteRoutine,
      ),
      const StoricoPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gymapp, Davide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                'Gymapp',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Tema scuro'),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: _isDarkMode,
              onChanged: (val) => setState(() => _isDarkMode = val),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Il mio profilo'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendario presenze'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.accessibility_new_outlined),
              title: const Text('Mappa muscolare'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Assistente AI'),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Schede',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Storico',
          ),
        ],
      ),
    );
  }
}

class SchedePage extends StatelessWidget {
  final List<WorkoutRoutine> routines;
  final Function(WorkoutRoutine) onStart;
  final Function(WorkoutRoutine, int) onEdit;
  final VoidCallback onCreate;
  final Function(int) onDelete;

  const SchedePage({
    super.key,
    required this.routines,
    required this.onStart,
    required this.onEdit,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: [
          const Text(
            'Schede',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Le tue schede di allenamento',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAlignment: CrossAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            routine.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code, size: 20),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => onDelete(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${routine.exercises.length} esercizi',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => onStart(routine),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Inizia'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => onEdit(routine, index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuova scheda', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class StoricoPage extends StatelessWidget {
  const StoricoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: const [
          Text(
            'Storico',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            'I tuoi allenamenti, per scheda ed esercizio',
            style: TextStyle(color: Colors.grey),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Nessuna serie registrata ancora.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
