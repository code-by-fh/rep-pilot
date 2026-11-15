import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_pilot/model.dart';

Journal sample({String name = 'Squat'}) => Journal(
  exercises: [Exercise(id: 'squat', name: name, archived: true)],
  workouts: [
    Workout(
      id: 'w1',
      date: DateTime(2026, 11, 15, 19, 30),
      entries: [
        WorkoutEntry(
          exerciseId: 'squat',
          sets: [
            TrainingSet(weight: 82.5, reps: 8),
            TrainingSet(weight: 0, reps: 12),
          ],
        ),
      ],
    ),
  ],
);

Map<String, dynamic> backup() =>
    jsonDecode(sample().toBackupJson()) as Map<String, dynamic>;
Map<String, dynamic> workout(Map<String, dynamic> data) =>
    (data['workouts'] as List).first as Map<String, dynamic>;
Map<String, dynamic> entry(Map<String, dynamic> data) =>
    (workout(data)['entries'] as List).first as Map<String, dynamic>;
Map<String, dynamic> trainingSet(Map<String, dynamic> data) =>
    (entry(data)['sets'] as List).first as Map<String, dynamic>;

void main() {
  test('German starter labels preserve stable IDs and imported names', () {
    final defaults = Journal.empty();
    expect(defaults.exercises.map((exercise) => exercise.id), [
      'squat',
      'bench-press',
      'deadlift',
    ]);
    expect(defaults.exercises.map((exercise) => exercise.name), [
      'Kniebeuge',
      'Bankdrücken',
      'Kreuzheben',
    ]);
    final custom = sample(name: 'My own squat');
    expect(
      Journal.fromBackupJson(custom.toBackupJson()).exercises.single.name,
      'My own squat',
    );
    expect(
      custom.toCsv(),
      startsWith('Datum,Übung,Satz,Gewicht (kg),Wiederholungen'),
    );
  });

  test(
    'backup roundtrip preserves dates, fractional weights, archive and sets',
    () {
      final original = sample();
      final restored = Journal.fromBackupJson(original.toBackupJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.workouts.single.date, DateTime(2026, 11, 15));
      expect(restored.workouts.single.entries.single.sets.last.reps, 12);
      expect(restored.exercises.single.archived, isTrue);
    },
  );

  test('domain objects snapshot inputs and expose immutable lists', () {
    final sets = [TrainingSet(weight: 50, reps: 5)];
    final entries = [WorkoutEntry(exerciseId: 'squat', sets: sets)];
    final workouts = [
      Workout(id: 'w1', date: DateTime(2026), entries: entries),
    ];
    final exercises = [Exercise(id: 'squat', name: 'Squat')];
    final journal = Journal(exercises: exercises, workouts: workouts);
    sets.clear();
    entries.clear();
    workouts.clear();
    exercises.clear();
    expect(journal.exercises, hasLength(1));
    expect(journal.workouts.single.entries.single.sets, hasLength(1));
    expect(() => journal.workouts.clear(), throwsUnsupportedError);
    expect(() => journal.exercises.clear(), throwsUnsupportedError);
    expect(
      () => journal.workouts.single.entries.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => journal.workouts.single.entries.single.sets.clear(),
      throwsUnsupportedError,
    );
  });

  test('invalid numeric domain values are rejected', () {
    for (final weight in [
      -1.0,
      10001.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => TrainingSet(weight: weight, reps: 1), throwsArgumentError);
    }
    for (final reps in [-1, 0, 10001]) {
      expect(() => TrainingSet(weight: 0, reps: reps), throwsArgumentError);
    }
    expect(TrainingSet(weight: 10000, reps: 10000).reps, 10000);
  });

  test('malformed JSON and schema versions fail explicitly', () {
    for (final source in [
      '',
      '{',
      'null',
      '[]',
      '{}',
      '{"schemaVersion":2}',
      '{"schemaVersion":1.0}',
    ]) {
      expect(() => Journal.fromBackupJson(source), throwsFormatException);
    }
  });

  test('invalid import values do not silently coerce or normalize', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (data) => trainingSet(data)['weight'] = '82.5',
      (data) => trainingSet(data)['weight'] = double.nan,
      (data) => trainingSet(data)['weight'] = double.infinity,
      (data) => trainingSet(data)['weight'] = -1,
      (data) => trainingSet(data)['reps'] = 8.0,
      (data) => trainingSet(data)['reps'] = 0,
      (data) => trainingSet(data)['reps'] = true,
      (data) => workout(data)['date'] = '2026-02-30',
      (data) => workout(data)['date'] = '2026-13-01',
      (data) => workout(data)['date'] = '0000-01-01',
      (data) => workout(data)['date'] = '2026-11-15T00:00:00Z',
      (data) => workout(data)['id'] = '',
      (data) => entry(data)['exerciseId'] = 'unknown',
      (data) => entry(data)['sets'] = [],
      (data) => workout(data)['entries'] = [],
      (data) => (data['exercises'] as List).first['archived'] = 'false',
      (data) => (data['exercises'] as List).first['name'] = '  ',
      (data) =>
          (data['exercises'] as List).add((data['exercises'] as List).first),
      (data) =>
          (data['workouts'] as List).add((data['workouts'] as List).first),
      (data) => (workout(data)['entries'] as List).add(
        (workout(data)['entries'] as List).first,
      ),
    ];
    for (var index = 0; index < mutations.length; index++) {
      final data = backup();
      mutations[index](data);
      expect(
        () => Journal.fromJson(data),
        throwsFormatException,
        reason: 'Invalid import case $index',
      );
    }
  });

  test('CSV quotes punctuation and prevents spreadsheet formula execution', () {
    final csv = sample(name: '=SUM(1,2) "test"').toCsv();
    expect(csv, contains('"\'=SUM(1,2) ""test"""'));
    expect(csv, contains('2026-11-15,'));
    expect(csv, contains(',1,82.5,8\r\n'));
    expect(csv, contains(',2,0.0,12\r\n'));
    expect(sample(name: '@command').toCsv(), contains('"\'@command"'));
  });

  test(
    'empty journal backup stays empty rather than reintroducing defaults',
    () {
      final empty = Journal(exercises: [], workouts: []);
      expect(Journal.fromBackupJson(empty.toBackupJson()).exercises, isEmpty);
    },
  );
}
