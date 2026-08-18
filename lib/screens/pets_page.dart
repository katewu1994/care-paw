import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/paw_ui.dart';
import '../widgets/pet_species_icon.dart';
import 'add_task_sheet.dart';

class PetsPage extends StatelessWidget {
  const PetsPage({required this.store, super.key});

  final CareStore store;

  @override
  Widget build(BuildContext context) {
    final pets = store.household?.pets ?? const <Pet>[];
    final todayTasks = store.todayTasks
        .where((task) => task.status != TaskStatus.skipped)
        .toList();
    final completed = todayTasks
        .where((task) => task.status == TaskStatus.completed)
        .length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        PawSpace.lg,
        PawSpace.sm,
        PawSpace.lg,
        pawListBottomInset(context),
      ),
      children: [
        _PetsSummary(
          pets: pets,
          completedTasks: completed,
          totalTasks: todayTasks.length,
        ),
        const SizedBox(height: PawSpace.xxl),
        if (pets.isEmpty)
          const PawEmptyState(
            icon: Icons.pets_rounded,
            title: 'No pets yet',
            message: 'Add a pet from the household profile to plan their care.',
          )
        else ...[
          SectionHeader(
            title: 'Your pets',
            detail: '${pets.length} in your care',
          ),
          const SizedBox(height: PawSpace.md),
          ...pets.map(
            (pet) => Padding(
              padding: const EdgeInsets.only(bottom: PawSpace.lg),
              child: _PetCareCard(pet: pet, store: store),
            ),
          ),
        ],
      ],
    );
  }
}

class _PetsSummary extends StatelessWidget {
  const _PetsSummary({
    required this.pets,
    required this.completedTasks,
    required this.totalTasks,
  });

  final List<Pet> pets;
  final int completedTasks;
  final int totalTasks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final progressLabel = totalTasks == 0
        ? 'No care is scheduled for today.'
        : '$completedTasks of $totalTasks household tasks done today.';

    return PawCard(
      color: pawLavender.withValues(alpha: .72),
      padding: const EdgeInsets.all(PawSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARE AT A GLANCE',
                  style: textTheme.labelSmall?.copyWith(
                    color: pawPurpleInk,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: PawSpace.sm),
                Text(
                  pets.length == 1
                      ? 'Everything ${pets.first.name} needs.'
                      : 'Every pet, cared for.',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: PawSpace.sm),
                Text(
                  progressLabel,
                  style: textTheme.bodySmall?.copyWith(color: pawMuted),
                ),
                if (totalTasks > 0) ...[
                  const SizedBox(height: PawSpace.md),
                  Semantics(
                    label:
                        '$completedTasks of $totalTasks household tasks completed today',
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(PawRadius.sm),
                      backgroundColor: Colors.white.withValues(alpha: .8),
                      color: progress == 1 ? pawGreenInk : pawPurple,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: PawSpace.lg),
          _PetIconStack(pets: pets),
        ],
      ),
    );
  }
}

