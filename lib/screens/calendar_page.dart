import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/paw_ui.dart';
import '../widgets/pet_species_icon.dart';
import '../widgets/task_card.dart';

enum _ScheduleFilter { all, routine, oneOff }

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.store,
    required this.onSelectedDateChanged,
    super.key,
  });

  final CareStore store;
  final ValueChanged<DateTime> onSelectedDateChanged;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  _ScheduleFilter _filter = _ScheduleFilter.all;
  String? _selectedPetId;

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        PawSpace.lg,
        PawSpace.sm,
        PawSpace.lg,
        pawListBottomInset(context, hasFab: true),
      ),
      children: [
        if (_pets.length > 1) ...[
          SectionHeader(title: 'Show care for', detail: _selectedPetName),
          const SizedBox(height: PawSpace.sm),
          _petFilter(),
          const SizedBox(height: PawSpace.lg),
        ],
        _calendarCard(),
        const SizedBox(height: PawSpace.lg),
        SectionHeader(title: 'Task type', detail: _filterLabel),
        const SizedBox(height: PawSpace.sm),
        SegmentedButton<_ScheduleFilter>(
          segments: const [
            ButtonSegment(
              value: _ScheduleFilter.all,
              label: Text('All', key: ValueKey('schedule-filter-all')),
            ),
            ButtonSegment(
              value: _ScheduleFilter.routine,
              label: Text('Routine', key: ValueKey('schedule-filter-routine')),
            ),
            ButtonSegment(
              value: _ScheduleFilter.oneOff,
              label: Text('One-time', key: ValueKey('schedule-filter-one-off')),
            ),
          ],
          selected: {_filter},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => _filter = value.first),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : pawPurpleInk,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? pawPurpleInk
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: PawSpace.xxl),
        SectionHeader(
          title: _agendaDate,
          detail: '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: PawSpace.md),
        if (tasks.isEmpty) _emptyAgenda() else ..._agendaSections,
      ],
    );
  }

  Widget _petFilter() => SingleChildScrollView(
    key: const ValueKey('pet-filter-scroll'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _petChoice(),
        for (final pet in _pets) ...[
          const SizedBox(width: PawSpace.sm),
          _petChoice(pet),
        ],
      ],
    ),
  );

  Widget _petChoice([Pet? pet]) {
    final petId = pet?.id;
    final isSelected = _effectivePetId == petId;
    final foreground = isSelected ? Colors.white : pawPurpleInk;
    return ChoiceChip(
      key: ValueKey('pet-filter-${petId ?? 'all'}'),
      selected: isSelected,
      showCheckmark: false,
      avatar: pet == null
          ? Icon(Icons.pets_rounded, size: 17, color: foreground)
          : PetSpeciesIcon(species: pet.species, color: foreground, size: 17),
      label: Text(pet?.name ?? 'All pets'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      selectedColor: pawPurpleInk,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? pawPurpleInk : pawPurple.withValues(alpha: .24),
      ),
      onSelected: (_) => setState(() => _selectedPetId = petId),
    );
  }

  Widget _emptyAgenda() {
    final unfilteredTasks = widget.store.tasksOn(_selectedDate);
    final filtersHideTasks = unfilteredTasks.isNotEmpty && _hasActiveFilters;
    return Column(
      children: [
        PawEmptyState(
          icon: filtersHideTasks
              ? Icons.filter_alt_off_rounded
              : Icons.event_available_rounded,
          title: filtersHideTasks ? 'No matching care' : 'No care planned yet',
          message: filtersHideTasks
              ? _filteredEmptyMessage
              : 'Nothing is scheduled for this date.',
        ),
        if (filtersHideTasks) ...[
          const SizedBox(height: PawSpace.sm),
          OutlinedButton.icon(
            key: const ValueKey('clear-calendar-filters'),
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Clear filters'),
          ),
        ],
      ],
    );
  }

  List<Widget> get _agendaSections {
    final sections = <Widget>[];

    void addSection(String title, String detail, List<CareTask> tasks) {
      if (tasks.isEmpty) return;
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: PawSpace.sm));
      }
      sections
        ..add(SectionHeader(title: title, detail: detail))
        ..add(const SizedBox(height: PawSpace.md))
        ..addAll(_cards(tasks));
    }

    addSection(
      'Needs attention',
      '${_urgentTasks.length} urgent',
      _urgentTasks,
    );
    addSection('Upcoming', '${_upcomingTasks.length} left', _upcomingTasks);
    addSection('Completed', 'Done', _completedTasks);
    addSection('Skipped', '${_skippedTasks.length} hidden', _skippedTasks);
    return sections;
  }

  Iterable<Widget> _cards(List<CareTask> tasks) => tasks.map(
    (task) => Padding(
      padding: const EdgeInsets.only(bottom: PawSpace.md),
      child: TaskCard(task: task, store: widget.store),
    ),
  );

  List<CareTask> get _filteredTasks => _tasksOn(_selectedDate);

  List<CareTask> _tasksOn(DateTime day) => widget.store
      .tasksOn(day)
      .where(_matchesPetFilter)
      .where(_matchesScheduleFilter)
      .toList();

  bool _matchesPetFilter(CareTask task) {
    final petId = _effectivePetId;
    return petId == null || task.petIds.isEmpty || task.petIds.contains(petId);
  }

  bool _matchesScheduleFilter(CareTask task) => switch (_filter) {
    _ScheduleFilter.all => true,
    _ScheduleFilter.routine => task.kind == TaskKind.routine,
    _ScheduleFilter.oneOff => task.kind == TaskKind.oneOff,
  };

  List<CareTask> get _urgentTasks => _filteredTasks
      .where(
        (task) =>
            task.priority == TaskPriority.urgent &&
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.skipped,
      )
      .toList();

  List<CareTask> get _upcomingTasks => _filteredTasks
      .where(
        (task) =>
            task.priority != TaskPriority.urgent &&
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.skipped,
      )
      .toList();

  List<CareTask> get _completedTasks => _filteredTasks
      .where((task) => task.status == TaskStatus.completed)
      .toList();

  List<CareTask> get _skippedTasks => _filteredTasks
      .where((task) => task.status == TaskStatus.skipped)
      .toList();

  List<Pet> get _pets => widget.store.household?.pets ?? const <Pet>[];

  String? get _effectivePetId =>
      _pets.any((pet) => pet.id == _selectedPetId) ? _selectedPetId : null;

  Pet? get _selectedPet => _effectivePetId == null
      ? null
      : _pets.where((pet) => pet.id == _effectivePetId).firstOrNull;

  String get _selectedPetName => _selectedPet?.name ?? 'All pets';

  String get _filterLabel => switch (_filter) {
    _ScheduleFilter.all => 'All tasks',
    _ScheduleFilter.routine => 'Routine',
    _ScheduleFilter.oneOff => 'One-time',
  };

  bool get _hasActiveFilters =>
      _effectivePetId != null || _filter != _ScheduleFilter.all;

  String get _filteredEmptyMessage {
    final pet = _selectedPet;
    final type = switch (_filter) {
      _ScheduleFilter.all => 'care',
      _ScheduleFilter.routine => 'routine care',
      _ScheduleFilter.oneOff => 'one-time care',
    };
    return pet == null
        ? 'No $type matches this date. Clear filters to see all care.'
        : 'No $type for ${pet.name} matches this date. Clear filters to see all household care.';
  }

  void _clearFilters() => setState(() {
    _selectedPetId = null;
    _filter = _ScheduleFilter.all;
  });

  String get _agendaDate {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[_selectedDate.weekday - 1]}, ${friendlyDate(_selectedDate)}';
  }

  Widget _calendarCard() {
    final textTheme = Theme.of(context).textTheme;
    return PawCard(
      padding: const EdgeInsets.all(PawSpace.md),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    children: [
                      Text(
                        _monthTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: PawSpace.xxs),
                      Text(
                        'Routine and extra care together',
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(
                          color: pawMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('calendar-today'),
                onPressed: _goToToday,
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: PawSpace.md),
          _weekdayHeader(),
          const SizedBox(height: PawSpace.xs),
          _monthGrid(),
          const SizedBox(height: PawSpace.md),
          const Wrap(
            spacing: PawSpace.md,
            runSpacing: PawSpace.xs,
            children: [
              _Legend(icon: Icons.circle, text: 'Routine', color: pawPurpleInk),
              _Legend(icon: Icons.circle, text: 'One-time', color: pawBlueInk),
              _Legend(icon: Icons.circle, text: 'Urgent', color: pawRoseInk),
              _Legend(
                icon: Icons.check_rounded,
                text: 'Completed',
                color: pawGreenInk,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdayHeader() {
    const symbols = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Row(
      children: List.generate(
        7,
        (index) => Expanded(
          child: Semantics(
            label: names[index],
            excludeSemantics: true,
            child: Center(
              child: Text(
                symbols[index],
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: pawMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthGrid() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final blanks = firstDay.weekday - 1;
    final days = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final cells = <Widget>[
      ...List.generate(blanks, (_) => const SizedBox.shrink()),
      ...List.generate(days, (index) {
        final day = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          index + 1,
        );
        return _DayCell(
          day: day,
          tasks: _tasksOn(day),
          isSelected: isSameDay(day, _selectedDate),
          isToday: isSameDay(day, DateTime.now()),
          onTap: () {
            setState(() => _selectedDate = day);
            widget.onSelectedDateChanged(day);
          },
        );
      }),
    ];
    return GridView.count(
      crossAxisCount: 7,
      mainAxisSpacing: PawSpace.xs,
      crossAxisSpacing: PawSpace.xxs,
      // Cells stay at least 44pt tall on the narrowest phone so every date
      // remains a comfortable tap target.
      childAspectRatio: .82,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }

  String get _monthTitle {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  void _moveMonth(int value) {
    final firstOfTarget = DateTime(
      _selectedDate.year,
      _selectedDate.month + value,
      1,
    );
    final lastDay = DateTime(
      firstOfTarget.year,
      firstOfTarget.month + 1,
      0,
    ).day;
    final date = DateTime(
      firstOfTarget.year,
      firstOfTarget.month,
      _selectedDate.day.clamp(1, lastDay),
    );
    setState(() => _selectedDate = date);
    widget.onSelectedDateChanged(date);
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _selectedDate = today);
    widget.onSelectedDateChanged(today);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.tasks,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final List<CareTask> tasks;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRoutine = tasks.any((task) => task.kind == TaskKind.routine);
    final hasOneOff = tasks.any((task) => task.kind == TaskKind.oneOff);
    final hasUrgent = tasks.any(
      (task) =>
          task.priority == TaskPriority.urgent &&
          task.status != TaskStatus.completed &&
          task.status != TaskStatus.skipped,
    );
    final allCompleted =
        tasks.isNotEmpty &&
        tasks.every((task) => task.status == TaskStatus.completed);
    final onSelected = isSelected ? Colors.white : null;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticLabel(hasRoutine, hasOneOff, hasUrgent),
      excludeSemantics: true,
      // Material sits above the fill so the ripple is actually visible;
      // an InkWell wrapped around a coloured Container would hide it.
      child: Material(
        color: isSelected ? pawPurpleInk : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.md),
          side: hasUrgent
              ? const BorderSide(color: pawRoseInk, width: 1.5)
              : isToday && !isSelected
              ? const BorderSide(color: pawPurpleInk, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: onSelected ?? pawInk,
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              const SizedBox(height: PawSpace.xxs),
              // Reserved strip keeps every cell the same height whether or
              // not it carries indicators.
              SizedBox(
                height: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tasks.isNotEmpty) ...[
                      Text(
                        '${tasks.length}',
                        style: TextStyle(
                          color: onSelected ?? pawMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 3),
                      if (allCompleted)
                        Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: onSelected ?? pawGreenInk,
                        )
                      else
                        ...tasks
                            .take(3)
                            .map(
                              (task) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 5,
                                  color: onSelected ?? _taskDotColor(task),
                                ),
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel(bool hasRoutine, bool hasOneOff, bool hasUrgent) {
    final parts = <String>[friendlyDate(day, includeYear: true)];
    if (isToday) parts.add('today');
    if (tasks.isEmpty) {
      parts.add('no care planned');
    } else {
      parts.add('${tasks.length} task${tasks.length == 1 ? '' : 's'}');
      if (hasRoutine) parts.add('routine');
      if (hasOneOff) parts.add('one-time');
      if (hasUrgent) parts.add('urgent');
    }
    return parts.join(', ');
  }

  Color _taskDotColor(CareTask task) {
    if (task.status == TaskStatus.completed) return pawGreenInk;
    if (task.status == TaskStatus.skipped) return pawMutedSoft;
    if (task.priority == TaskPriority.urgent) return pawRoseInk;
    return task.kind == TaskKind.routine ? pawPurpleInk : pawBlueInk;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: PawSpace.xs),
      Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0),
      ),
    ],
  );
}
