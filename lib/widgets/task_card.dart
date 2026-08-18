import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../screens/add_task_sheet.dart';
import '../state/care_store.dart';
import 'paw_ui.dart';
import 'pet_species_icon.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.store,
    this.showDate = false,
    super.key,
  });

  final CareTask task;
  final CareStore store;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PawRadius.xxl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E0621),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: _backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.xxl),
          side: BorderSide(color: statusColor.withValues(alpha: .25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _hasActions ? () => _showTaskActions(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(PawSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryIcon(category: task.category),
                    const SizedBox(width: PawSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: textTheme.titleMedium),
                          const SizedBox(height: PawSpace.xs),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  task.hasDueTime
                                      ? Icons.schedule_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 14,
                                  color: pawMuted,
                                ),
                              ),
                              const SizedBox(width: PawSpace.xs),
                              Expanded(
                                child: Text(
                                  _scheduleLabel,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: pawMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: PawSpace.sm),
                          Wrap(
                            spacing: PawSpace.sm,
                            runSpacing: PawSpace.sm,
                            children: [
                              ...store
                                  .petsForTask(task)
                                  .map((pet) => PetTag(pet: pet)),
                              PawTag(
                                label: task.kind == TaskKind.routine
                                    ? 'Routine'
                                    : 'One-time',
                                color: task.kind == TaskKind.routine
                                    ? pawPurple
                                    : pawBlue,
                                ink: task.kind == TaskKind.routine
                                    ? pawPurpleInk
                                    : pawBlueInk,
                                icon: task.kind == TaskKind.routine
                                    ? Icons.autorenew_rounded
                                    : Icons.event_rounded,
                              ),
                              if (task.priority == TaskPriority.urgent)
                                const PawTag(
                                  label: 'Urgent',
                                  color: pawRose,
                                  ink: pawRoseInk,
                                  icon: Icons.priority_high_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PawSpace.md),
                  child: Divider(
                    color: pawPurple.withValues(alpha: .14),
                    height: 1,
                  ),
                ),
                Row(
                  children: [
                    Icon(_statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: PawSpace.sm),
                    Expanded(
                      child: Text(_statusMessage, style: textTheme.titleSmall),
                    ),
                    if (_canCompleteDirectly) ...[
                      const SizedBox(width: PawSpace.sm),
                      TextButton.icon(
                        key: ValueKey('complete-${task.id}'),
                        onPressed: () => store.complete(task),
                        style: TextButton.styleFrom(
                          foregroundColor: pawGreenInk,
                          backgroundColor: pawGreen.withValues(alpha: .14),
                          // 44pt visual height; Flutter pads the hit area to
                          // 48pt because tapTargetSize stays at its default.
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: PawSpace.md,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: textTheme.labelMedium,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Done'),
                      ),
                    ],
                    if (_hasActions)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: pawMuted,
                        size: 22,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _scheduleLabel {
    final date = showDate ? friendlyDate(task.dueAt) : null;
    if (!task.hasDueTime) return date ?? 'Any time';
    final time = friendlyTime(task.dueAt);
    return date == null ? time : '$date · $time';
  }

  bool get _hasActions => store.currentCaregiver != null;

  bool get _canCompleteDirectly =>
      task.status == TaskStatus.unclaimed && task.assignmentRequest == null;

  Future<void> _showTaskActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .76,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PawSpace.xl,
              PawSpace.xs,
              PawSpace.xl,
              PawSpace.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: PawSpace.xs),
                Text(
                  _statusMessage,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: pawMuted),
                ),
                const SizedBox(height: PawSpace.xl),
                _sheetActions(sheetContext, context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetActions(BuildContext sheetContext, BuildContext parentContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasCareActions) ...[
          _careActions(sheetContext),
          const SizedBox(height: PawSpace.lg),
          const Divider(),
          const SizedBox(height: PawSpace.xs),
        ],
        if (task.status == TaskStatus.skipped)
          ListTile(
            key: ValueKey('restore-${task.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: pawLavender,
              child: Icon(Icons.restore_rounded, color: pawPurple),
            ),
            title: const Text('Restore this day'),
            subtitle: const Text('Put this occurrence back on the schedule'),
            onTap: () => _restoreTask(sheetContext, parentContext),
          )
        else ...[
          ListTile(
            key: ValueKey('edit-${task.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: pawLavender,
              child: Icon(Icons.edit_rounded, color: pawPurple),
            ),
            title: Text(
              task.kind == TaskKind.routine ? 'Edit this day' : 'Edit task',
            ),
            subtitle: Text(
              task.kind == TaskKind.routine
                  ? 'The regular routine stays unchanged'
                  : 'Change the task details',
            ),
            trailing: const Icon(Icons.arrow_forward_rounded, color: pawPurple),
            onTap: () => _editTask(sheetContext, parentContext),
          ),
          if (task.kind == TaskKind.routine &&
              task.status != TaskStatus.completed)
            ListTile(
              key: ValueKey('skip-${task.id}'),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: pawYellow.withValues(alpha: .14),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: pawYellowInk,
                ),
              ),
              title: const Text('Skip this day'),
              subtitle: Text(
                'Only ${friendlyDate(task.dueAt)} will be skipped',
              ),
              onTap: () => _skipTask(sheetContext, parentContext),
            ),
          if (task.kind == TaskKind.oneOff)
            ListTile(
              key: ValueKey('delete-${task.id}'),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: pawRose.withValues(alpha: .12),
                child: const Icon(Icons.delete_outline_rounded, color: pawRose),
              ),
              title: const Text(
                'Delete task',
                style: TextStyle(
                  color: pawRoseInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('Permanently removes this task'),
              onTap: () => _confirmDelete(sheetContext, parentContext),
            ),
        ],
      ],
    );
  }

  bool get _hasCareActions =>
      task.status == TaskStatus.unclaimed ||
      (task.status == TaskStatus.claimed &&
          task.assignee?.id == store.currentCaregiver?.id);

  Widget _careActions(BuildContext context) {
    final current = store.currentCaregiver!;
    final request = task.assignmentRequest;
    final requestForYou = request?.requestedTo?.id == current.id;
    final requestSentByYou = request?.requestedBy.id == current.id;

    if (task.status == TaskStatus.claimed) {
      return task.assignee?.id == current.id
          ? PawFilledButton(
              label: 'Mark done',
              color: pawGreenInk,
              onPressed: () => _perform(context, () => store.complete(task)),
              icon: Icons.check_rounded,
            )
          : const SizedBox.shrink();
    }

    if (requestForYou) {
      return Row(
        children: [
          Expanded(
            child: PawOutlinedButton(
              label: 'Decline',
              color: pawMuted,
              onPressed: () =>
                  _perform(context, () => store.declineRequest(task)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PawFilledButton(
              label: 'Accept',
              onPressed: () =>
                  _perform(context, () => store.acceptRequest(task)),
            ),
          ),
        ],
      );
    }

    if (requestSentByYou) {
      return Row(
        children: [
          Expanded(
            child: PawOutlinedButton(
              label: 'Cancel request',
              color: pawMuted,
              onPressed: () =>
                  _perform(context, () => store.cancelRequest(task)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PawFilledButton(
              label: 'I’ll do it',
              onPressed: () => _perform(context, () => store.claim(task)),
            ),
          ),
        ],
      );
    }

    final people = store.caregivers
        .where((person) => person.id != store.currentCaregiver?.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PawOutlinedButton(
                label: 'I’ll do it',
                onPressed: () => _perform(context, () => store.claim(task)),
              ),
            ),
            if (_canCompleteDirectly) ...[
              const SizedBox(width: 10),
              Expanded(
                child: PawFilledButton(
                  label: 'Done',
                  color: pawGreenInk,
                  onPressed: () =>
                      _perform(context, () => store.complete(task)),
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: PawSpace.xl),
        Text('Or assign to', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: PawSpace.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: pawLavender,
            child: Icon(Icons.groups_rounded, color: pawPurple),
          ),
          title: const Text(
            'Anyone in the household',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('Leave it open for the first volunteer'),
          trailing: const Icon(Icons.arrow_forward_rounded, color: pawPurple),
          onTap: () => _perform(context, () => store.requestAnyone(task)),
        ),
        ...people.map(
          (person) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: pawLavender,
              child: Text(
                person.name.isEmpty
                    ? '?'
                    : person.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: pawPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(person.name),
            subtitle: const Text('Ask this caregiver directly'),
            trailing: const Icon(Icons.arrow_forward_rounded, color: pawPurple),
            onTap: () =>
                _perform(context, () => store.requestCaregiver(task, person)),
          ),
        ),
      ],
    );
  }

  Future<void> _editTask(
    BuildContext sheetContext,
    BuildContext parentContext,
  ) async {
    Navigator.pop(sheetContext);
    await Future<void>.delayed(Duration.zero);
    if (!parentContext.mounted) return;
    await showEditTaskSheet(parentContext, store, task);
  }

  Future<void> _skipTask(
    BuildContext sheetContext,
    BuildContext parentContext,
  ) async {
    Navigator.pop(sheetContext);
    await store.skipTaskOccurrence(task);
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          store.errorMessage ??
              '${task.title} skipped for ${friendlyDate(task.dueAt)}.',
        ),
      ),
    );
  }

  Future<void> _restoreTask(
    BuildContext sheetContext,
    BuildContext parentContext,
  ) async {
    Navigator.pop(sheetContext);
    await store.restoreTaskOccurrence(task);
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          store.errorMessage ??
              '${task.title} restored for ${friendlyDate(task.dueAt)}.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext sheetContext,
    BuildContext parentContext,
  ) async {
    Navigator.pop(sheetContext);
    await Future<void>.delayed(Duration.zero);
    if (!parentContext.mounted) return;
    final isRoutine = task.kind == TaskKind.routine;
    final confirmed = await showDialog<bool>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRoutine ? 'Delete this routine?' : 'Delete this task?'),
        content: Text(
          isRoutine
              ? 'All upcoming occurrences will be removed. Completed care history will stay available.'
              : '“${task.title}” will be permanently removed.',
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
    await store.deleteTask(task);
    if (!parentContext.mounted) return;
    final error = store.errorMessage;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          error ?? (isRoutine ? 'Routine deleted.' : 'Task deleted.'),
        ),
      ),
    );
  }

  void _perform(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  Color get _statusColor => switch (task.status) {
    TaskStatus.unclaimed => pawRoseInk,
    TaskStatus.claimed => pawPurpleInk,
    TaskStatus.completed => pawGreenInk,
    TaskStatus.skipped => pawMuted,
  };

  Color get _backgroundColor => switch (task.status) {
    TaskStatus.unclaimed => Colors.white,
    TaskStatus.claimed => pawLavender.withValues(alpha: .84),
    TaskStatus.completed => pawGreen.withValues(alpha: .08),
    TaskStatus.skipped => pawMuted.withValues(alpha: .06),
  };

  IconData get _statusIcon => switch (task.status) {
    TaskStatus.unclaimed =>
      task.assignmentRequest == null
          ? Icons.person_search_rounded
          : Icons.send_rounded,
    TaskStatus.claimed => Icons.assignment_turned_in_rounded,
    TaskStatus.completed => Icons.verified_rounded,
    TaskStatus.skipped => Icons.event_busy_rounded,
  };

  String get _statusMessage {
    final current = store.currentCaregiver;
    final request = task.assignmentRequest;
    switch (task.status) {
      case TaskStatus.unclaimed:
        if (request == null) return 'Not claimed yet';
        if (request.requestedTo?.id == current?.id) {
          return '${request.requestedBy.name} asked you to take this';
        }
        if (request.requestedBy.id == current?.id) {
          return request.mode == AssignmentMode.open
              ? 'Open to anyone in the household'
              : 'Waiting for ${request.requestedTo?.name ?? 'a caregiver'}';
        }
        return request.mode == AssignmentMode.open
            ? 'Open to anyone in the household'
            : 'Waiting for a caregiver';
      case TaskStatus.claimed:
        return task.assignee?.id == current?.id
            ? 'You’re on it'
            : '${task.assignee?.name ?? 'A caregiver'} is on it';
      case TaskStatus.completed:
        final time = task.completedAt == null
            ? ''
            : ' · ${friendlyTime(task.completedAt!)}';
        return 'Done by ${task.completedBy?.name ?? 'a caregiver'}$time';
      case TaskStatus.skipped:
        return 'Skipped for this day';
    }
  }
}
