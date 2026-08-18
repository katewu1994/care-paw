import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/paw_ui.dart';
import '../widgets/task_card.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({required this.store, super.key});

  final CareStore store;

  @override
  Widget build(BuildContext context) {
    final pending = store.tasksWithStatus(TaskStatus.unclaimed);
    final claimed = store.tasksWithStatus(TaskStatus.claimed);
    final completed = store.tasksWithStatus(TaskStatus.completed);
    final skipped = store.tasksWithStatus(TaskStatus.skipped);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        PawSpace.lg,
        PawSpace.sm,
        PawSpace.lg,
        pawListBottomInset(context, hasFab: true),
      ),
      children: [
        _greeting(context, pending.length + claimed.length),
        const SizedBox(height: PawSpace.xxl),
        SectionHeader(
          title: 'Needs a person',
          detail: pending.isEmpty ? 'Clear' : '${pending.length} unclaimed',
        ),
        const SizedBox(height: PawSpace.md),
        if (pending.isEmpty)
          const PawEmptyState(
            icon: Icons.check_rounded,
            color: pawGreen,
            iconColor: pawGreenInk,
            title: 'Everything is handled',
            message:
                'Enjoy the quiet moment, or add care when something comes up.',
          )
        else
          ..._taskList(pending),
        if (claimed.isNotEmpty) ...[
          const SizedBox(height: PawSpace.md),
          SectionHeader(
            title: 'In progress',
            detail: '${claimed.length} claimed',
          ),
          const SizedBox(height: PawSpace.md),
          ..._taskList(claimed),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: PawSpace.md),
          const SectionHeader(title: 'Done today', detail: 'Shared care'),
          const SizedBox(height: PawSpace.md),
          ..._taskList(completed.take(3)),
        ],
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: PawSpace.md),
          SectionHeader(
            title: 'Skipped today',
            detail: '${skipped.length} skipped',
          ),
          const SizedBox(height: PawSpace.md),
          ..._taskList(skipped),
        ],
      ],
    );
  }

  Iterable<Widget> _taskList(Iterable<CareTask> tasks) => tasks.map(
    (task) => Padding(
      padding: const EdgeInsets.only(bottom: PawSpace.md),
      child: TaskCard(task: task, store: store),
    ),
  );

  Widget _greeting(BuildContext context, int remaining) {
    final textTheme = Theme.of(context).textTheme;
    final caregiver = store.currentCaregiver?.name ?? 'pet parent';
    final pets = store.household?.pets ?? const <Pet>[];
    final petLabel = pets.length <= 2
        ? pets.map((pet) => pet.name).join(' & ')
        : '${pets.length} pets';
    final careSummary = remaining == 0
        ? '$petLabel · All care is done today.'
        : '$petLabel · $remaining care ${remaining == 1 ? 'task' : 'tasks'} left today.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hi, $caregiver', style: textTheme.headlineMedium),
        const SizedBox(height: PawSpace.xs),
        Text(
          careSummary,
          style: textTheme.bodyMedium?.copyWith(color: pawMuted),
        ),
      ],
    );
  }
}
