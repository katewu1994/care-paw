import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/care_models.dart';
import '../services/firebase_care_service.dart';
import '../services/notification_service.dart';

/// Shared care state. Supplying [FirebaseCareService] enables anonymous
/// Firebase Auth plus Firestore synchronization; omitting it retains a small
/// in-memory implementation for tests and unsupported platforms.
class CareStore extends ChangeNotifier {
  CareStore({
    FirebaseCareService? firebaseService,
    NotificationService? notificationService,
  }) : this._(firebaseService, notificationService);

  CareStore._(this._firebaseService, this._notificationService);

  final FirebaseCareService? _firebaseService;
  final NotificationService? _notificationService;
  final Random _random = Random();

  Household? household;
  Caregiver? currentCaregiver;
  List<Caregiver> caregivers = const [];
  List<CareRoutine> routines = const [];
  HouseholdInvitation? invitationPreview;
  HouseholdInvitation? activeInvitation;
  HouseholdJoinRequest? pendingJoinRequest;
  List<HouseholdJoinRequest> joinRequests = const [];
  String? errorMessage;
  bool isRestoringSession = false;
  bool isLoading = false;
  NotificationPermissionState notificationPermission =
      NotificationPermissionState.unavailable;
  bool notificationsEnabled = false;

  final List<CareTask> _oneOffTasks = [];
  final Map<String, CareTask> _routineOverrides = {};
  StreamSubscription<Household?>? _householdSubscription;
  StreamSubscription<List<Caregiver>>? _caregiverSubscription;
  StreamSubscription<List<CareRoutine>>? _routineSubscription;
  StreamSubscription<List<CareTask>>? _taskSubscription;
  StreamSubscription<List<HouseholdJoinRequest>>? _joinRequestsSubscription;
  StreamSubscription<HouseholdJoinRequest?>? _pendingJoinSubscription;
  bool _completingApprovedJoin = false;

  bool get isCloudBacked => _firebaseService != null;
  bool get hasHousehold => household != null && currentCaregiver != null;
  bool get isOwner => currentCaregiver?.isOwner == true;

  Future<void> refreshNotificationState() => _syncNotificationsForSession();

  Future<void> enableNotifications() async {
    final notifications = _notificationService;
    final home = household;
    final caregiver = currentCaregiver;
    if (notifications == null || home == null || caregiver == null) return;

    final saved = await _runLoading(() async {
      notificationPermission = await notifications.requestAndSync(
        householdId: home.id,
        caregiverId: caregiver.id,
      );
      notificationsEnabled = notificationPermission.isGranted;
    });
    if (saved) notifyListeners();
  }

  Future<void> disableNotifications() async {
    final notifications = _notificationService;
    final home = household;
    final caregiver = currentCaregiver;
    if (notifications == null || home == null || caregiver == null) return;

    final saved = await _runLoading(
      () => notifications.disableForMember(
        householdId: home.id,
        caregiverId: caregiver.id,
      ),
    );
    if (saved) {
      notificationsEnabled = false;
      notifyListeners();
    }
  }

