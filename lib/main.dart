import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'model.dart';
import 'repository.dart';
import 'ui/workout_editor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RepPilotApp());
}

class RepPilotApp extends StatefulWidget {
  const RepPilotApp({super.key, this.repository});
  final JournalRepository? repository;
  @override
  State<RepPilotApp> createState() => _RepPilotAppState();
}

class _RepPilotAppState extends State<RepPilotApp> {
  late final JournalRepository _repository =
      widget.repository ?? JournalRepository();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rep Pilot',
    debugShowCheckedModeBanner: false,
    locale: const Locale('de'),
    supportedLocales: const [Locale('de')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFCCFF73),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF111411),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: JournalPage(repository: _repository),
  );
}

String displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';
String weightText(double value) =>
    (value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString())
        .replaceAll('.', ',');
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
List<Workout> newestWorkouts(Journal journal) {
  final positions = {
    for (var i = 0; i < journal.workouts.length; i++) journal.workouts[i].id: i,
  };
  return [...journal.workouts]..sort((a, b) {
    final dateOrder = b.date.compareTo(a.date);
    return dateOrder != 0
        ? dateOrder
        : positions[b.id]!.compareTo(positions[a.id]!);
  });
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.repository});
  final JournalRepository repository;
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  Journal? _journal;
  String? _error;
  bool _busy = false;
  int _tab = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await widget.repository.load();
      if (mounted) setState(() => _journal = value);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Dein Trainingstagebuch konnte nicht geladen werden. Gespeicherte Daten wurden nicht ersetzt.',
        );
    }
  }

  Future<void> _save(Journal value) async {
    setState(() => _busy = true);
    try {
      await widget.repository.save(value);
      if (mounted) setState(() => _journal = value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editWorkout([Workout? workout]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkoutEditor(
          journal: _journal!,
          workout: workout,
          onCreateExercise: _createExercise,
          onSave: (saved) => _save(
            Journal(
              exercises: _journal!.exercises,
              workouts: [
                ..._journal!.workouts.where((item) => item.id != saved.id),
                saved,
              ],
            ),
          ),
          onDelete: workout == null
              ? null
              : () => _save(
                  Journal(
                    exercises: _journal!.exercises,
                    workouts: _journal!.workouts
                        .where((item) => item.id != workout.id)
                        .toList(),
                  ),
                ),
        ),
      ),
    );
  }

  Future<Exercise> _createExercise(String name) async {
    final exercise = Exercise(id: newId(), name: name);
    await _save(
      Journal(
        exercises: [..._journal!.exercises, exercise],
        workouts: _journal!.workouts,
      ),
    );
    return exercise;
  }

  Future<void> _nameExercise([Exercise? exercise]) async {
    final name = await askExerciseName(context, exercise: exercise);
    if (name == null || !mounted) return;
    final saved = Exercise(
      id: exercise?.id ?? newId(),
      name: name,
      archived: exercise?.archived ?? false,
    );
    try {
      await _save(
        Journal(
          exercises: [
            for (final item in _journal!.exercises)
              if (item.id != saved.id) item,
            saved,
          ],
          workouts: _journal!.workouts,
        ),
      );
    } catch (_) {
      _notice(
        'Die Übung konnte nicht gespeichert werden. Bitte erneut versuchen.',
      );
    }
  }

  Future<void> _archive(Exercise exercise) async {
    try {
      await _save(
        Journal(
          exercises: [
            for (final item in _journal!.exercises)
              item.id == exercise.id
                  ? Exercise(
                      id: item.id,
                      name: item.name,
                      archived: !item.archived,
                    )
                  : item,
          ],
          workouts: _journal!.workouts,
        ),
      );
    } catch (_) {
      _notice(
        'Die Übung konnte nicht aktualisiert werden. Bitte erneut versuchen.',
      );
    }
  }

  void _history(Exercise exercise) {
    final workouts = newestWorkouts(_journal!)
        .where(
          (workout) =>
              workout.entries.any((entry) => entry.exerciseId == exercise.id),
        )
        .toList();
    final sets = workouts
        .expand(
          (workout) => workout.entries
              .where((entry) => entry.exerciseId == exercise.id)
              .expand((entry) => entry.sets),
        )
        .toList();
    final maximum = sets.fold<double>(
      0,
      (max, set) => set.weight > max ? set.weight : max,
    );
    final last = workouts.isEmpty
        ? null
        : workouts.first.entries
              .firstWhere((entry) => entry.exerciseId == exercise.id)
              .sets
              .last;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(exercise.name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'ÜBUNGSVERLAUF',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 16),
              Text(
                sets.isEmpty
                    ? 'Noch keine Sätze erfasst.'
                    : 'Zuletzt: ${weightText(last!.weight)} kg  ·  Höchstgewicht: ${weightText(maximum)} kg',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              for (final workout in workouts)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayDate(workout.date),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final entry in workout.entries.where(
                          (entry) => entry.exerciseId == exercise.id,
                        ))
                          for (var i = 0; i < entry.sets.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Satz ${i + 1}  ·  ${weightText(entry.sets[i].weight)} kg × ${entry.sets[i].reps} Wdh.',
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _backup() async {
    final backup = _journal!.toBackupJson();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON-Sicherung'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(backup)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: backup));
                if (context.mounted) Navigator.pop(context);
                _notice(
                  'JSON-Sicherung kopiert. Speichere sie an einem sicheren Ort.',
                );
              } catch (_) {
                _notice(
                  'Die Sicherung konnte nicht kopiert werden. Markiere den JSON-Text, um ihn manuell zu kopieren.',
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('JSON kopieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final imported = await showDialog<Journal>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (imported == null || !mounted) return;
    if (!await confirm(
      context,
      'Alle Daten ersetzen?',
      'Dein Tagebuch wird durch ${imported.workouts.length} Trainingseinheiten und ${imported.exercises.length} Übungen ersetzt. Erstelle vorher eine Sicherung, wenn du die bisherigen Daten behalten möchtest.',
      'Daten ersetzen',
    ))
      return;
    if (!mounted) return;
    try {
      await _save(imported);
      _notice('Sicherung wiederhergestellt.');
    } catch (_) {
      _notice(
        'Die Wiederherstellung ist fehlgeschlagen. Dein bisheriges Tagebuch bleibt erhalten.',
      );
    }
  }

  Widget _training(Journal journal) {
    final workouts = newestWorkouts(journal);
    final setCount = workouts.fold<int>(
      0,
      (total, workout) =>
          total +
          workout.entries.fold<int>(
            0,
            (total, entry) => total + entry.sets.length,
          ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          'DEIN TRAINING.\nDEIN FORTSCHRITT.',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
        ),
        const SizedBox(height: 12),
        const Text('Jedes Training zählt. Jeder Satz bringt dich weiter.'),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _stat('${workouts.length}', 'TRAININGS'),
                _stat('$setCount', 'SÄTZE ERFASST'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('DEIN TRAINING', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        if (workouts.isEmpty)
          const _Empty(
            icon: Icons.fitness_center,
            title: 'Hier beginnt dein erstes Training',
            text: 'Starte ein Training und wähle eine Übung aus oder lege direkt eine neue an.',
          ),
        for (final workout in workouts)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Text(displayDate(workout.date)),
              subtitle: Text(
                '${workout.entries.map((entry) => journal.exercises.firstWhere((exercise) => exercise.id == entry.exerciseId).name).join(', ')}\n${workout.entries.fold<int>(0, (count, entry) => count + entry.sets.length)} Sätze',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _editWorkout(workout),
            ),
          ),
      ],
    );
  }

  Widget _stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
  Widget _exercises(Journal journal) {
    final exercises = [...journal.exercises]
      ..sort((a, b) {
        if (a.archived != b.archived) return a.archived ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          'Deine\nÜbungen.',
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Wähle eine Übung aus, um alle Sätze zu sehen. Archiviere Übungen, die du gerade nicht verwendest. Ihr Verlauf bleibt erhalten.',
        ),
        const SizedBox(height: 24),
        if (exercises.isEmpty)
          const _Empty(
            icon: Icons.add_circle_outline,
            title: 'Gestalte dein Training',
            text: 'Lege deine erste Übung an.',
          ),
        for (final exercise in exercises)
          Card(
            child: ListTile(
              title: Text(exercise.name),
              subtitle: Text(
                exercise.archived
                    ? 'Archiviert · Verlauf bleibt erhalten'
                    : 'Trainingsverlauf ansehen',
              ),
              onTap: () => _history(exercise),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                tooltip: 'Übungsoptionen',
                onSelected: (value) {
                  if (value == 'rename') {
                    _nameExercise(exercise);
                  } else {
                    _archive(exercise);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Umbenennen'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      exercise.archived ? 'Wieder aktivieren' : 'Archivieren',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _data() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Dein Fortschritt.\nDeine Daten.',
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Deine Daten bleiben auf diesem Gerät. Du brauchst kein Konto. Erstelle regelmäßig Sicherungen, besonders vor einer Neuinstallation oder einem Gerätewechsel.',
      ),
      const SizedBox(height: 24),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('JSON-Sicherung'),
              subtitle: const Text(
                'Vollständige Sicherung anzeigen und kopieren',
              ),
              onTap: _busy ? null : _backup,
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV kopieren'),
              subtitle: const Text(
                'Trainingsdaten für deine Tabellenkalkulation',
              ),
              onTap: _busy
                  ? null
                  : () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: _journal!.toCsv()),
                        );
                        _notice(
                          'CSV kopiert. Füge die Daten in eine Tabelle oder Textdatei ein.',
                        );
                      } catch (_) {
                        _notice(
                          'CSV konnte nicht kopiert werden. Bitte erneut versuchen.',
                        );
                      }
                    },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Sicherung wiederherstellen'),
              subtitle: const Text(
                'JSON importieren und lokale Daten ersetzen',
              ),
              onTap: _busy ? null : _import,
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final journal = _journal;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'REP PILOT',
          style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.fitness_center),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: journal == null
                ? (_error == null
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _load,
                                  child: const Text('Erneut versuchen'),
                                ),
                              ],
                            ),
                          ),
                        ))
                : Column(
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      Expanded(
                        child: [
                          _training(journal),
                          _exercises(journal),
                          _data(),
                        ][_tab],
                      ),
                    ],
                  ),
          ),
        ),
      ),
      floatingActionButton: journal == null || _tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy
                  ? null
                  : () {
                      if (_tab == 1) {
                        _nameExercise();
                      } else {
                        _editWorkout();
                      }
                    },
              icon: const Icon(Icons.add),
              label: Text(_tab == 1 ? 'Übung hinzufügen' : 'Neues Training'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Übungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_rounded),
            label: 'Daten',
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

