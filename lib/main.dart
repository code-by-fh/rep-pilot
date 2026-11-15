import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final JournalRepository _repository = widget.repository ?? JournalRepository();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rep Pilot', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCCFF73), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF111411),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    home: JournalPage(repository: _repository),
  );
}

String displayDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
String weightText(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
List<Workout> newestWorkouts(Journal journal) {
  final positions = {for (var i = 0; i < journal.workouts.length; i++) journal.workouts[i].id: i};
  return [...journal.workouts]..sort((a, b) {
    final dateOrder = b.date.compareTo(a.date);
    return dateOrder != 0 ? dateOrder : positions[b.id]!.compareTo(positions[a.id]!);
  });
}

Future<bool> confirm(BuildContext context, String title, String message, String action) async =>
  await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [
    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
    FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
  ])) ?? false;

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
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _error = null);
    try { final value = await widget.repository.load(); if (mounted) setState(() => _journal = value); }
    catch (_) { if (mounted) setState(() => _error = 'Your journal could not be loaded. Saved data has not been replaced.'); }
  }
  Future<void> _save(Journal value) async {
    setState(() => _busy = true);
    try { await widget.repository.save(value); if (mounted) setState(() => _journal = value); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  void _notice(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> _editWorkout([Workout? workout]) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => WorkoutEditor(
      journal: _journal!, workout: workout,
      onSave: (saved) => _save(Journal(exercises: _journal!.exercises, workouts: [
        ..._journal!.workouts.where((item) => item.id != saved.id), saved])),
      onDelete: workout == null ? null : () => _save(Journal(exercises: _journal!.exercises,
        workouts: _journal!.workouts.where((item) => item.id != workout.id).toList())),
    )));
  }
  Future<void> _nameExercise([Exercise? exercise]) async {
    final name = await showDialog<String>(context: context, builder: (_) => _ExerciseNameDialog(exercise: exercise));
    if (name == null || !mounted) return;
    final saved = Exercise(id: exercise?.id ?? newId(), name: name, archived: exercise?.archived ?? false);
    try { await _save(Journal(exercises: [for (final item in _journal!.exercises) if (item.id != saved.id) item, saved], workouts: _journal!.workouts)); }
    catch (_) { _notice('Could not save the exercise. Please try again.'); }
  }
  Future<void> _archive(Exercise exercise) async {
    try { await _save(Journal(exercises: [for (final item in _journal!.exercises)
      item.id == exercise.id ? Exercise(id: item.id, name: item.name, archived: !item.archived) : item], workouts: _journal!.workouts)); }
    catch (_) { _notice('Could not update the exercise. Please try again.'); }
  }
  void _history(Exercise exercise) {
    final workouts = newestWorkouts(_journal!).where((workout) => workout.entries.any((entry) => entry.exerciseId == exercise.id)).toList();
    final sets = workouts.expand((workout) => workout.entries.where((entry) => entry.exerciseId == exercise.id).expand((entry) => entry.sets)).toList();
    final maximum = sets.fold<double>(0, (max, set) => set.weight > max ? set.weight : max);
    final last = workouts.isEmpty ? null : workouts.first.entries.firstWhere((entry) => entry.exerciseId == exercise.id).sets.last;
    Navigator.push<void>(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: Text(exercise.name)), body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('EXERCISE HISTORY', style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 16),
        Text(sets.isEmpty ? 'No sets recorded yet.' : 'Last: ${weightText(last!.weight)} kg  ·  Best: ${weightText(maximum)} kg', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        for (final workout in workouts) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayDate(workout.date), style: Theme.of(context).textTheme.titleMedium),
          for (final entry in workout.entries.where((entry) => entry.exerciseId == exercise.id))
            for (var i = 0; i < entry.sets.length; i++) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Set ${i + 1}  ·  ${weightText(entry.sets[i].weight)} kg × ${entry.sets[i].reps} reps')),
        ]))),
      ]),
    )));
  }
  Future<void> _backup() async {
    final backup = _journal!.toBackupJson();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('JSON backup'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: SelectableText(backup))), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(onPressed: () async {
          try { await Clipboard.setData(ClipboardData(text: backup)); if (context.mounted) Navigator.pop(context); _notice('JSON backup copied. Save it in a safe place.'); }
          catch (_) { _notice('Could not copy the backup. Select the JSON text to copy it manually.'); }
        }, icon: const Icon(Icons.copy), label: const Text('Copy JSON')),
      ]));
  }
  Future<void> _import() async {
    final imported = await showDialog<Journal>(context: context, builder: (_) => const _ImportDialog());
    if (imported == null || !mounted) return;
    if (!await confirm(context, 'Replace all data?', 'Your current journal will be replaced with ${imported.workouts.length} training sessions and ${imported.exercises.length} exercises. Export a backup first if you want to keep it.', 'Replace data')) return;
    if (!mounted) return;
    try { await _save(imported); _notice('Backup restored.'); }
    catch (_) { _notice('Restore failed. Your current journal remains available.'); }
  }
  Widget _training(Journal journal) {
    final workouts = newestWorkouts(journal);
    final setCount = workouts.fold<int>(0, (total, workout) => total + workout.entries.fold<int>(0, (total, entry) => total + entry.sets.length));
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), children: [
      Text('BUILD YOUR\nNEXT BEST.', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05)),
      const SizedBox(height: 12), const Text('One session. One set. A little stronger.'), const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 32, runSpacing: 16, children: [_stat('${workouts.length}', 'SESSIONS'), _stat('$setCount', 'SETS LOGGED')]))),
      const SizedBox(height: 24), Text('YOUR TRAINING', style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 12),
      if (workouts.isEmpty) const _Empty(icon: Icons.fitness_center, title: 'Your first set starts here', text: 'Add an exercise in the Exercises tab, then record your first training session.'),
      for (final workout in workouts) Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(displayDate(workout.date)),
        subtitle: Text('${workout.entries.map((entry) => journal.exercises.firstWhere((exercise) => exercise.id == entry.exerciseId).name).join(', ')}\n${workout.entries.fold<int>(0, (count, entry) => count + entry.sets.length)} sets'),
        trailing: const Icon(Icons.chevron_right), onTap: _busy ? null : () => _editWorkout(workout))),
    ]);
  }
  Widget _stat(String value, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    Text(label, style: Theme.of(context).textTheme.labelSmall),
  ]);
  Widget _exercises(Journal journal) {
    final exercises = [...journal.exercises]..sort((a, b) { if (a.archived != b.archived) return a.archived ? 1 : -1; return a.name.toLowerCase().compareTo(b.name.toLowerCase()); });
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), children: [
      Text('Your movement\nlibrary.', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), const Text('Choose an exercise to see every set. Archive exercises to keep your history and simplify your next session.'), const SizedBox(height: 24),
      if (exercises.isEmpty) const _Empty(icon: Icons.add_circle_outline, title: 'Make it your routine', text: 'Add your first exercise to begin.'),
      for (final exercise in exercises) Card(child: ListTile(title: Text(exercise.name), subtitle: Text(exercise.archived ? 'Archived · history preserved' : 'View training history'),
        onTap: () => _history(exercise), trailing: PopupMenuButton<String>(enabled: !_busy, tooltip: 'Exercise options',
          onSelected: (value) { if (value == 'rename') { _nameExercise(exercise); } else { _archive(exercise); } }, itemBuilder: (_) => [
            const PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'archive', child: Text(exercise.archived ? 'Unarchive' : 'Archive'))]))),
    ]);
  }
  Widget _data() => ListView(padding: const EdgeInsets.all(20), children: [
    Text('Your progress.\nYour data.', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12), const Text('Everything is stored on this device. No account is needed. Keep regular backups before reinstalling or changing devices.'), const SizedBox(height: 24),
    Card(child: Column(children: [
      ListTile(leading: const Icon(Icons.data_object), title: const Text('JSON backup'), subtitle: const Text('View and copy a complete backup'), onTap: _busy ? null : _backup),
      ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Copy CSV'), subtitle: const Text('Training rows for your spreadsheet'), onTap: _busy ? null : () async {
        try { await Clipboard.setData(ClipboardData(text: _journal!.toCsv())); _notice('CSV copied. Paste it into a spreadsheet or text file.'); }
        catch (_) { _notice('Could not copy CSV. Please try again.'); }
      }),
      ListTile(leading: const Icon(Icons.restore), title: const Text('Restore backup'), subtitle: const Text('Import JSON and replace local data'), onTap: _busy ? null : _import),
    ])),
  ]);
  @override
  Widget build(BuildContext context) {
    final journal = _journal;
    return Scaffold(
      appBar: AppBar(title: const Text('REP PILOT', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800)), actions: const [Padding(padding: EdgeInsets.only(right: 20), child: Icon(Icons.fitness_center))]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child:
        journal == null ? (_error == null ? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), FilledButton(onPressed: _load, child: const Text('Retry'))])))) : Column(children: [if (_busy) const LinearProgressIndicator(), Expanded(child: [_training(journal), _exercises(journal), _data()][_tab])])))),
      floatingActionButton: journal == null || _tab == 2 ? null : FloatingActionButton.extended(onPressed: _busy ? null : () {
        if (_tab == 1) { _nameExercise(); } else if (!journal.exercises.any((exercise) => !exercise.archived)) { _notice('Add or unarchive an exercise first.'); setState(() => _tab = 1); } else { _editWorkout(); }
      }, icon: const Icon(Icons.add), label: Text(_tab == 1 ? 'Add exercise' : 'New training')),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (value) => setState(() => _tab = value), destinations: const [
        NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Training'), NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Exercises'), NavigationDestination(icon: Icon(Icons.storage_rounded), label: 'Data'),
      ]),
    );
  }
}
class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Column(children: [
    Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center),
  ]));
}
class _ExerciseNameDialog extends StatefulWidget {
  const _ExerciseNameDialog({this.exercise});
  final Exercise? exercise;
  @override
  State<_ExerciseNameDialog> createState() => _ExerciseNameDialogState();
}
class _ExerciseNameDialogState extends State<_ExerciseNameDialog> {
  late final _controller = TextEditingController(text: widget.exercise?.name ?? '');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true, title: Text(widget.exercise == null ? 'Add exercise' : 'Rename exercise'),
    content: Form(key: _form, child: TextFormField(controller: _controller, autofocus: true, maxLength: 100, textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Exercise name'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter an exercise name.' : null)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, _controller.text.trim()); }, child: const Text('Save'))]);
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
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Restore JSON backup'),
    content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Paste a Rep Pilot backup. Restore replaces every exercise and training entry currently on this device.'), const SizedBox(height: 16),
      TextField(controller: _controller, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: 'Backup JSON', errorText: _error), onChanged: (_) => setState(() { _imported = null; _error = null; })),
      if (_imported != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text('Ready to restore ${_imported!.exercises.length} exercises and ${_imported!.workouts.length} training sessions.')),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { if (_imported != null) { Navigator.pop(context, _imported); return; }
        try { final parsed = Journal.fromBackupJson(_controller.text); setState(() { _imported = parsed; _error = null; }); }
        catch (_) { setState(() => _error = 'Invalid or unsupported Rep Pilot backup.'); }
      }, child: Text(_imported == null ? 'Preview backup' : 'Continue'))]);
}