  Future<void> restoreSession() async {
    final service = _firebaseService;
    if (service == null) return;

    isRestoringSession = true;
    notifyListeners();
    try {
      final session = await service.restoreSession();
      if (session != null) {
        _startCloudSession(session);
      } else {
        final request = await service.restorePendingJoinRequest();
        if (request != null) _watchPendingRequest(request);
      }
    } catch (error) {
      _setError(error);
    } finally {
      isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> previewInvitation(String value) async {
    final service = _firebaseService;
    if (service == null) {
      if (value.trim().toUpperCase() != 'PAW123') {
        _setError(
          const FirebaseCareException(
            'That invitation is unavailable in local demo mode. Try PAW123.',
          ),
        );
        return;
      }
      invitationPreview = HouseholdInvitation(
        id: 'PAW123',
        householdId: 'local-demo-household',
        householdName: 'Mochi Family',
        petNames: const ['Mochi'],
        inviterName: 'Alex',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        status: InvitationStatus.active,
      );
      notifyListeners();
      return;
    }
    await _runLoading(() async {
      invitationPreview = await service.loadInvitation(value);
    });
  }

  Future<void> handleInvitationLink(Uri uri) async {
    if (uri.scheme != 'copaw' || uri.host != 'invite') return;
    if (hasHousehold) {
      _setError(
        const FirebaseCareException(
          'Leave the current household before opening another invitation.',
        ),
      );
      return;
    }
    await previewInvitation(uri.toString());
  }

  void clearInvitationPreview() {
    invitationPreview = null;
    clearError();
  }

  Future<void> createHousehold({
    required String householdName,
    required List<Pet> pets,
    required String caregiverName,
  }) async {
    final service = _firebaseService;
    if (service == null) {
      _createLocalHousehold(
        householdName: householdName,
        pets: pets,
        caregiverName: caregiverName,
      );
      return;
    }

    await _runLoading(() async {
      final session = await service.createHousehold(
        householdName: householdName,
        pets: pets,
        caregiverName: caregiverName,
      );
      _startCloudSession(session);
    });
  }

  Future<void> requestToJoin({required String caregiverName}) async {
    final invitation = invitationPreview;
    if (invitation == null) return;
    final service = _firebaseService;
    if (service == null) {
      _joinLocalHousehold(
        inviteCode: invitation.id,
        caregiverName: caregiverName,
      );
      return;
    }

    await _runLoading(() async {
      final request = await service.requestToJoin(
        invitation: invitation,
        caregiverName: caregiverName,
      );
      invitationPreview = null;
      _watchPendingRequest(request);
    });
  }

  Future<void> createInvitation() async {
    final service = _firebaseService;
    final home = household;
    final caregiver = currentCaregiver;
    if (service == null || home == null || caregiver == null) return;
    await _runLoading(() async {
      final previous = activeInvitation;
      if (previous != null && previous.isActive) {
        await service.revokeInvitation(previous);
        activeInvitation = null;
      }
      activeInvitation = await service.createInvitation(
        household: home,
        inviter: caregiver,
      );
    });
  }

  Future<void> revokeInvitation() async {
    final service = _firebaseService;
    final invitation = activeInvitation;
    if (service == null || invitation == null) return;
    final revoked = await _runLoading(
      () => service.revokeInvitation(invitation),
    );
    if (revoked) activeInvitation = null;
  }

  Future<void> reviewJoinRequest(
    HouseholdJoinRequest request, {
    required bool approve,
  }) async {
    final service = _firebaseService;
    final caregiver = currentCaregiver;
    if (service == null || caregiver == null) return;
    final reviewed = await _runLoading(
      () => service.reviewJoinRequest(
        request: request,
        reviewer: caregiver,
        approve: approve,
      ),
    );
    if (reviewed) {
      joinRequests = joinRequests
          .where(
            (item) =>
                item.userId != request.userId ||
                item.invitationId != request.invitationId,
          )
          .toList();
      notifyListeners();
    }
  }

  Future<void> removeMember(Caregiver caregiver) async {
    final service = _firebaseService;
    final home = household;
    if (service == null || home == null || caregiver.isOwner) return;
    await _runLoading(
      () =>
          service.removeMember(householdId: home.id, caregiverId: caregiver.id),
    );
  }

  List<CareTask> tasksOn(DateTime day) {
    final routineTasks = routines
        .where((routine) => _isRoutineDue(routine, day))
        .map((routine) {
          final generated = _taskForRoutine(routine, day);
          return _routineOverrides[generated.id] ?? generated;
        });
    final oneOff = _oneOffTasks.where((task) => isSameDay(task.dueAt, day));
    return [...routineTasks, ...oneOff]
      ..sort((first, second) => first.dueAt.compareTo(second.dueAt));
  }

  List<CareTask> get todayTasks => tasksOn(DateTime.now());

  List<CareTask> get allCompletedTasks =>
      [
        ..._oneOffTasks.where((task) => task.status == TaskStatus.completed),
        ..._routineOverrides.values.where(
          (task) => task.status == TaskStatus.completed,
        ),
      ]..sort(
        (first, second) => (second.completedAt ?? second.dueAt).compareTo(
          first.completedAt ?? first.dueAt,
        ),
      );

  List<CareTask> tasksWithStatus(TaskStatus status, {DateTime? day}) =>
      (day == null ? todayTasks : tasksOn(day))
          .where((task) => task.status == status)
          .toList();

  /// Resolves the pets attached to a task. Tasks saved before pet assignment
  /// was introduced have no IDs and remain compatible by applying to all pets.
  List<Pet> petsForTask(CareTask task) {
    final pets = household?.pets ?? const <Pet>[];
    if (task.petIds.isEmpty) return pets;
    return pets.where((pet) => task.petIds.contains(pet.id)).toList();
  }

  CareRoutine? routineForTask(CareTask task) {
    final routineId = task.routineId;
    if (routineId == null) return null;
    return routines.where((routine) => routine.id == routineId).firstOrNull;
  }

  /// Creates a display-only occurrence that can be used to edit a routine.
  /// The occurrence itself is not persisted unless a day-specific action is
  /// performed on it.
  CareTask taskForRoutine(CareRoutine routine) =>
      _taskForRoutine(routine, routine.startDate);

  Future<void> addTask({
    required String title,
    required CareCategory category,
    required TaskKind kind,
    required TaskPriority priority,
    required DateTime dueAt,
    bool hasDueTime = true,
    required Set<int> weekdays,
    required Set<String> petIds,
    Caregiver? assignee,
  }) async {
    final caregiver = currentCaregiver;
    final home = household;
    final householdId = home?.id;
    final trimmedTitle = title.trim();
    final validPetIds = home == null
        ? <String>{}
        : petIds.intersection(home.pets.map((pet) => pet.id).toSet());
    final normalizedDueAt = hasDueTime ? dueAt : _day(dueAt);
    final selectedCaregiver = assignee == null
        ? null
        : assignee.id == caregiver?.id
        ? caregiver
        : caregivers.where((person) => person.id == assignee.id).firstOrNull;
    if (caregiver == null ||
        householdId == null ||
        trimmedTitle.isEmpty ||
        validPetIds.isEmpty) {
      return;
    }

    final service = _firebaseService;
    if (service == null) {
      if (kind == TaskKind.routine) {
        routines = [
          ...routines,
          CareRoutine(
            id: _id('routine'),
            title: trimmedTitle,
            category: category,
            priority: priority,
            hour: normalizedDueAt.hour,
            minute: normalizedDueAt.minute,
            hasDueTime: hasDueTime,
            weekdays: weekdays,
            startDate: _day(normalizedDueAt),
            createdBy: caregiver,
            petIds: validPetIds,
            assignee: selectedCaregiver,
          ),
        ];
      } else {
        _oneOffTasks.add(
          CareTask(
            id: _id('task'),
            title: trimmedTitle,
            category: category,
            dueAt: normalizedDueAt,
            hasDueTime: hasDueTime,
            kind: TaskKind.oneOff,
            priority: priority,
            createdBy: caregiver,
            status: selectedCaregiver == null
                ? TaskStatus.unclaimed
                : TaskStatus.claimed,
            petIds: validPetIds,
            assignee: selectedCaregiver,
          ),
        );
      }
      notifyListeners();
      return;
    }

    if (kind == TaskKind.routine) {
      await _runLoading(
        () => service.addRoutine(
          householdId: householdId,
          routine: CareRoutine(
            id: _id('routine'),
            title: trimmedTitle,
            category: category,
            priority: priority,
            hour: normalizedDueAt.hour,
            minute: normalizedDueAt.minute,
            hasDueTime: hasDueTime,
            weekdays: weekdays,
            startDate: _day(normalizedDueAt),
            createdBy: caregiver,
            petIds: validPetIds,
            assignee: selectedCaregiver,
          ),
        ),
      );
    } else {
      await _runLoading(
        () => service.addTask(
          householdId: householdId,
          task: CareTask(
            id: _id('task'),
            title: trimmedTitle,
            category: category,
            dueAt: normalizedDueAt,
            hasDueTime: hasDueTime,
            kind: TaskKind.oneOff,
            priority: priority,
            createdBy: caregiver,
            status: selectedCaregiver == null
                ? TaskStatus.unclaimed
                : TaskStatus.claimed,
            petIds: validPetIds,
            assignee: selectedCaregiver,
          ),
        ),
      );
    }
  }

  Future<void> updateTask({
    required CareTask task,
    required String title,
    required CareCategory category,
    required TaskPriority priority,
    required DateTime dueAt,
    bool hasDueTime = true,
    required Set<int> weekdays,
    required Set<String> petIds,
  }) async {
    final home = household;
    final householdId = home?.id;
    final trimmedTitle = title.trim();
    final validPetIds = home == null
        ? <String>{}
        : petIds.intersection(home.pets.map((pet) => pet.id).toSet());
    final normalizedDueAt = hasDueTime ? dueAt : _day(dueAt);
    if (householdId == null || trimmedTitle.isEmpty || validPetIds.isEmpty) {
      return;
    }

    if (task.routineId == null) {
      final updatedTask = task.copyWith(
        title: trimmedTitle,
        category: category,
        dueAt: normalizedDueAt,
        hasDueTime: hasDueTime,
        priority: priority,
        petIds: validPetIds,
      );
      await _replaceTask(updatedTask);
      return;
    }

    final routine = routineForTask(task);
    if (routine == null || weekdays.isEmpty) return;
    final updatedRoutine = routine.copyWith(
      title: trimmedTitle,
      category: category,
      priority: priority,
      hour: normalizedDueAt.hour,
      minute: normalizedDueAt.minute,
      hasDueTime: hasDueTime,
      weekdays: Set.of(weekdays),
      startDate: _day(normalizedDueAt),
      petIds: validPetIds,
    );
    final updatedOverrides = _routineOverrides.values
        .where(
          (override) =>
              override.routineId == routine.id &&
              override.status != TaskStatus.completed,
        )
        .map(
          (override) => override.copyWith(
            title: trimmedTitle,
            category: category,
            dueAt: hasDueTime
                ? _atTime(
                    override.dueAt,
                    normalizedDueAt.hour,
                    normalizedDueAt.minute,
                  )
                : _day(override.dueAt),
            hasDueTime: hasDueTime,
            priority: priority,
            petIds: validPetIds,
          ),
        )
        .toList();

    final service = _firebaseService;
    if (service == null) {
      routines = routines
          .map((item) => item.id == routine.id ? updatedRoutine : item)
          .toList();
      for (final override in updatedOverrides) {
        _routineOverrides[override.id] = override;
      }
      errorMessage = null;
      notifyListeners();
      return;
    }
    await _runLoading(
      () => service.updateRoutine(
        householdId: householdId,
        routine: updatedRoutine,
        taskOverrides: updatedOverrides,
      ),
    );
  }

  /// Updates one generated routine occurrence without changing its routine.
  /// Routine occurrences keep their original calendar date; only the time and
  /// other task details can be customized for that day.
  Future<void> updateTaskOccurrence({
    required CareTask task,
    required String title,
    required CareCategory category,
    required TaskPriority priority,
    required DateTime dueAt,
    bool hasDueTime = true,
    required Set<String> petIds,
  }) async {
    final home = household;
    final trimmedTitle = title.trim();
    final validPetIds = home == null
        ? <String>{}
        : petIds.intersection(home.pets.map((pet) => pet.id).toSet());
    if (home == null || trimmedTitle.isEmpty || validPetIds.isEmpty) return;

    final occurrenceDueAt = hasDueTime
        ? task.routineId == null
              ? dueAt
              : _atTime(task.dueAt, dueAt.hour, dueAt.minute)
        : _day(task.routineId == null ? dueAt : task.dueAt);
    await _replaceTask(
      task.copyWith(
        title: trimmedTitle,
        category: category,
        dueAt: occurrenceDueAt,
        hasDueTime: hasDueTime,
        priority: priority,
        petIds: validPetIds,
      ),
    );
  }

  Future<void> skipTaskOccurrence(CareTask task) async {
    if (task.routineId == null || task.status == TaskStatus.completed) return;
    await _replaceTask(
      task.copyWith(
        status: TaskStatus.skipped,
        clearAssignee: true,
        clearAssignmentRequest: true,
        clearCompletion: true,
      ),
    );
  }

  Future<void> restoreTaskOccurrence(CareTask task) async {
    if (task.routineId == null || task.status != TaskStatus.skipped) return;
    await _replaceTask(
      task.copyWith(
        status: TaskStatus.unclaimed,
        clearAssignee: true,
        clearAssignmentRequest: true,
        clearCompletion: true,
      ),
    );
  }

  Future<void> deleteTask(CareTask task) async {
    final householdId = household?.id;
    if (householdId == null) return;
    final service = _firebaseService;

    if (task.routineId == null) {
      if (service == null) {
        _oneOffTasks.removeWhere((item) => item.id == task.id);
        errorMessage = null;
        notifyListeners();
        return;
      }
      await _runLoading(
        () => service.deleteTask(householdId: householdId, taskId: task.id),
      );
      return;
    }

    final routineId = task.routineId!;
    final pendingOverrideIds = _routineOverrides.values
        .where(
          (override) =>
              override.routineId == routineId &&
              override.status != TaskStatus.completed,
        )
        .map((override) => override.id)
        .toList();
    if (service == null) {
      routines = routines.where((routine) => routine.id != routineId).toList();
      _routineOverrides.removeWhere(
        (_, override) =>
            override.routineId == routineId &&
            override.status != TaskStatus.completed,
      );
      errorMessage = null;
      notifyListeners();
      return;
    }
    await _runLoading(
      () => service.deleteRoutine(
        householdId: householdId,
        routineId: routineId,
        taskOverrideIds: pendingOverrideIds,
      ),
    );
  }

  Future<void> claim(CareTask task) async {
    final caregiver = currentCaregiver;
    if (caregiver == null || task.status != TaskStatus.unclaimed) return;
    await _replaceTask(
      task.copyWith(
        status: TaskStatus.claimed,
        assignee: caregiver,
        clearAssignmentRequest: true,
      ),
    );
  }

  Future<void> requestAnyone(CareTask task) async {
    final caregiver = currentCaregiver;
    if (caregiver == null || task.status != TaskStatus.unclaimed) return;
    await _replaceTask(
      task.copyWith(
        assignmentRequest: AssignmentRequest(
          id: _id('request'),
          requestedBy: caregiver,
          createdAt: DateTime.now(),
          mode: AssignmentMode.open,
        ),
      ),
    );
  }

  Future<void> requestCaregiver(CareTask task, Caregiver caregiver) async {
    final sender = currentCaregiver;
    if (sender == null || task.status != TaskStatus.unclaimed) return;
    await _replaceTask(
      task.copyWith(
        assignmentRequest: AssignmentRequest(
          id: _id('request'),
          requestedBy: sender,
          requestedTo: caregiver,
          createdAt: DateTime.now(),
          mode: AssignmentMode.direct,
        ),
      ),
    );
  }

  Future<void> acceptRequest(CareTask task) async {
    final caregiver = currentCaregiver;
    if (caregiver == null || task.status != TaskStatus.unclaimed) return;
    await _replaceTask(
      task.copyWith(
        status: TaskStatus.claimed,
        assignee: caregiver,
        clearAssignmentRequest: true,
      ),
    );
  }

  Future<void> declineRequest(CareTask task) async {
    if (task.status != TaskStatus.unclaimed) return;
    await _replaceTask(task.copyWith(clearAssignmentRequest: true));
  }

  Future<void> cancelRequest(CareTask task) async {
    if (task.status != TaskStatus.unclaimed) return;
    await _replaceTask(task.copyWith(clearAssignmentRequest: true));
  }

  Future<void> complete(CareTask task) async {
    final caregiver = currentCaregiver;
    final isUnassigned =
        task.status == TaskStatus.unclaimed && task.assignmentRequest == null;
    final isClaimedByCurrent =
        task.status == TaskStatus.claimed && task.assignee?.id == caregiver?.id;
    if (caregiver == null || (!isUnassigned && !isClaimedByCurrent)) {
      return;
    }
    await _replaceTask(
      task.copyWith(
        status: TaskStatus.completed,
        completedBy: caregiver,
        completedAt: DateTime.now(),
        clearAssignmentRequest: true,
      ),
    );
  }

  Future<void> updateProfile({
    required String householdName,
    required List<Pet> pets,
    required String caregiverName,
  }) async {
    final home = household;
    final caregiver = currentCaregiver;
    if (home == null || caregiver == null) return;

    final updatedCaregiver = caregiver.copyWith(name: caregiverName.trim());
    final service = _firebaseService;
    if (service != null) {
      final saved = await _runLoading(
        () => service.updateProfile(
          householdId: home.id,
          caregiver: updatedCaregiver,
          householdName: householdName,
          pets: pets,
        ),
      );
      if (!saved) return;
    }

    household = home.copyWith(name: householdName.trim(), pets: pets);
    currentCaregiver = updatedCaregiver;
    caregivers = caregivers
        .map(
          (person) =>
              person.id == updatedCaregiver.id ? updatedCaregiver : person,
        )
        .toList();
    if (service == null) {
      routines = routines
          .map(
            (routine) =>
                routine.createdBy.id == updatedCaregiver.id ||
                    routine.assignee?.id == updatedCaregiver.id
                ? CareRoutine(
                    id: routine.id,
                    title: routine.title,
                    category: routine.category,
                    priority: routine.priority,
                    hour: routine.hour,
                    minute: routine.minute,
                    hasDueTime: routine.hasDueTime,
                    weekdays: routine.weekdays,
                    startDate: routine.startDate,
                    createdBy: routine.createdBy.id == updatedCaregiver.id
                        ? updatedCaregiver
                        : routine.createdBy,
                    petIds: routine.petIds,
                    assignee: routine.assignee?.id == updatedCaregiver.id
                        ? updatedCaregiver
                        : routine.assignee,
                  )
                : routine,
          )
          .toList();
    }
    notifyListeners();
  }

  Future<void> leaveHousehold() async {
    final service = _firebaseService;
    final notifications = _notificationService;
    final householdId = household?.id;
    final caregiverId = currentCaregiver?.id;
    if (service != null && householdId != null && caregiverId != null) {
      if (notifications != null) {
        final disabled = await _runLoading(
          () => notifications.disableForMember(
            householdId: householdId,
            caregiverId: caregiverId,
          ),
        );
        if (!disabled) return;
      }
      final left = await _runLoading(
        () => service.leaveHousehold(
          householdId: householdId,
          caregiverId: caregiverId,
        ),
      );
      if (!left) return;
    }
    _clearSession();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _replaceTask(CareTask task) async {
    final service = _firebaseService;
    final householdId = household?.id;
    if (service == null || householdId == null) {
      _replaceTaskLocal(task);
      return;
    }
    await _runLoading(
      () => service.replaceTask(householdId: householdId, task: task),
    );
  }

  void _replaceTaskLocal(CareTask task) {
    if (task.routineId != null) {
      _routineOverrides[task.id] = task;
    } else {
      final index = _oneOffTasks.indexWhere((item) => item.id == task.id);
      if (index != -1) _oneOffTasks[index] = task;
    }
    notifyListeners();
  }

  Future<bool> _runLoading(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      _setError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _startCloudSession(CloudSession session) {
    final service = _firebaseService;
    if (service == null) return;
    _cancelSubscriptions();
    household = session.household;
    currentCaregiver = session.caregiver;
    pendingJoinRequest = null;
    invitationPreview = null;
    errorMessage = null;

    _householdSubscription = service
        .householdStream(session.household.id)
        .listen((next) {
          if (next != null) {
            household = next;
            notifyListeners();
          }
        }, onError: _setError);
    _caregiverSubscription = service
        .caregiversStream(session.household.id)
        .listen((next) {
          caregivers = next;
          final localCaregiver = currentCaregiver;
          if (localCaregiver != null) {
            currentCaregiver = next.firstWhere(
              (caregiver) => caregiver.id == localCaregiver.id,
              orElse: () => localCaregiver,
            );
          }
          notifyListeners();
        }, onError: _setError);
    _routineSubscription = service.routinesStream(session.household.id).listen((
      next,
    ) {
      routines = next;
      notifyListeners();
    }, onError: _setError);
    _taskSubscription = service.tasksStream(session.household.id).listen((
      next,
    ) {
      _oneOffTasks
        ..clear()
        ..addAll(next.where((task) => task.routineId == null));
      _routineOverrides
        ..clear()
        ..addEntries(
          next
              .where((task) => task.routineId != null)
              .map((task) => MapEntry(task.id, task)),
        );
      notifyListeners();
    }, onError: _setError);
    if (session.caregiver.isOwner) {
      _joinRequestsSubscription = service
          .joinRequestsStream(session.household.id)
          .listen((next) {
            joinRequests = next;
            final invitation = activeInvitation;
            if (invitation != null &&
                next.any((request) => request.invitationId == invitation.id)) {
              activeInvitation = null;
            }
            notifyListeners();
          }, onError: _setError);
    }
    unawaited(_syncNotificationsForSession());
    notifyListeners();
  }

  void _watchPendingRequest(HouseholdJoinRequest request) {
    final service = _firebaseService;
    if (service == null) return;
    _pendingJoinSubscription?.cancel();
    pendingJoinRequest = request;
    invitationPreview = null;
    _pendingJoinSubscription = service.joinRequestStream(request).listen((
      next,
    ) {
      pendingJoinRequest = next;
      notifyListeners();
      if (next?.status == JoinRequestStatus.approved) {
        unawaited(_completeApprovedJoin());
      }
    }, onError: _setError);
    notifyListeners();
  }

  Future<void> _completeApprovedJoin() async {
    if (_completingApprovedJoin) return;
    final service = _firebaseService;
    if (service == null) return;
    _completingApprovedJoin = true;
    try {
      final session = await service.restoreSession();
      if (session != null) _startCloudSession(session);
    } catch (error) {
      _setError(error);
    } finally {
      _completingApprovedJoin = false;
    }
  }

  Future<void> _syncNotificationsForSession() async {
    final notifications = _notificationService;
    final home = household;
    final caregiver = currentCaregiver;
    if (notifications == null || home == null || caregiver == null) {
      notificationPermission = NotificationPermissionState.unavailable;
      notificationsEnabled = false;
      notifyListeners();
      return;
    }
    try {
      notificationPermission = await notifications.currentPermission();
      notificationsEnabled =
          notificationPermission.isGranted &&
          await notifications.prepareMember(
            householdId: home.id,
            caregiverId: caregiver.id,
          );
      notifyListeners();
    } catch (error) {
      _setError(error);
    }
  }

  void _createLocalHousehold({
    required String householdName,
    required List<Pet> pets,
    required String caregiverName,
  }) {
    final caregiver = Caregiver(
      id: _id('caregiver'),
      name: caregiverName.trim(),
      role: HouseholdRole.owner,
    );
    final home = Household(
      id: _id('household'),
      name: householdName.trim(),
      pets: pets,
      inviteCode: _inviteCode(),
    );
    _startLocalDemo(home: home, caregiver: caregiver);
  }

  void _joinLocalHousehold({
    required String inviteCode,
    required String caregiverName,
  }) {
    if (inviteCode.trim().toUpperCase() != 'PAW123') {
      errorMessage =
          'That invite code is not available in local demo mode. Try PAW123.';
      notifyListeners();
      return;
    }
    _startLocalDemo(
      home: const Household(
        id: 'local-demo-household',
        name: 'Mochi Family',
        pets: [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
        inviteCode: 'PAW123',
      ),
      caregiver: Caregiver(id: _id('caregiver'), name: caregiverName.trim()),
    );
  }

  void _startLocalDemo({
    required Household home,
    required Caregiver caregiver,
  }) {
    household = home;
    currentCaregiver = caregiver;
    const alex = Caregiver(id: 'alex', name: 'Alex');
    caregivers = [caregiver, alex];
    final now = DateTime.now();
    final start = _day(now);
    final allPetIds = home.pets.map((pet) => pet.id).toSet();
    routines = [
      CareRoutine(
        id: 'brush-coat',
        title: 'Brush coat',
        category: CareCategory.grooming,
        priority: TaskPriority.normal,
        hour: 7,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: start,
        createdBy: caregiver,
        petIds: allPetIds,
      ),
      CareRoutine(
        id: 'morning-meal',
        title: 'Morning meal',
        category: CareCategory.feeding,
        priority: TaskPriority.normal,
        hour: 8,
        minute: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: start,
        createdBy: caregiver,
        petIds: allPetIds,
      ),
      CareRoutine(
        id: 'allergy-medicine',
        title: 'Give allergy medicine',
        category: CareCategory.medication,
        priority: TaskPriority.urgent,
        hour: 10,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: start,
        createdBy: caregiver,
        petIds: allPetIds,
      ),
      CareRoutine(
        id: 'evening-walk',
        title: 'Evening walk',
        category: CareCategory.walking,
        priority: TaskPriority.normal,
        hour: 18,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: start,
        createdBy: caregiver,
        petIds: allPetIds,
      ),
    ];
    _oneOffTasks
      ..clear()
      ..add(
        CareTask(
          id: 'vet-call-${_dateKey(now)}',
          title: 'Confirm vet appointment',
          category: CareCategory.other,
          dueAt: _atTime(now, 14, 0),
          kind: TaskKind.oneOff,
          priority: TaskPriority.normal,
          createdBy: caregiver,
          status: TaskStatus.unclaimed,
          petIds: allPetIds,
        ),
      );
    _routineOverrides.clear();
    final brushed = _taskForRoutine(routines.first, now).copyWith(
      status: TaskStatus.completed,
      assignee: alex,
      completedBy: alex,
      completedAt: _atTime(now, 7, 45),
    );
    final eveningWalk = _taskForRoutine(
      routines[3],
      now,
    ).copyWith(status: TaskStatus.claimed, assignee: alex);
    _routineOverrides[brushed.id] = brushed;
    _routineOverrides[eveningWalk.id] = eveningWalk;
    errorMessage = null;
    notifyListeners();
  }

  void _clearSession() {
    _cancelSubscriptions();
    household = null;
    currentCaregiver = null;
    caregivers = const [];
    routines = const [];
    invitationPreview = null;
    activeInvitation = null;
    pendingJoinRequest = null;
    joinRequests = const [];
    _oneOffTasks.clear();
    _routineOverrides.clear();
    notificationPermission = NotificationPermissionState.unavailable;
    notificationsEnabled = false;
    errorMessage = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _householdSubscription?.cancel();
    _caregiverSubscription?.cancel();
    _routineSubscription?.cancel();
    _taskSubscription?.cancel();
    _joinRequestsSubscription?.cancel();
    _pendingJoinSubscription?.cancel();
    _householdSubscription = null;
    _caregiverSubscription = null;
    _routineSubscription = null;
    _taskSubscription = null;
    _joinRequestsSubscription = null;
    _pendingJoinSubscription = null;
  }

  void _setError(Object error) {
    final message = error is FirebaseCareException
        ? error.message
        : error.toString();
    errorMessage = message.replaceFirst('Exception: ', '');
    notifyListeners();
  }

  bool _isRoutineDue(CareRoutine routine, DateTime day) {
    final target = _day(day);
    return !target.isBefore(_day(routine.startDate)) &&
        routine.weekdays.contains(target.weekday);
  }

  CareTask _taskForRoutine(CareRoutine routine, DateTime day) => CareTask(
    id: '${routine.id}-${_dateKey(day)}',
    title: routine.title,
    category: routine.category,
    dueAt: _atTime(day, routine.hour, routine.minute),
    hasDueTime: routine.hasDueTime,
    kind: TaskKind.routine,
    priority: routine.priority,
    routineId: routine.id,
    createdBy: routine.createdBy,
    status: routine.assignee == null
        ? TaskStatus.unclaimed
        : TaskStatus.claimed,
    petIds: routine.petIds,
    assignee: routine.assignee,
  );

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}';

  String _inviteCode() => List.generate(
    6,
    (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[_random.nextInt(32)],
  ).join();

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

DateTime dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String dateKey(DateTime value) => _dateKey(value);

DateTime atTime(DateTime day, int hour, int minute) =>
    _atTime(day, hour, minute);

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _atTime(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