Future<String?> askExerciseName(BuildContext context, {Exercise? exercise}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ExerciseNameDialog(exercise: exercise),
    );

class _ExerciseNameDialog extends StatefulWidget {
  const _ExerciseNameDialog({this.exercise});
  final Exercise? exercise;
  @override
  State<_ExerciseNameDialog> createState() => _ExerciseNameDialogState();
}

class _ExerciseNameDialogState extends State<_ExerciseNameDialog> {
  late final _controller = TextEditingController(
    text: widget.exercise?.name ?? '',
  );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.exercise == null ? 'Neue Übung' : 'Übung umbenennen'),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('exercise-name-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name der Übung'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Gib einen Namen für die Übung ein.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        key: const ValueKey('save-exercise-name'),
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(context, _controller.text.trim());
        },
        child: const Text('Speichern'),
      ),
    ],
  );
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();
  String? _error;
  Journal? _imported;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('JSON-Sicherung wiederherstellen'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Füge eine Rep-Pilot-Sicherung ein. Beim Wiederherstellen werden alle Übungen und Trainingseinheiten auf diesem Gerät ersetzt.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'JSON-Sicherung',
                errorText: _error,
              ),
              onChanged: (_) => setState(() {
                _imported = null;
                _error = null;
              }),
            ),
            if (_imported != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Bereit zur Wiederherstellung von ${_imported!.exercises.length} Übungen und ${_imported!.workouts.length} Trainingseinheiten.',
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (_imported != null) {
            Navigator.pop(context, _imported);
            return;
          }
          try {
            final parsed = Journal.fromBackupJson(_controller.text);
            setState(() {
              _imported = parsed;
              _error = null;
            });
          } catch (_) {
            setState(
              () => _error =
                  'Ungültige oder nicht unterstützte Rep-Pilot-Sicherung.',
            );
          }
        },
        child: Text(_imported == null ? 'Sicherung prüfen' : 'Weiter'),
      ),
    ],
  );
}
