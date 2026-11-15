import 'dart:convert';

String _id(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw ArgumentError('IDs must contain 1-128 letters, numbers, underscores or hyphens.');
  }
  return value;
}

class Exercise {
  final String id;
  final String name;
  final bool archived;
  Exercise({required String id, required String name, this.archived = false})
      : id = _id(id), name = name.trim() {
    if (this.name.isEmpty || this.name.length > 100) {
      throw ArgumentError('Exercise names must contain 1-100 characters.');
    }
  }
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'archived': archived};
}

class TrainingSet {
  final double weight;
  final int reps;
  TrainingSet({required this.weight, required this.reps}) {
    if (!weight.isFinite || weight < 0 || weight > 10000) {
      throw ArgumentError('Weight must be between 0 and 10000 kg.');
    }
    if (reps < 1 || reps > 10000) throw ArgumentError('Repetitions must be between 1 and 10000.');
  }
  Map<String, Object?> toJson() => {'weight': weight, 'reps': reps};
}

class WorkoutEntry {
  final String exerciseId;
  final List<TrainingSet> sets;
  WorkoutEntry({required String exerciseId, required List<TrainingSet> sets})
      : exerciseId = _id(exerciseId), sets = List.unmodifiable(sets) {
    if (sets.isEmpty) throw ArgumentError('An exercise needs at least one set.');
  }
  Map<String, Object?> toJson() => {'exerciseId': exerciseId, 'sets': sets.map((set) => set.toJson()).toList()};
}

class Workout {
  final String id;
  final DateTime date;
  final List<WorkoutEntry> entries;
  Workout({required String id, required DateTime date, required List<WorkoutEntry> entries})
      : id = _id(id), date = DateTime(date.year, date.month, date.day), entries = List.unmodifiable(entries) {
    if (date.year < 1 || date.year > 9999) throw ArgumentError('Invalid workout date.');
    if (entries.isEmpty) throw ArgumentError('A workout needs at least one exercise.');
    if (entries.map((entry) => entry.exerciseId).toSet().length != entries.length) {
      throw ArgumentError('Duplicate workout exercise.');
    }
  }
  Map<String, Object?> toJson() => {'id': id, 'date': _dateText(date), 'entries': entries.map((entry) => entry.toJson()).toList()};
}

String _dateText(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Journal {
  final List<Exercise> exercises;
  final List<Workout> workouts;
  Journal({required List<Exercise> exercises, required List<Workout> workouts})
      : exercises = List.unmodifiable(exercises), workouts = List.unmodifiable(workouts) {
    final exerciseIds = exercises.map((exercise) => exercise.id).toSet();
    if (exerciseIds.length != exercises.length) throw ArgumentError('Duplicate exercise ID.');
    if (workouts.map((workout) => workout.id).toSet().length != workouts.length) throw ArgumentError('Duplicate workout ID.');
    for (final workout in workouts) {
      for (final entry in workout.entries) {
        if (!exerciseIds.contains(entry.exerciseId)) throw ArgumentError('Workout references an unknown exercise.');
      }
    }
  }
  factory Journal.empty() => Journal(exercises: [
    Exercise(id: 'squat', name: 'Squat'),
    Exercise(id: 'bench-press', name: 'Bench press'),
    Exercise(id: 'deadlift', name: 'Deadlift'),
  ], workouts: []);
  Map<String, Object?> toJson() => {'schemaVersion': 1, 'exercises': exercises.map((exercise) => exercise.toJson()).toList(), 'workouts': workouts.map((workout) => workout.toJson()).toList()};
  String toBackupJson() => const JsonEncoder.withIndent('  ').convert(toJson());
  factory Journal.fromBackupJson(String source) => Journal.fromJson(jsonDecode(source));
  factory Journal.fromJson(Object? source) {
    try {
      final root = _object(source);
      if (root['schemaVersion'] is! int || root['schemaVersion'] != 1) throw const FormatException('Unsupported backup schema version.');
      final exercises = _list(root['exercises']).map((value) {
        final item = _object(value);
        if (item['archived'] is! bool) throw const FormatException('Invalid archived flag.');
        return Exercise(id: _string(item['id']), name: _string(item['name']), archived: item['archived'] as bool);
      }).toList();
      final workouts = _list(root['workouts']).map((value) {
        final item = _object(value);
        return Workout(id: _string(item['id']), date: _parseDate(item['date']), entries: _list(item['entries']).map((value) {
          final entry = _object(value);
          return WorkoutEntry(exerciseId: _string(entry['exerciseId']), sets: _list(entry['sets']).map((value) {
            final set = _object(value);
            if (set['weight'] is! num || set['reps'] is! int) throw const FormatException('Invalid set weight or repetitions.');
            return TrainingSet(weight: (set['weight'] as num).toDouble(), reps: set['reps'] as int);
          }).toList());
        }).toList());
      }).toList();
      return Journal(exercises: exercises, workouts: workouts);
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }
  String toCsv() {
    final names = {for (final exercise in exercises) exercise.id: exercise.name};
    final lines = <String>['Date,Exercise,Set,Weight (kg),Repetitions'];
    final sorted = [...workouts]..sort((a, b) => a.date.compareTo(b.date));
    for (final workout in sorted) {
      for (final entry in workout.entries) {
        for (var index = 0; index < entry.sets.length; index++) {
          final set = entry.sets[index];
          lines.add([_dateText(workout.date), _csvText(names[entry.exerciseId]!), '${index + 1}', '${set.weight}', '${set.reps}'].join(','));
        }
      }
    }
    return '${lines.join('\r\n')}\r\n';
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException('Expected a JSON object.');
  return value;
}
List<dynamic> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected a JSON array.');
  return value;
}
String _string(Object? value) {
  if (value is! String) throw const FormatException('Expected a string.');
  return value;
}
DateTime _parseDate(Object? value) {
  final text = _string(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) throw const FormatException('Invalid workout date.');
  final parts = text.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]);
  if (parts[0] < 1 || _dateText(date) != text) throw const FormatException('Invalid workout date.');
  return date;
}
String _csvText(String value) {
  // Spreadsheets can interpret imported text as formulas, even after whitespace.
  if (RegExp(r'^[\s]*[=+@-]').hasMatch(value) || value.contains('\t') || value.contains('\r')) value = "'$value";
  return '"${value.replaceAll('"', '""')}"';
}
