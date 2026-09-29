class RoutineExercise {
  final String name;
  final String category;
  final int sets;
  final int reps;
  final int restSeconds;
  final String notes;

  RoutineExercise({
    required this.name,
    required this.category,
    this.sets = 3,
    this.reps = 10,
    this.restSeconds = 60,
    this.notes = '',
  });
}

class WorkoutRoutine {
  final String id;
  final String name;
  final List<RoutineExercise> exercises;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
  });
}
