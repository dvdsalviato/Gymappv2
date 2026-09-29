class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final int restTimeSeconds;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.restTimeSeconds = 90,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'restTimeSeconds': restTimeSeconds,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    name: json['name'],
    sets: json['sets'],
    reps: json['reps'],
    weight: (json['weight'] as num).toDouble(),
    restTimeSeconds: json['restTimeSeconds'] ?? 90,
  );
}

class WorkoutRoutine {
  final String id;
  final String name;
  final List<Exercise> exercises;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) => WorkoutRoutine(
    id: json['id'],
    name: json['name'],
    exercises: (json['exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList(),
  );
}
