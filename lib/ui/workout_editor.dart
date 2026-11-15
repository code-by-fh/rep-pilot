import 'package:flutter/material.dart';

import '../main.dart'
    show
        askExerciseName,
        confirm,
        displayDate,
        newId,
        weightText,
        newestWorkouts;
import '../model.dart';

class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({
    super.key,
    required this.journal,
    required this.onSave,
    required this.onCreateExercise,
    this.workout,
    this.onDelete,
  });
  final Journal journal;
  final Workout? workout;
  final Future<void> Function(Workout) onSave;
  final Future<Exercise> Function(String name) onCreateExercise;
  final Future<void> Function()? onDelete;
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _SetDraft {
  _SetDraft({String weight = '', String reps = ''})
    : weight = TextEditingController(text: weight),
      reps = TextEditingController(text: reps);
  final TextEditingController weight;
  final TextEditingController reps;
  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _EntryDraft {
  _EntryDraft(this.exerciseId, this.sets);
  final String exerciseId;
  final List<_SetDraft> sets;
  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  final _form = GlobalKey<FormState>();
  final _entries = <_EntryDraft>[];
  late final List<Exercise> _exercises;
  bool _creating = false;
  bool get _busy => _saving || _creating;
  late DateTime _date;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _date = widget.workout?.date ?? DateTime.now();
    _exercises = [...widget.journal.exercises];
    for (final entry in widget.workout?.entries ?? <WorkoutEntry>[]) {
      _entries.add(
        _EntryDraft(entry.exerciseId, [
          for (final set in entry.sets)
            _SetDraft(weight: weightText(set.weight), reps: '${set.reps}'),
        ]),
      );
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (!_dirty || _error != null)
      setState(() {
        _dirty = true;
        _error = null;
      });
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (_dirty &&
        !await confirm(
          context,
          'Änderungen verwerfen?',
          'Deine ungespeicherten Änderungen am Training gehen verloren. Bereits angelegte Übungen bleiben in der Bibliothek.',
          'Verwerfen',
        ))
      return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _datePicker() async {
    if (_busy) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null && mounted && date != _date)
      setState(() {
        _date = date;
        _dirty = true;
      });
  }

  Future<void> _addExercise() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final available =
        _exercises
            .where(
              (exercise) =>
                  !exercise.archived &&
                  !_entries.any((entry) => entry.exerciseId == exercise.id),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .7,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('exercise-picker'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Übung auswählen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Keine weiteren aktiven Übungen. Lege eine neue Übung an.',
                      ),
                    ),
                  for (final item in available)
                    ListTile(
                      key: ValueKey('choose-exercise-${item.id}'),
                      title: Text(item.name),
                      trailing: const Icon(Icons.add),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const ValueKey('create-exercise'),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.add),
                label: const Text('Neue Übung anlegen'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == true) {
      await _createExercise();
    } else if (selected is Exercise) {
      _appendExercise(selected);
    }
  }

  Future<void> _createExercise() async {
    if (_busy) return;
    try {
      final name = await askExerciseName(context);
      if (!mounted || name == null || name.trim().isEmpty || _busy) return;
      setState(() {
        _creating = true;
        _error = null;
      });
      final exercise = await widget.onCreateExercise(name.trim());
      if (!mounted) return;
      _exercises.add(exercise);
      _appendExercise(exercise);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Die Übung konnte nicht angelegt werden. Deine Trainingseingaben bleiben erhalten. Bitte erneut versuchen.',
        );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _appendExercise(Exercise exercise) {
    final previous = newestWorkouts(widget.journal);
    TrainingSet? last;
    for (final workout in previous) {
      for (final entry in workout.entries) {
        if (entry.exerciseId == exercise.id) {
          last = entry.sets.last;
          break;
        }
      }
      if (last != null) break;
    }
    setState(() {
      _entries.add(
        _EntryDraft(exercise.id, [
          _SetDraft(
            weight: last == null ? '' : weightText(last.weight),
            reps: last == null ? '' : '${last.reps}',
          ),
        ]),
      );
      _dirty = true;
      _error = null;
    });
  }

  void _addSet(_EntryDraft entry) {
    final previous = entry.sets.last;
    setState(() {
      entry.sets.add(
        _SetDraft(weight: previous.weight.text, reps: previous.reps.text),
      );
      _dirty = true;
    });
  }

  Future<void> _removeEntry(_EntryDraft entry) async {
    if (!await confirm(
      context,
      'Übung entfernen?',
      'Alle Sätze dieser Übung werden aus diesem Training entfernt.',
      'Entfernen',
    ))
      return;
    if (!mounted) return;
    setState(() {
      _entries.remove(entry);
      _dirty = true;
    });
    // Rebuild the form before disposing controllers that its fields use.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  void _removeSet(_EntryDraft entry, _SetDraft set) {
    setState(() {
      entry.sets.remove(set);
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => set.dispose());
  }

  String? _weightError(String? text) {
    final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
    return value == null || !value.isFinite || value < 0 || value > 10000
        ? '0–10000 kg eingeben'
        : null;
  }

  String? _repsError(String? text) {
    final value = int.tryParse((text ?? '').trim());
    return value == null || value < 1 || value > 10000
        ? '1–10000 eingeben'
        : null;
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (_entries.isEmpty) {
      setState(
        () => _error = 'Füge vor dem Speichern mindestens eine Übung hinzu.',
      );
      return;
    }
    final visibleFieldsValid = _form.currentState!.validate();
    final allSetsValid = _entries.every(
      (entry) => entry.sets.every(
        (set) =>
            _weightError(set.weight.text) == null &&
            _repsError(set.reps.text) == null,
      ),
    );
    if (!visibleFieldsValid || !allSetsValid) {
      setState(
        () => _error = 'Prüfe Gewicht und Wiederholungen in allen Sätzen, auch weiter oben oder unten.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final workout = Workout(
        id: widget.workout?.id ?? newId(),
        date: _date,
        entries: [
          for (final entry in _entries)
            WorkoutEntry(
              exerciseId: entry.exerciseId,
              sets: [
                for (final set in entry.sets)
                  TrainingSet(
                    weight: double.parse(
                      set.weight.text.trim().replaceAll(',', '.'),
                    ),
                    reps: int.parse(set.reps.text.trim()),
                  ),
              ],
            ),
        ],
      );
      await widget.onSave(workout);
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _dirty = false;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Das Training konnte nicht gespeichert werden. Deine Eingaben bleiben erhalten. Bitte erneut versuchen.';
        });
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (!await confirm(
      context,
      'Training löschen?',
      'Dieses Training und alle zugehörigen Sätze werden dauerhaft gelöscht.',
      'Löschen',
    ))
      return;
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onDelete!();
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _dirty = false;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Das Training konnte nicht gelöscht werden. Bitte erneut versuchen.';
        });
    }
  }

  Widget _setRow(_EntryDraft entry, _SetDraft set, int index) {
    final weight = TextFormField(
      key: ValueKey('${entry.exerciseId}-weight-$index'),
      controller: set.weight,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Gewicht (kg)'),
      validator: _weightError,
      onChanged: (_) => _changed(),
    );
    final reps = TextFormField(
      key: ValueKey('${entry.exerciseId}-reps-$index'),
      controller: set.reps,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Wiederholungen'),
      validator: _repsError,
      onChanged: (_) => _changed(),
    );
    return Padding(
      key: ObjectKey(set),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SATZ ${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                tooltip: 'Satz ${index + 1} entfernen',
                onPressed: _busy || entry.sets.length == 1
                    ? null
                    : () => _removeSet(entry, set),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? Column(children: [weight, const SizedBox(height: 12), reps])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: weight),
                      const SizedBox(width: 12),
                      Expanded(child: reps),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(_EntryDraft entry) {
    final exercise = _exercises.firstWhere(
      (exercise) => exercise.id == entry.exerciseId,
    );
    return Card(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '${exercise.name} entfernen',
                  onPressed: _busy ? null : () => _removeEntry(entry),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (exercise.archived) const Text('Archivierte Übung'),
            for (var index = 0; index < entry.sets.length; index++)
              _setRow(entry, entry.sets[index], index),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _busy ? null : () => _addSet(entry),
              icon: const Icon(Icons.add),
              label: const Text('Satz hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Zurück',
          onPressed: _busy ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.workout == null ? 'Neues Training' : 'Training bearbeiten',
        ),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Training löschen',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: LayoutBuilder(
              builder: (context, viewport) => Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        key: const ValueKey('workout-fields'),
                        padding: const EdgeInsets.all(20),
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _datePicker,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(displayDate(_date)),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Halte dein Training fest. Sieh deinen Fortschritt.',
                          ),
                          const SizedBox(height: 24),
                          if (_entries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Wähle eine Übung aus oder lege eine neue an. Gib für jeden Satz Gewicht und Wiederholungen ein. Nutze 0 kg für Übungen mit dem eigenen Körpergewicht.',
                              ),
                            ),
                          for (final entry in _entries) _entryCard(entry),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _addExercise,
                            icon: const Icon(Icons.add),
                            label: const Text('Übung hinzufügen'),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: viewport.maxHeight < 384
                                  ? viewport.maxHeight / 4
                                  : 96,
                            ),
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          key: const ValueKey('save-training'),
                          onPressed: _busy ? null : _save,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _creating
                                ? 'Übung wird angelegt...'
                                : _saving
                                ? 'Wird gespeichert...'
                                : 'Training speichern',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
