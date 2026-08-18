import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/paw_ui.dart';
import '../widgets/pet_species_icon.dart';

Future<void> showAddTaskSheet(
  BuildContext context,
  CareStore store, {
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTaskSheet(store: store, initialDate: initialDate),
  );
}

Future<void> showEditTaskSheet(
  BuildContext context,
  CareStore store,
  CareTask task,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTaskSheet(store: store, task: task),
  );
}

Future<void> showEditRoutineSheet(
  BuildContext context,
  CareStore store,
  CareRoutine routine,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTaskSheet(
      store: store,
      task: store.taskForRoutine(routine),
      editRoutine: true,
    ),
  );
}

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({
    required this.store,
    this.initialDate,
    this.task,
    this.editRoutine = false,
    super.key,
  }) : assert(!editRoutine || task != null);

  final CareStore store;
  final DateTime? initialDate;
  final CareTask? task;
  final bool editRoutine;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  late DateTime _dueAt;
  bool _hasDueTime = false;
  TaskKind _kind = TaskKind.oneOff;
  CareCategory _category = CareCategory.feeding;
  TaskPriority _priority = TaskPriority.normal;
  final Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  final Set<String> _selectedPetIds = {};
  String? _selectedCaregiverId;
  bool _showPetError = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      final routine = widget.editRoutine
          ? widget.store.routineForTask(task)
          : null;
      _title.text = routine?.title ?? task.title;
      _kind = task.kind;
      _category = routine?.category ?? task.category;
      _priority = routine?.priority ?? task.priority;
      _hasDueTime = routine?.hasDueTime ?? task.hasDueTime;
      _dueAt = routine == null
          ? task.dueAt
          : DateTime(
              routine.startDate.year,
              routine.startDate.month,
              routine.startDate.day,
              routine.hour,
              routine.minute,
            );
      _weekdays
        ..clear()
        ..addAll(routine?.weekdays ?? const <int>{});
      final petIds = routine?.petIds ?? task.petIds;
      _selectedPetIds.addAll(
        petIds.isEmpty
            ? widget.store.household?.pets.map((pet) => pet.id) ?? const []
            : petIds,
      );
      return;
    }
    final initial = widget.initialDate ?? DateTime.now();
    final now = DateTime.now();
    _dueAt = DateTime(
      initial.year,
      initial.month,
      initial.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(
        () => _dueAt = DateTime(
          date.year,
          date.month,
          date.day,
          _dueAt.hour,
          _dueAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time != null) {
      setState(() {
        _dueAt = DateTime(
          _dueAt.year,
          _dueAt.month,
          _dueAt.day,
          time.hour,
          time.minute,
        );
        _hasDueTime = true;
      });
    }
  }

  Future<void> _save() async {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (_selectedPetIds.isEmpty) {
      setState(() => _showPetError = true);
    }
    if (!formIsValid || _selectedPetIds.isEmpty) return;
    final dueAt = _hasDueTime
        ? _dueAt
        : DateTime(_dueAt.year, _dueAt.month, _dueAt.day);
    final task = widget.task;
    if (task == null) {
      await widget.store.addTask(
        title: _title.text,
        category: _category,
        kind: _kind,
        priority: _priority,
        dueAt: dueAt,
        hasDueTime: _hasDueTime,
        weekdays: _weekdays,
        petIds: Set.of(_selectedPetIds),
        assignee: _selectedCaregiver,
      );
    } else if (widget.editRoutine) {
      await widget.store.updateTask(
        task: task,
        title: _title.text,
        category: _category,
        priority: _priority,
        dueAt: dueAt,
        hasDueTime: _hasDueTime,
        weekdays: _weekdays,
        petIds: Set.of(_selectedPetIds),
      );
    } else {
      await widget.store.updateTaskOccurrence(
        task: task,
        title: _title.text,
        category: _category,
        priority: _priority,
        dueAt: dueAt,
        hasDueTime: _hasDueTime,
        petIds: Set.of(_selectedPetIds),
      );
    }
    if (!mounted) return;
    final error = widget.store.errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(top: PawSpace.xxxl, bottom: bottomPadding),
      child: Material(
        color: pawCream,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PawRadius.xxl),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: PawSpace.md),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pawMutedSoft.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(PawRadius.sm),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.xl,
                    PawSpace.lg,
                    PawSpace.sm,
                    PawSpace.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pawLavender,
                          borderRadius: BorderRadius.circular(PawRadius.md),
                        ),
                        child: Icon(
                          widget.task == null
                              ? Icons.add_rounded
                              : Icons.edit_rounded,
                          color: pawPurpleInk,
                        ),
                      ),
                      const SizedBox(width: PawSpace.md),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _sheetTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('task-form-scroll'),
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.xl,
                      PawSpace.sm,
                      PawSpace.xl,
                      PawSpace.xxl,
                    ),
                    children: [
                      _scheduleSummary(),
                      const SizedBox(height: 16),
                      _petSelector(),
                      if (widget.task == null) ...[
                        const SizedBox(height: PawSpace.lg),
                        _caregiverSelector(),
                      ],
                      const SizedBox(height: PawSpace.lg),
                      PawCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frequency',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: PawSpace.md),
                            SegmentedButton<TaskKind>(
                              segments: const [
                                ButtonSegment(
                                  value: TaskKind.oneOff,
                                  icon: Icon(Icons.event_rounded),
                                  label: Text('One-time'),
                                ),
                                ButtonSegment(
                                  value: TaskKind.routine,
                                  icon: Icon(Icons.autorenew_rounded),
                                  label: Text('Routine'),
                                ),
                              ],
                              selected: {_kind},
                              onSelectionChanged: widget.task == null
                                  ? (value) =>
                                        setState(() => _kind = value.first)
                                  : null,
                            ),
                            if (widget.task != null) ...[
                              const SizedBox(height: PawSpace.sm),
                              Text(
                                widget.editRoutine
                                    ? 'Changes apply to every upcoming occurrence.'
                                    : _isRoutineOccurrenceEdit
                                    ? 'Only this day changes. Manage the regular schedule in Pets.'
                                    : 'Task frequency cannot be changed while editing.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: pawMuted),
                              ),
                            ],
                            if (_kind == TaskKind.routine &&
                                !_isRoutineOccurrenceEdit) ...[
                              const SizedBox(height: PawSpace.lg),
                              Text(
                                'Repeats on',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: pawPurpleDark),
                              ),
                              const SizedBox(height: PawSpace.sm),
                              Wrap(
                                spacing: PawSpace.sm,
                                runSpacing: PawSpace.sm,
                                children: List.generate(7, (index) {
                                  final weekday = index + 1;
                                  const labels = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ];
                                  final selected = _weekdays.contains(weekday);
                                  const names = [
                                    'Monday',
                                    'Tuesday',
                                    'Wednesday',
                                    'Thursday',
                                    'Friday',
                                    'Saturday',
                                    'Sunday',
                                  ];
                                  return ChoiceChip(
                                    label: SizedBox(
                                      width: 28,
                                      height: 24,
                                      child: Center(child: Text(labels[index])),
                                    ),
                                    tooltip: names[index],
                                    selected: selected,
                                    showCheckmark: false,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          _weekdays.add(weekday);
                                        } else if (_weekdays.length > 1) {
                                          _weekdays.remove(weekday);
                                        }
                                      });
                                    },
                                    selectedColor: pawPurpleInk,
                                    side: BorderSide(
                                      color: selected
                                          ? pawPurpleInk
                                          : pawPurple.withValues(alpha: .28),
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : pawPurpleInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: PawSpace.lg),
                      PawCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Care category',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: PawSpace.md),
                            GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: PawSpace.sm,
                              mainAxisSpacing: PawSpace.sm,
                              childAspectRatio: 1.05,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: CareCategory.values
                                  .map(_categoryTile)
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PawSpace.lg),
                      PawCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What needs to be done?',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: PawSpace.md),
                            TextFormField(
                              key: const ValueKey('task-title-field'),
                              controller: _title,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: _input('For example: Morning meal'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Add a task name.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PawSpace.lg),
                      PawCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isRoutineOccurrenceEdit
                                  ? 'Date and optional time for this day'
                                  : _kind == TaskKind.routine
                                  ? 'Start date and optional time'
                                  : 'Date and optional time',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: PawSpace.md),
                            Row(
                              children: [
                                if (!_isRoutineOccurrenceEdit) ...[
                                  Expanded(
                                    child: _pickerButton(
                                      Icons.calendar_today_rounded,
                                      friendlyDate(_dueAt, includeYear: true),
                                      _pickDate,
                                    ),
                                  ),
                                  const SizedBox(width: PawSpace.md),
                                ],
                                Expanded(
                                  child: _hasDueTime
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _pickerButton(
                                                Icons.schedule_rounded,
                                                friendlyTime(_dueAt),
                                                _pickTime,
                                              ),
                                            ),
                                            IconButton(
                                              key: const ValueKey(
                                                'clear-task-time',
                                              ),
                                              tooltip: 'Remove time',
                                              onPressed: () => setState(
                                                () => _hasDueTime = false,
                                              ),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                          ],
                                        )
                                      : _pickerButton(
                                          Icons.add_alarm_rounded,
                                          'Add time (optional)',
                                          _pickTime,
                                          key: const ValueKey('add-task-time'),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PawSpace.lg),
                      PawCard(
                        padding: const EdgeInsets.all(PawSpace.md),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0x22ED6F82),
                              child: Icon(
                                Icons.priority_high_rounded,
                                color: pawRoseInk,
                              ),
                            ),
                            const SizedBox(width: PawSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Urgent care',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: PawSpace.xxs),
                                  Text(
                                    'Make this stand out for both caregivers.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: pawMuted),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _priority == TaskPriority.urgent,
                              activeTrackColor: pawRoseInk,
                              onChanged: (value) => setState(
                                () => _priority = value
                                    ? TaskPriority.urgent
                                    : TaskPriority.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PawSpace.xl),
                      PawFilledButton(
                        label: _saveLabel,
                        icon: Icons.check_rounded,
                        onPressed: _save,
                      ),
                      if (widget.editRoutine) ...[
                        const SizedBox(height: PawSpace.sm),
                        TextButton.icon(
                          key: const ValueKey('delete-routine-button'),
                          onPressed: _deleteRoutine,
                          style: TextButton.styleFrom(
                            foregroundColor: pawRoseInk,
                            minimumSize: const Size(
                              double.infinity,
                              pawMinTouch,
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete routine'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleSummary() => PawCard(
    padding: const EdgeInsets.all(PawSpace.md),
    color: pawLavender.withValues(alpha: .72),
    child: Row(
      children: [
        const Icon(Icons.calendar_month_rounded, color: pawPurpleInk),
        const SizedBox(width: PawSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRoutineOccurrenceEdit
                    ? 'Changing only this occurrence'
                    : widget.editRoutine
                    ? 'Regular schedule starts'
                    : 'Scheduled for',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: pawMuted),
              ),
              const SizedBox(height: PawSpace.xxs),
              Text(
                _hasDueTime
                    ? '${friendlyDate(_dueAt, includeYear: true)} · ${friendlyTime(_dueAt)}'
                    : '${friendlyDate(_dueAt, includeYear: true)} · Any time',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  bool get _isRoutineOccurrenceEdit =>
      widget.task?.routineId != null && !widget.editRoutine;

  Caregiver? get _selectedCaregiver => _selectedCaregiverId == null
      ? null
      : widget.store.caregivers
            .where((person) => person.id == _selectedCaregiverId)
            .firstOrNull;

  String get _sheetTitle {
    if (widget.task == null) return 'A new care moment';
    if (widget.editRoutine) return 'Edit routine';
    if (_isRoutineOccurrenceEdit) return 'Edit this day';
    return 'Edit care task';
  }

  String get _saveLabel {
    if (widget.task == null) return 'Save task';
    if (widget.editRoutine) return 'Save routine';
    if (_isRoutineOccurrenceEdit) return 'Save for this day';
    return 'Save changes';
  }

  Future<void> _deleteRoutine() async {
    final task = widget.task;
    if (!widget.editRoutine || task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this routine?'),
        content: const Text(
          'All upcoming occurrences will be removed. Completed care records are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pawRoseInk),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteTask(task);
    if (!mounted || widget.store.errorMessage != null) return;
    Navigator.pop(context);
  }

  Widget _petSelector() {
    final pets = widget.store.household?.pets ?? const <Pet>[];
    return PawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who is this for?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PawSpace.xs),
          Text(
            'Select one or more pets.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: pawMuted),
          ),
          const SizedBox(height: PawSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = pets.length == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - PawSpace.md) / 2;
              return Wrap(
                spacing: PawSpace.md,
                runSpacing: PawSpace.md,
                children: pets.map((pet) {
                  final selected = _selectedPetIds.contains(pet.id);
                  return SizedBox(
                    width: tileWidth,
                    child: Semantics(
                      checked: selected,
                      label: pet.name,
                      child: InkWell(
                        key: ValueKey('task-pet-${pet.id}'),
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedPetIds.remove(pet.id);
                          } else {
                            _selectedPetIds.add(pet.id);
                          }
                          _showPetError = false;
                        }),
                        borderRadius: BorderRadius.circular(PawRadius.lg),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          constraints: const BoxConstraints(
                            minHeight: pawMinTouch + 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: PawSpace.md,
                            vertical: PawSpace.md,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? pawPurple.withValues(alpha: .11)
                                : pawCream,
                            borderRadius: BorderRadius.circular(PawRadius.lg),
                            border: Border.all(
                              color: selected
                                  ? pawPurpleInk
                                  : pawPurple.withValues(alpha: .18),
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected ? pawPurpleInk : pawLavender,
                                  borderRadius: BorderRadius.circular(
                                    PawRadius.md,
                                  ),
                                ),
                                child: PetSpeciesIcon(
                                  species: pet.species,
                                  color: selected
                                      ? Colors.white
                                      : pawPurpleDark,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: PawSpace.sm),
                              Expanded(
                                child: Text(
                                  pet.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected ? pawPurpleInk : pawMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_showPetError) ...[
            const SizedBox(height: PawSpace.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: pawRoseInk,
                  ),
                  const SizedBox(width: PawSpace.xs + 1),
                  Text(
                    'Choose at least one pet.',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: pawRoseInk),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caregiverSelector() {
    final caregivers = [...widget.store.caregivers];
    final current = widget.store.currentCaregiver;
    if (current != null &&
        !caregivers.any((caregiver) => caregiver.id == current.id)) {
      caregivers.insert(0, current);
    }
    return PawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Caregiver', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PawSpace.xs),
          Text(
            'Choose who will take care of this task, or leave it unassigned.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: pawMuted),
          ),
          const SizedBox(height: PawSpace.md),
          Wrap(
            spacing: PawSpace.sm,
            runSpacing: PawSpace.sm,
            children: [
              ChoiceChip(
                key: const ValueKey('task-caregiver-unassigned'),
                avatar: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Unassigned'),
                selected: _selectedCaregiverId == null,
                onSelected: (_) => setState(() => _selectedCaregiverId = null),
              ),
              ...caregivers.map(
                (caregiver) => ChoiceChip(
                  key: ValueKey('task-caregiver-${caregiver.id}'),
                  avatar: CircleAvatar(
                    child: Text(
                      caregiver.name.isEmpty
                          ? '?'
                          : caregiver.name.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  label: Text(
                    caregiver.id == widget.store.currentCaregiver?.id
                        ? '${caregiver.name} (you)'
                        : caregiver.name,
                  ),
                  selected: _selectedCaregiverId == caregiver.id,
                  onSelected: (_) =>
                      setState(() => _selectedCaregiverId = caregiver.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(CareCategory category) {
    final selected = _category == category;
    final color = categoryColor(category);
    final ink = categoryInk(category);
    return Semantics(
      selected: selected,
      button: true,
      label: category.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? color.withValues(alpha: .14) : pawCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.lg),
          side: BorderSide(
            color: selected ? ink : pawPurple.withValues(alpha: .12),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _category = category),
          child: Padding(
            padding: const EdgeInsets.all(PawSpace.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(categoryIcon(category), color: ink, size: 24),
                const SizedBox(height: PawSpace.xs),
                Text(
                  category.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Key? key,
  }) => OutlinedButton.icon(
    key: key,
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      foregroundColor: pawPurpleDark,
      minimumSize: const Size(0, pawMinTouch),
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.md),
      ),
      side: BorderSide(color: pawPurple.withValues(alpha: .28)),
    ),
  );

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    fillColor: pawLavender.withValues(alpha: .45),
  );
}
