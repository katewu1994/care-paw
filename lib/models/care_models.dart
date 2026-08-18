enum CareCategory {
  feeding,
  walking,
  medication,
  grooming,
  hydration,
  play,
  training,
  toileting,
  vet,
  other,
}

extension CareCategoryDetails on CareCategory {
  String get label => switch (this) {
    CareCategory.feeding => 'Feeding',
    CareCategory.walking => 'Walking',
    CareCategory.medication => 'Medication',
    CareCategory.grooming => 'Grooming',
    CareCategory.hydration => 'Water',
    CareCategory.play => 'Playtime',
    CareCategory.training => 'Training',
    CareCategory.toileting => 'Toileting',
    CareCategory.vet => 'Vet care',
    CareCategory.other => 'Other',
  };
}

enum TaskKind { routine, oneOff }

enum TaskPriority { normal, urgent }

enum TaskStatus { unclaimed, claimed, completed, skipped }

enum AssignmentMode { direct, open }

enum PetSpecies {
  dog,
  cat,
  rabbit,
  bird,
  fish,
  hamster,
  guineaPig,
  ferret,
  turtle,
  reptile,
  amphibian,
  horse,
  other,
}

enum HouseholdRole { owner, caregiver }

enum InvitationStatus { active, claimed, approved, rejected, revoked }

enum JoinRequestStatus { pending, approved, rejected }

extension PetSpeciesDetails on PetSpecies {
  String get label => switch (this) {
    PetSpecies.dog => 'Dog',
    PetSpecies.cat => 'Cat',
    PetSpecies.rabbit => 'Rabbit',
    PetSpecies.bird => 'Bird',
    PetSpecies.fish => 'Fish',
    PetSpecies.hamster => 'Hamster',
    PetSpecies.guineaPig => 'Guinea pig',
    PetSpecies.ferret => 'Ferret',
    PetSpecies.turtle => 'Turtle',
    PetSpecies.reptile => 'Reptile',
    PetSpecies.amphibian => 'Amphibian',
    PetSpecies.horse => 'Horse',
    PetSpecies.other => 'Other',
  };
}

class Pet {
  const Pet({required this.id, required this.name, required this.species});

  final String id;
  final String name;
  final PetSpecies species;
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.pets,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final List<Pet> pets;
  final String inviteCode;

  String get petNames => pets.map((pet) => pet.name).join(', ');

  Household copyWith({String? name, List<Pet>? pets}) => Household(
    id: id,
    name: name ?? this.name,
    pets: pets ?? this.pets,
    inviteCode: inviteCode,
  );
}

class Caregiver {
  const Caregiver({
    required this.id,
    required this.name,
    this.role = HouseholdRole.caregiver,
    this.email,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final String? email;

  bool get isOwner => role == HouseholdRole.owner;

  Caregiver copyWith({String? name}) =>
      Caregiver(id: id, name: name ?? this.name, role: role, email: email);
}

class HouseholdInvitation {
  const HouseholdInvitation({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.petNames,
    required this.inviterName,
    required this.expiresAt,
    required this.status,
  });

  final String id;
  final String householdId;
  final String householdName;
  final List<String> petNames;
  final String inviterName;
  final DateTime expiresAt;
  final InvitationStatus status;

  String get deepLink => 'copaw://invite/$id';
  bool get isActive =>
      status == InvitationStatus.active && expiresAt.isAfter(DateTime.now());
}

class HouseholdJoinRequest {
  const HouseholdJoinRequest({
    required this.userId,
    required this.householdId,
    required this.invitationId,
    required this.name,
    required this.createdAt,
    required this.status,
    this.email,
  });

  final String userId;
  final String householdId;
  final String invitationId;
  final String name;
  final String? email;
  final DateTime createdAt;
  final JoinRequestStatus status;
}

class AssignmentRequest {
  const AssignmentRequest({
    required this.id,
    required this.requestedBy,
    required this.createdAt,
    required this.mode,
    this.requestedTo,
  });

  final String id;
  final Caregiver requestedBy;
  final Caregiver? requestedTo;
  final DateTime createdAt;
  final AssignmentMode mode;
}

class CareRoutine {
  const CareRoutine({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.hour,
    required this.minute,
    this.hasDueTime = true,
    required this.weekdays,
    required this.startDate,
    required this.createdBy,
    required this.petIds,
    this.assignee,
  });

  final String id;
  final String title;
  final CareCategory category;
  final TaskPriority priority;
  final int hour;
  final int minute;
  final bool hasDueTime;

  /// DateTime.weekday values: Monday is 1 and Sunday is 7.
  final Set<int> weekdays;
  final DateTime startDate;
  final Caregiver createdBy;
  final Caregiver? assignee;

  /// Empty only for legacy routines created before pet assignment existed.
  /// Legacy routines are treated as applying to every pet in the household.
  final Set<String> petIds;

  CareRoutine copyWith({
    String? title,
    CareCategory? category,
    TaskPriority? priority,
    int? hour,
    int? minute,
    bool? hasDueTime,
    Set<int>? weekdays,
    DateTime? startDate,
    Set<String>? petIds,
    Caregiver? assignee,
    bool clearAssignee = false,
  }) => CareRoutine(
    id: id,
    title: title ?? this.title,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    hasDueTime: hasDueTime ?? this.hasDueTime,
    weekdays: weekdays ?? this.weekdays,
    startDate: startDate ?? this.startDate,
    createdBy: createdBy,
    petIds: petIds ?? this.petIds,
    assignee: clearAssignee ? null : (assignee ?? this.assignee),
  );
}

class CareTask {
  const CareTask({
    required this.id,
    required this.title,
    required this.category,
    required this.dueAt,
    this.hasDueTime = true,
    required this.kind,
    required this.priority,
    required this.createdBy,
    required this.status,
    required this.petIds,
    this.routineId,
    this.assignee,
    this.assignmentRequest,
    this.completedBy,
    this.completedAt,
  });

  final String id;
  final String title;
  final CareCategory category;
  final DateTime dueAt;
  final bool hasDueTime;
  final TaskKind kind;
  final TaskPriority priority;
  final String? routineId;
  final Caregiver createdBy;
  final TaskStatus status;

  /// Empty only for legacy tasks, which apply to every household pet.
  final Set<String> petIds;
  final Caregiver? assignee;
  final AssignmentRequest? assignmentRequest;
  final Caregiver? completedBy;
  final DateTime? completedAt;

  CareTask copyWith({
    String? title,
    CareCategory? category,
    DateTime? dueAt,
    bool? hasDueTime,
    TaskPriority? priority,
    Set<String>? petIds,
    TaskStatus? status,
    Caregiver? assignee,
    bool clearAssignee = false,
    AssignmentRequest? assignmentRequest,
    bool clearAssignmentRequest = false,
    Caregiver? completedBy,
    DateTime? completedAt,
    bool clearCompletion = false,
  }) {
    return CareTask(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      dueAt: dueAt ?? this.dueAt,
      hasDueTime: hasDueTime ?? this.hasDueTime,
      kind: kind,
      priority: priority ?? this.priority,
      routineId: routineId,
      createdBy: createdBy,
      status: status ?? this.status,
      petIds: petIds ?? this.petIds,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      assignmentRequest: clearAssignmentRequest
          ? null
          : (assignmentRequest ?? this.assignmentRequest),
      completedBy: clearCompletion ? null : (completedBy ?? this.completedBy),
      completedAt: clearCompletion ? null : (completedAt ?? this.completedAt),
    );
  }
}
