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
  await tester.pumpWidget(
    RepPilotApp(repository: JournalRepository(storage: storage)),
  );
  await tester.pumpAndSettle();
}

Future<void> startSquat(WidgetTester tester) async {
  await tester.tap(find.text('Neues Training'));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.text('Übung hinzufügen'),
    find.byKey(const ValueKey('workout-fields')),
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
  expect(find.text('Übung hinzufügen').hitTestable(), findsOneWidget);
  await tester.tap(find.text('Übung hinzufügen'));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.byKey(const ValueKey('choose-exercise-squat')),
    find.byKey(const ValueKey('exercise-picker')),
    const Offset(0, -120),
  );
  // The picker must leave enough room for an entire row at large text sizes.
  expect(
    tester.getSize(find.byKey(const ValueKey('exercise-picker'))).height,
    greaterThanOrEqualTo(
      tester
          .getSize(find.byKey(const ValueKey('choose-exercise-squat')))
          .height,
    ),
  );
  // Center the complete tap target rather than only revealing its top edge.
  await Scrollable.ensureVisible(
    tester.element(find.byKey(const ValueKey('choose-exercise-squat'))),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('choose-exercise-squat')).hitTestable(),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('choose-exercise-squat')));
  await tester.pumpAndSettle();
}

Future<void> fillFirstSet(
  WidgetTester tester,
  String weight,
  String reps,
) async {
  final weightField = find.byKey(const ValueKey('squat-weight-0'));
  final repsField = find.byKey(const ValueKey('squat-reps-0'));
  await tester.ensureVisible(weightField);
  await tester.pumpAndSettle();
  await tester.enterText(weightField, weight);
  await tester.ensureVisible(repsField);
  await tester.pumpAndSettle();
  await tester.enterText(repsField, reps);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> saveTraining(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('save-training'));
  await tester.pumpAndSettle();
  expect(save.hitTestable(), findsOneWidget);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> openExerciseCreation(WidgetTester tester) async {
  final add = find.text('Übung hinzufügen');
  await tester.dragUntilVisible(
    add,
    find.byKey(const ValueKey('workout-fields')),
    const Offset(0, -160),
  );
  await tester.pumpAndSettle();
  expect(add.hitTestable(), findsOneWidget);
  await tester.tap(add);
  await tester.pumpAndSettle();
  final create = find.byKey(const ValueKey('create-exercise'));
  expect(create.hitTestable(), findsOneWidget);
  await tester.tap(create);
  await tester.pumpAndSettle();
}

Future<void> submitExerciseName(WidgetTester tester, String name) async {
  await tester.enterText(
    find.byKey(const ValueKey('exercise-name-input')),
    name,
  );
  await tester.tap(find.byKey(const ValueKey('save-exercise-name')));
  await tester.pumpAndSettle();
}

void main() {
  late bool previousHitTestWarnings;
  setUp(() {
    previousHitTestWarnings = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = previousHitTestWarnings;
  });

  testWidgets(
    'German defaults include localized Material date picker controls',
    (tester) async {
      await launch(tester, MemoryStorage());
      final context = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(context).languageCode, 'de');
      expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Abbrechen');
      await tester.tap(find.text('Übungen'));
      await tester.pumpAndSettle();
      expect(find.text('Kniebeuge'), findsOneWidget);
      expect(find.text('Bankdrücken'), findsOneWidget);
      expect(find.text('Kreuzheben'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Training'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(displayDate(DateTime.now())));
      await tester.pumpAndSettle();
      final picker = find.byType(DatePickerDialog);
      expect(picker, findsOneWidget);
      final localized = MaterialLocalizations.of(tester.element(picker));
      expect(Localizations.localeOf(tester.element(picker)).languageCode, 'de');
      expect(find.text(localized.datePickerHelpText), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
      expect(
        find.byKey(const ValueKey('save-training')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an empty journal can create an exercise while composing its first training',
    (tester) async {
      final storage = MemoryStorage()
        ..source = Journal(exercises: [], workouts: []).toBackupJson();
      await launch(tester, storage);
      await tester.tap(find.text('Neues Training'));
      await tester.pumpAndSettle();
      await openExerciseCreation(tester);
      await submitExerciseName(tester, 'Rudern');
      expect(storage.writes, 1);
      final exerciseOnly = Journal.fromBackupJson(storage.source!);
      expect(exerciseOnly.exercises.single.name, 'Rudern');
      expect(exerciseOnly.workouts, isEmpty);
      final id = exerciseOnly.exercises.single.id;
      final weight = find.byKey(ValueKey('$id-weight-0'));
      final reps = find.byKey(ValueKey('$id-reps-0'));
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '52,5');
      await tester.ensureVisible(reps);
      await tester.enterText(reps, '10');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await saveTraining(tester);
      expect(storage.writes, 2);
      final saved = Journal.fromBackupJson(storage.source!);
      expect(saved.exercises, hasLength(1));
      final entry = saved.workouts.single.entries.single;
      expect(entry.exerciseId, id);
      expect(entry.sets.single.weight, 52.5);
      expect(entry.sets.single.reps, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed exercise creation leaves no phantom and preserves training fields on retry',
    (tester) async {
      final storage = MemoryStorage()..source = Journal.empty().toBackupJson();
      final original = storage.source;
      await launch(tester, storage);
      await startSquat(tester);
      await fillFirstSet(tester, '72,5', '7');
      storage.failWrites = true;
      await openExerciseCreation(tester);
      await submitExerciseName(tester, 'Rudern');
      expect(storage.writes, 0);
      expect(storage.source, original);
      expect(find.text('Rudern'), findsNothing);
      expect(
        find.text(
          'Die Übung konnte nicht angelegt werden. Deine Trainingseingaben bleiben erhalten. Bitte erneut versuchen.',
        ),
        findsOneWidget,
      );
      final squatWeight = find.byKey(const ValueKey('squat-weight-0'));
      final squatReps = find.byKey(const ValueKey('squat-reps-0'));
      await tester.ensureVisible(squatWeight);
      expect(
        tester.widget<TextFormField>(squatWeight).controller!.text,
        '72,5',
      );
      expect(tester.widget<TextFormField>(squatReps).controller!.text, '7');
      storage.failWrites = false;
      await openExerciseCreation(tester);
      await submitExerciseName(tester, 'Rudern');
      expect(storage.writes, 1);
      final durable = Journal.fromBackupJson(storage.source!);
      expect(
        durable.exercises.where((exercise) => exercise.name == 'Rudern'),
        hasLength(1),
      );
      expect(durable.workouts, isEmpty);
      final id = durable.exercises
          .singleWhere((exercise) => exercise.name == 'Rudern')
          .id;
      final rowWeight = find.byKey(ValueKey('$id-weight-0'));
      final rowReps = find.byKey(ValueKey('$id-reps-0'));
      await tester.ensureVisible(rowWeight);
      await tester.enterText(rowWeight, '50');
      await tester.ensureVisible(rowReps);
      await tester.enterText(rowReps, '10');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await saveTraining(tester);
      expect(storage.writes, 2);
      final saved = Journal.fromBackupJson(storage.source!);
      final entries = saved.workouts.single.entries;
      expect(entries, hasLength(2));
      expect(entries.first.exerciseId, 'squat');
      expect(entries.first.sets.single.weight, 72.5);
      expect(entries.first.sets.single.reps, 7);
      expect(entries.last.exerciseId, id);
      expect(entries.last.sets.single.weight, 50);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'records decimal comma weights and prefills the latest saved set',
    (tester) async {
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
      expect(
        tester.widget<TextFormField>(weightField).controller!.text,
        '62,5',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('squat-reps-0')))
            .controller!
            .text,
        '8',
      );
    },
  );

  testWidgets('latest saved session wins when two workouts share a date', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final date = DateTime(2026, 11, 15);
    storage.source = Journal(
      exercises: [Exercise(id: 'squat', name: 'Squat')],
      workouts: [
        Workout(
          id: 'first',
          date: date,
          entries: [
            WorkoutEntry(
              exerciseId: 'squat',
              sets: [TrainingSet(weight: 60, reps: 8)],
            ),
          ],
        ),
        Workout(
          id: 'last',
          date: date,
          entries: [
            WorkoutEntry(
              exerciseId: 'squat',
              sets: [TrainingSet(weight: 65, reps: 6)],
            ),
          ],
        ),
      ],
    ).toBackupJson();
    await launch(tester, storage);
    await startSquat(tester);
    final field = find.byKey(const ValueKey('squat-weight-0'));
    await tester.ensureVisible(field);
    expect(tester.widget<TextFormField>(field).controller!.text, '65');
  });

  testWidgets(
    'failed persistence retains the form and permits a successful retry',
    (tester) async {
      final storage = MemoryStorage()..failWrites = true;
      await launch(tester, storage);
      await startSquat(tester);
      await fillFirstSet(tester, '80', '5');
      await saveTraining(tester);
      expect(storage.source, isNull);
      expect(
        find.textContaining('Deine Eingaben bleiben erhalten'),
        findsOneWidget,
      );
      storage.failWrites = false;
      await saveTraining(tester);
      expect(storage.writes, 1);
      expect(
        Journal.fromBackupJson(storage.source!)
            .workouts
            .single
            .entries
            .single
            .sets
            .single
            .weight,
        80,
      );
    },
  );

  testWidgets('zero repetitions cannot be persisted', (tester) async {
    final storage = MemoryStorage();
    await launch(tester, storage);
    await startSquat(tester);
    await fillFirstSet(tester, '0', '0');
    await saveTraining(tester);
    expect(storage.writes, 0);
    expect(find.text('Training bearbeiten'), findsNothing);
    expect(
      find.byKey(const ValueKey('save-training')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.textContaining('Prüfe Gewicht und Wiederholungen in allen Sätzen'),
      findsOneWidget,
    );
    await fillFirstSet(tester, '0', '5');
    await saveTraining(tester);
    expect(storage.writes, 1);
    expect(
      Journal.fromBackupJson(storage.source!)
          .workouts
          .single
          .entries
          .single
          .sets
          .single
          .reps,
      5,
    );
  });

  testWidgets('invalid sets outside the visible form still block saving', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final workout = Workout(
      id: 'long-session',
      date: DateTime(2026, 11, 15),
      entries: [
        WorkoutEntry(
          exerciseId: 'squat',
          sets: List.generate(12, (_) => TrainingSet(weight: 80, reps: 5)),
        ),
      ],
    );
    storage.source = Journal(
      exercises: [Exercise(id: 'squat', name: 'Squat')],
      workouts: [workout],
    ).toBackupJson();
    await launch(tester, storage);
    await tester.tap(find.text(displayDate(workout.date)));
    await tester.pumpAndSettle();
    await fillFirstSet(tester, '-1', '5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('workout-fields')),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('squat-weight-0')).hitTestable(),
      findsNothing,
    );
    await saveTraining(tester);
    expect(storage.writes, 0);
    expect(
      find.textContaining('Prüfe Gewicht und Wiederholungen in allen Sätzen'),
      findsOneWidget,
    );
    expect(
      Journal.fromBackupJson(storage.source!)
          .workouts
          .single
          .entries
          .single
          .sets
          .first
          .weight,
      80,
    );
  });

  testWidgets('save remains reachable with large text and an open keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final storage = MemoryStorage();
    await launch(tester, storage);
    await startSquat(tester);
    await fillFirstSet(tester, '0', '0');
    await saveTraining(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('save-training')).hitTestable(),
      findsOneWidget,
    );
    expect(storage.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unreadable stored data is preserved and never replaced automatically',
    (tester) async {
      final storage = MemoryStorage()..source = 'not valid JSON';
      await launch(tester, storage);
      expect(
        find.textContaining('konnte nicht geladen werden'),
        findsOneWidget,
      );
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(storage.source, 'not valid JSON');
      expect(storage.writes, 0);
      expect(find.text('Neues Training'), findsNothing);
    },
  );

  testWidgets(
    'backup restore requires preview and explicit replacement confirmation',
    (tester) async {
      final storage = MemoryStorage();
      await launch(tester, storage);
      await tester.tap(find.text('Daten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sicherung wiederherstellen'));
      await tester.pumpAndSettle();
      final backup = Journal(
        exercises: [Exercise(id: 'pull-up', name: 'Pull-up')],
        workouts: [],
      );
      await tester.enterText(find.byType(TextField), backup.toBackupJson());
      await tester.tap(find.text('Sicherung prüfen'));
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Alle Daten ersetzen?'), findsOneWidget);
      expect(storage.writes, 0);
      await tester.tap(find.text('Daten ersetzen'));
      await tester.pumpAndSettle();
      expect(
        Journal.fromBackupJson(storage.source!).exercises.single.name,
        'Pull-up',
      );
    },
  );

  testWidgets('small screens and large text keep the main tabs usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester, MemoryStorage());
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Übungen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Daten'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
