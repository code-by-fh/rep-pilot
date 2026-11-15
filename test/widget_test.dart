import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_pilot/main.dart';
import 'package:rep_pilot/model.dart';
import 'package:rep_pilot/repository.dart';

class MemoryStorage implements JournalStorage {
  String? source;
  bool failWrites = false;
  int writes = 0;
  @override
  Future<String?> read() async => source;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    source = value;
    writes++;
  }
}

Future<void> launch(WidgetTester tester, MemoryStorage storage) async {
  await tester.pumpWidget(RepPilotApp(repository: JournalRepository(storage: storage)));
  await tester.pumpAndSettle();
}

Future<void> startSquat(WidgetTester tester) async {
  await tester.tap(find.text('New training'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Add exercise'));
  await tester.tap(find.text('Add exercise'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat'));
  await tester.pumpAndSettle();
}

Future<void> fillFirstSet(WidgetTester tester, String weight, String reps) async {
  final weightField = find.byKey(const ValueKey('squat-weight-0'));
  final repsField = find.byKey(const ValueKey('squat-reps-0'));
  await tester.ensureVisible(weightField);
  await tester.enterText(weightField, weight);
  await tester.ensureVisible(repsField);
  await tester.enterText(repsField, reps);
  await tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> saveTraining(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('save-training'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('records decimal comma weights and prefills the latest saved set', (tester) async {
    final storage = MemoryStorage();
    await launch(tester, storage);
    await startSquat(tester);
    await fillFirstSet(tester, '62,5', '8');
    await saveTraining(tester);
    expect(storage.writes, 1);
    final saved = Journal.fromBackupJson(storage.source!);
    expect(saved.workouts.single.entries.single.sets.single.weight, 62.5);
    expect(saved.workouts.single.entries.single.sets.single.reps, 8);
    await startSquat(tester);
    final weightField = find.byKey(const ValueKey('squat-weight-0'));
    await tester.ensureVisible(weightField);
    expect(tester.widget<TextFormField>(weightField).controller!.text, '62.5');
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('squat-reps-0'))).controller!.text, '8');
  });

  testWidgets('latest saved session wins when two workouts share a date', (tester) async {
    final storage = MemoryStorage();
    final date = DateTime(2026, 11, 15);
    storage.source = Journal(exercises: [Exercise(id: 'squat', name: 'Squat')], workouts: [
      Workout(id: 'first', date: date, entries: [WorkoutEntry(exerciseId: 'squat', sets: [TrainingSet(weight: 60, reps: 8)])]),
      Workout(id: 'last', date: date, entries: [WorkoutEntry(exerciseId: 'squat', sets: [TrainingSet(weight: 65, reps: 6)])]),
    ]).toBackupJson();
    await launch(tester, storage);
    await startSquat(tester);
    final field = find.byKey(const ValueKey('squat-weight-0'));
    await tester.ensureVisible(field);
    expect(tester.widget<TextFormField>(field).controller!.text, '65');
  });

  testWidgets('failed persistence retains the form and permits a successful retry', (tester) async {
    final storage = MemoryStorage()..failWrites = true;
    await launch(tester, storage);
    await startSquat(tester);
    await fillFirstSet(tester, '80', '5');
    await saveTraining(tester);
    expect(storage.source, isNull);
    expect(find.textContaining('Your entries are still here'), findsOneWidget);
    storage.failWrites = false;
    await saveTraining(tester);
    expect(storage.writes, 1);
    expect(Journal.fromBackupJson(storage.source!).workouts.single.entries.single.sets.single.weight, 80);
  });

  testWidgets('zero repetitions cannot be persisted', (tester) async {
    final storage = MemoryStorage();
    await launch(tester, storage);
    await startSquat(tester);
    await fillFirstSet(tester, '0', '0');
    await saveTraining(tester);
    expect(storage.writes, 0);
    expect(find.text('Edit training'), findsNothing);
    expect(find.byKey(const ValueKey('save-training')), findsOneWidget);
  });

  testWidgets('invalid sets outside the visible form still block saving', (tester) async {
    final storage = MemoryStorage();
    final workout = Workout(id: 'long-session', date: DateTime(2026, 11, 15), entries: [
      WorkoutEntry(exerciseId: 'squat', sets: List.generate(12, (_) => TrainingSet(weight: 80, reps: 5))),
    ]);
    storage.source = Journal(exercises: [Exercise(id: 'squat', name: 'Squat')], workouts: [workout]).toBackupJson();
    await launch(tester, storage);
    await tester.tap(find.text(displayDate(workout.date)));
    await tester.pumpAndSettle();
    await fillFirstSet(tester, '-1', '5');
    await saveTraining(tester);
    expect(storage.writes, 0);
    expect(find.textContaining('Check weight and repetitions in every set'), findsOneWidget);
    expect(Journal.fromBackupJson(storage.source!).workouts.single.entries.single.sets.first.weight, 80);
  });

  testWidgets('unreadable stored data is preserved and never replaced automatically', (tester) async {
    final storage = MemoryStorage()..source = 'not valid JSON';
    await launch(tester, storage);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(storage.source, 'not valid JSON');
    expect(storage.writes, 0);
    expect(find.text('New training'), findsNothing);
  });

  testWidgets('backup restore requires preview and explicit replacement confirmation', (tester) async {
    final storage = MemoryStorage();
    await launch(tester, storage);
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore backup'));
    await tester.pumpAndSettle();
    final backup = Journal(exercises: [Exercise(id: 'pull-up', name: 'Pull-up')], workouts: []);
    await tester.enterText(find.byType(TextField), backup.toBackupJson());
    await tester.tap(find.text('Preview backup'));
    await tester.pumpAndSettle();
    expect(storage.writes, 0);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Replace all data?'), findsOneWidget);
    expect(storage.writes, 0);
    await tester.tap(find.text('Replace data'));
    await tester.pumpAndSettle();
    expect(Journal.fromBackupJson(storage.source!).exercises.single.name, 'Pull-up');
  });

  testWidgets('small screens and large text keep the main tabs usable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester, MemoryStorage());
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