class _PetIconStack extends StatelessWidget {
  const _PetIconStack({required this.pets});

  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) {
      return const _PetAvatar(species: PetSpecies.other, size: 72);
    }

    final visiblePets = pets.take(3).toList();
    return SizedBox(
      width: visiblePets.length == 1 ? 72 : 88,
      height: 88,
      child: Stack(
        children: [
          for (var index = 0; index < visiblePets.length; index++)
            Positioned(
              left: index.isEven ? 0 : 32,
              top: index < 2 ? 0 : 32,
              child: _PetAvatar(species: visiblePets[index].species, size: 56),
            ),
          if (pets.length > visiblePets.length)
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: pawPurpleDark,
                child: Text(
                  '+${pets.length - visiblePets.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PetCareCard extends StatefulWidget {
  const _PetCareCard({required this.pet, required this.store});

  final Pet pet;
  final CareStore store;

  @override
  State<_PetCareCard> createState() => _PetCareCardState();
}

class _PetCareCardState extends State<_PetCareCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final todayTasks = widget.store.todayTasks
        .where(
          (task) =>
              task.status != TaskStatus.skipped && _belongsToPet(task.petIds),
        )
        .toList();
    final completed = todayTasks
        .where((task) => task.status == TaskStatus.completed)
        .length;
    final remaining = todayTasks
        .where((task) => task.status != TaskStatus.completed)
        .toList();
    final routines = widget.store.routines
        .where((routine) => _belongsToPet(routine.petIds))
        .toList();
    final progress = todayTasks.isEmpty ? 0.0 : completed / todayTasks.length;

    return PawCard(
      key: ValueKey('pet-card-${widget.pet.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(PawSpace.lg),
            child: Row(
              children: [
                _PetAvatar(species: widget.pet.species),
                const SizedBox(width: PawSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.pet.name, style: textTheme.titleLarge),
                      const SizedBox(height: PawSpace.xxs),
                      Text(
                        widget.pet.species.label,
                        style: textTheme.bodySmall?.copyWith(color: pawMuted),
                      ),
                    ],
                  ),
                ),
                PawTag(
                  label: remaining.isEmpty
                      ? 'All done'
                      : '${remaining.length} left',
                  color: remaining.isEmpty ? pawGreen : pawPurple,
                  ink: remaining.isEmpty ? pawGreenInk : pawPurpleInk,
                  icon: remaining.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: pawCream.withValues(alpha: .62),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(PawRadius.xxl),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    expanded: _isExpanded,
                    label:
                        '${widget.pet.name} care details, ${_isExpanded ? 'expanded' : 'collapsed'}',
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('pet-toggle-${widget.pet.id}'),
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PawSpace.lg,
                          PawSpace.md,
                          PawSpace.lg,
                          PawSpace.lg,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Today's care",
                                    style: textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  todayTasks.isEmpty
                                      ? 'Nothing scheduled'
                                      : '$completed / ${todayTasks.length} done',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: pawMuted,
                                  ),
                                ),
                                const SizedBox(width: PawSpace.sm),
                                AnimatedRotation(
                                  turns: _isExpanded ? .5 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: pawPurpleInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: PawSpace.sm),
                            Semantics(
                              label:
                                  '$completed of ${todayTasks.length} tasks completed for ${widget.pet.name}',
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(
                                  PawRadius.sm,
                                ),
                                backgroundColor: pawPurple.withValues(
                                  alpha: .12,
                                ),
                                color:
                                    remaining.isEmpty && todayTasks.isNotEmpty
                                    ? pawGreenInk
                                    : pawPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: !_isExpanded
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(
                              PawSpace.lg,
                              0,
                              PawSpace.lg,
                              PawSpace.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (remaining.isNotEmpty)
                                  _NextCare(task: remaining.first),
                                if (routines.isNotEmpty) ...[
                                  if (remaining.isNotEmpty)
                                    const SizedBox(height: PawSpace.lg),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Routine care',
                                          style: textTheme.titleSmall,
                                        ),
                                      ),
                                      Text(
                                        '${routines.length} routine${routines.length == 1 ? '' : 's'}',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: pawMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: PawSpace.xs),
                                  Text(
                                    'Tap a routine to update its regular schedule.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: pawMuted,
                                    ),
                                  ),
                                  const SizedBox(height: PawSpace.sm),
                                  ...routines.map(
                                    (routine) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: PawSpace.sm,
                                      ),
                                      child: _RoutineRow(
                                        routine: routine,
                                        store: widget.store,
                                        petId: widget.pet.id,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _belongsToPet(Set<String> petIds) =>
      petIds.isEmpty || petIds.contains(widget.pet.id);
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.store,
    required this.petId,
  });

  final CareRoutine routine;
  final CareStore store;
  final String petId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.lg),
        side: BorderSide(
          color: categoryColor(routine.category).withValues(alpha: .2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('edit-routine-$petId-${routine.id}'),
        onTap: () => showEditRoutineSheet(context, store, routine),
        child: Padding(
          padding: const EdgeInsets.all(PawSpace.md),
          child: Row(
            children: [
              CategoryIcon(category: routine.category, size: 40),
              const SizedBox(width: PawSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.title, style: textTheme.titleSmall),
                    const SizedBox(height: PawSpace.xxs),
                    Text(
                      '${_routineDays(routine.weekdays)} · ${routine.hasDueTime ? friendlyTime(_routineTime) : 'Any time'}',
                      style: textTheme.bodySmall?.copyWith(color: pawMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PawSpace.sm),
              const Icon(Icons.edit_rounded, size: 20, color: pawPurpleInk),
            ],
          ),
        ),
      ),
    );
  }

  DateTime get _routineTime =>
      DateTime(2000, 1, 1, routine.hour, routine.minute);

  String _routineDays(Set<int> weekdays) {
    if (weekdays.length == 7) return 'Every day';
    if (_sameDays(weekdays, const {1, 2, 3, 4, 5})) return 'Weekdays';
    if (_sameDays(weekdays, const {6, 7})) return 'Weekends';
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = weekdays.toList()..sort();
    return days.map((day) => labels[day - 1]).join(', ');
  }

  bool _sameDays(Set<int> first, Set<int> second) =>
      first.length == second.length && first.containsAll(second);
}

class _NextCare extends StatelessWidget {
  const _NextCare({required this.task});

  final CareTask task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = task.status == TaskStatus.claimed
        ? '${task.assignee?.name ?? 'Someone'} is handling this'
        : 'Needs someone';

    return Container(
      padding: const EdgeInsets.all(PawSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PawRadius.lg),
        border: Border.all(
          color: categoryColor(task.category).withValues(alpha: .2),
        ),
      ),
      child: Row(
        children: [
          CategoryIcon(category: task.category, size: 40),
          const SizedBox(width: PawSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: textTheme.titleSmall),
                const SizedBox(height: PawSpace.xxs),
                Text(
                  '${task.hasDueTime ? friendlyTime(task.dueAt) : 'Any time'} · $status',
                  style: textTheme.bodySmall?.copyWith(color: pawMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.species, this.size = 56});

  final PetSpecies species;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: pawPurple.withValues(alpha: .18)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120E0621),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: PetSpeciesIcon(
      species: species,
      color: pawPurpleDark,
      size: size * .5,
    ),
  );
}
