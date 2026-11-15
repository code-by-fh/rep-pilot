import 'package:flutter/material.dart';

import '../main.dart'
    show confirm, displayDate, newId, weightText, newestWorkouts;
import '../model.dart';

class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({
    super.key,
    required this.journal,
    required this.onSave,
    this.workout,
    this.onDelete,
  });
  final Journal journal;
  final Workout? workout;
  final Future<void> Function(Workout) onSave;
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
  late DateTime _date;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _date = widget.workout?.date ?? DateTime.now();
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
    if (_saving) return;
    if (_dirty &&
        !await confirm(
          context,
          'Discard changes?',
          'Your unsaved training changes will be lost.',
          'Discard',
        ))
      return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _datePicker() async {
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
    final available =
        widget.journal.exercises
            .where(
              (exercise) =>
                  !exercise.archived &&
                  !_entries.any((entry) => entry.exerciseId == exercise.id),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No more active exercises. Add or unarchive an exercise in your library.',
          ),
        ),
      );
      return;
    }
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Choose exercise',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('exercise-picker'),
                children: [
                  for (final item in available)
                    ListTile(
                      title: Text(item.name),
                      trailing: const Icon(Icons.add),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (exercise == null || !mounted) return;
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
      'Remove exercise?',
      'All sets for this exercise will be removed from this training session.',
      'Remove',
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
        ? 'Enter 0–10000 kg'
        : null;
  }

  String? _repsError(String? text) {
    final value = int.tryParse((text ?? '').trim());
    return value == null || value < 1 || value > 10000 ? 'Enter 1–10000' : null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_entries.isEmpty) {
      setState(() => _error = 'Add at least one exercise before saving.');
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
        () => _error = 'Check weight and repetitions in every set, including sets further up or down the page.',
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
          _error = 'Training could not be saved. Your entries are still here. Please try again.';
        });
    }
  }

  Future<void> _delete() async {
    if (!await confirm(
      context,
      'Delete training?',
      'This training session and all its sets will be permanently removed.',
      'Delete',
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
          _error = 'Training could not be deleted. Please try again.';
        });
    }
  }

  Widget _setRow(_EntryDraft entry, _SetDraft set, int index) {
    final weight = TextFormField(
      key: ValueKey('${entry.exerciseId}-weight-$index'),
      controller: set.weight,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Weight (kg)'),
      validator: _weightError,
      onChanged: (_) => _changed(),
    );
    final reps = TextFormField(
      key: ValueKey('${entry.exerciseId}-reps-$index'),
      controller: set.reps,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Reps'),
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
                  'SET ${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                tooltip: 'Remove set ${index + 1}',
                onPressed: _saving || entry.sets.length == 1
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
    final exercise = widget.journal.exercises.firstWhere(
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
                  tooltip: 'Remove ${exercise.name}',
                  onPressed: _saving ? null : () => _removeEntry(entry),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (exercise.archived) const Text('Archived exercise'),
            for (var index = 0; index < entry.sets.length; index++)
              _setRow(entry, entry.sets[index], index),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _saving ? null : () => _addSet(entry),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.workout == null ? 'New training' : 'Edit training'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete training',
              onPressed: _saving ? null : _delete,
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
                            onPressed: _saving ? null : _datePicker,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(displayDate(_date)),
                          ),
                          const SizedBox(height: 12),
                          const Text('Log the work. Keep the progress.'),
                          const SizedBox(height: 24),
                          if (_entries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Choose an exercise, then enter a weight and repetition count for each set. Use 0 kg for bodyweight movements.',
                              ),
                            ),
                          for (final entry in _entries) _entryCard(entry),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _addExercise,
                            icon: const Icon(Icons.add),
                            label: const Text('Add exercise'),
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
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_saving ? 'Saving...' : 'Save training'),
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
