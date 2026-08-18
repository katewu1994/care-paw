import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/care_models.dart';

class FirebaseCareService {
  FirebaseCareService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Random _secureRandom = Random.secure();

  CollectionReference<Map<String, dynamic>> get _households =>
      _firestore.collection('households');

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('invitations');

  DocumentReference<Map<String, dynamic>> _householdRef(String id) =>
      _households.doc(id);

  CollectionReference<Map<String, dynamic>> _membersRef(String householdId) =>
      _householdRef(householdId).collection('members');

  CollectionReference<Map<String, dynamic>> _joinRequestsRef(
    String householdId,
  ) => _householdRef(householdId).collection('joinRequests');

  CollectionReference<Map<String, dynamic>> _devicesRef(
    String householdId,
    String caregiverId,
  ) => _membersRef(householdId).doc(caregiverId).collection('devices');

  CollectionReference<Map<String, dynamic>> _routinesRef(String householdId) =>
      _householdRef(householdId).collection('routines');

  CollectionReference<Map<String, dynamic>> _tasksRef(String householdId) =>
      _householdRef(householdId).collection('tasks');

  Future<String> ensureSignedIn() async {
    final signedIn = _auth.currentUser;
    if (signedIn != null) return signedIn.uid;
    return (await _auth.signInAnonymously()).user!.uid;
  }

  Future<User> _signedInUser() async {
    await ensureSignedIn();
    final user = _auth.currentUser;
    if (user == null) {
      throw const FirebaseCareException(
        'Unable to start a Firebase session. Please try again.',
      );
    }
    await user.getIdToken(true);
    return user;
  }

  Future<CloudSession?> restoreSession() async {
    final uid = await ensureSignedIn();
    final memberships = await _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (memberships.docs.isEmpty) return null;

    final memberDocument = memberships.docs.first;
    final householdReference = memberDocument.reference.parent.parent;
    if (householdReference == null) return null;
    final householdDocument = await householdReference.get();
    if (!householdDocument.exists) return null;
    return CloudSession(
      household: _householdFrom(householdDocument),
      caregiver: _caregiverFrom(memberDocument),
    );
  }

  Future<CloudSession> createHousehold({
    required String householdName,
    required List<Pet> pets,
    required String caregiverName,
  }) async {
    final user = await _signedInUser();
    final uid = user.uid;
    final householdReference = _households.doc();
    final memberReference = _membersRef(householdReference.id).doc(uid);
    final now = Timestamp.now();
    final caregiver = Caregiver(
      id: uid,
      name: caregiverName.trim(),
      role: HouseholdRole.owner,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(householdReference, {
        'name': householdName.trim(),
        'pets': pets.map(_petData).toList(),
        'ownerId': uid,
        'timeZone': 'Asia/Tokyo',
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.set(memberReference, {
        'userId': uid,
        'name': caregiver.name,
        'role': HouseholdRole.owner.name,
        'createdAt': now,
      });

      final petIds = pets.map((pet) => pet.id).toSet();
      for (final routine in _seedRoutines(caregiver, petIds)) {
        transaction.set(
          _routinesRef(householdReference.id).doc(routine.id),
          _routineData(routine),
        );
      }
    });

    return CloudSession(
      household: Household(
        id: householdReference.id,
        name: householdName.trim(),
        pets: pets,
        inviteCode: '',
      ),
      caregiver: caregiver,
    );
  }

  Future<HouseholdInvitation> createInvitation({
    required Household household,
    required Caregiver inviter,
  }) async {
    final user = await _signedInUser();
    if (user.uid != inviter.id || !inviter.isOwner) {
      throw const FirebaseCareException(
        'Only the household owner can create invitations.',
      );
    }

    final invitationId = _newInvitationId();
    final now = DateTime.now();
    final invitation = HouseholdInvitation(
      id: invitationId,
      householdId: household.id,
      householdName: household.name,
      petNames: household.pets.map((pet) => pet.name).toList(),
      inviterName: inviter.name,
      expiresAt: now.add(const Duration(hours: 24)),
      status: InvitationStatus.active,
    );
    await _invitations.doc(invitationId).set({
      'householdId': household.id,
      'householdName': household.name,
      'petNames': invitation.petNames,
      'invitedBy': inviter.id,
      'inviterName': inviter.name,
      'status': InvitationStatus.active.name,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(invitation.expiresAt),
    });
    return invitation;
  }

  Future<HouseholdInvitation> loadInvitation(String value) async {
    await ensureSignedIn();
    final invitationId = invitationIdFrom(value);
    if (invitationId == null) {
      throw const FirebaseCareException('That invitation link is invalid.');
    }
    final document = await _invitations.doc(invitationId).get();
    if (!document.exists) {
      throw const FirebaseCareException('That invitation was not found.');
    }
    final invitation = _invitationFrom(document);
    if (invitation.status != InvitationStatus.active) {
      throw const FirebaseCareException(
        'That invitation has already been used or revoked.',
      );
    }
    if (!invitation.expiresAt.isAfter(DateTime.now())) {
      throw const FirebaseCareException('That invitation has expired.');
    }
    return invitation;
  }

  Future<HouseholdJoinRequest> requestToJoin({
    required HouseholdInvitation invitation,
    required String caregiverName,
  }) async {
    final user = await _signedInUser();
    final invitationReference = _invitations.doc(invitation.id);
    final requestReference = _joinRequestsRef(
      invitation.householdId,
    ).doc(user.uid);
    final now = Timestamp.now();

    await _firestore.runTransaction((transaction) async {
      final currentInvitation = await transaction.get(invitationReference);
      if (!currentInvitation.exists) {
        throw const FirebaseCareException('That invitation was not found.');
      }
      final data = currentInvitation.data()!;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (data['status'] != InvitationStatus.active.name ||
          expiresAt == null ||
          !expiresAt.toDate().isAfter(DateTime.now())) {
        throw const FirebaseCareException(
          'That invitation has expired or has already been used.',
        );
      }
      final existingRequest = await transaction.get(requestReference);
      final existingStatus = existingRequest.data()?['status'];
      if (existingStatus == JoinRequestStatus.pending.name) {
        throw const FirebaseCareException(
          'You already have a request for this household.',
        );
      }
      if (existingRequest.exists &&
          existingStatus != JoinRequestStatus.approved.name &&
          existingStatus != JoinRequestStatus.rejected.name) {
        throw const FirebaseCareException(
          'Your previous request could not be replaced. Please ask the owner to create a new invitation.',
        );
      }

      transaction.update(invitationReference, {
        'status': InvitationStatus.claimed.name,
        'claimedBy': user.uid,
        'claimedName': caregiverName.trim(),
        'claimedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(requestReference, {
        'userId': user.uid,
        'name': caregiverName.trim(),
        'inviteId': invitation.id,
        'invitedBy': data['invitedBy'],
        'status': JoinRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return HouseholdJoinRequest(
      userId: user.uid,
      householdId: invitation.householdId,
      invitationId: invitation.id,
      name: caregiverName.trim(),
      createdAt: now.toDate(),
      status: JoinRequestStatus.pending,
    );
  }

  Future<HouseholdJoinRequest?> restorePendingJoinRequest() async {
    final uid = await ensureSignedIn();
    final requests = await _firestore
        .collectionGroup('joinRequests')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .limit(1)
        .get();
    if (requests.docs.isEmpty) return null;
    return _joinRequestFrom(requests.docs.first);
  }

  Stream<HouseholdJoinRequest?> joinRequestStream(
    HouseholdJoinRequest request,
  ) => _joinRequestsRef(request.householdId)
      .doc(request.userId)
      .snapshots()
      .map((document) => document.exists ? _joinRequestFrom(document) : null);

  Stream<List<HouseholdJoinRequest>> joinRequestsStream(String householdId) =>
      _joinRequestsRef(householdId)
          .where('status', isEqualTo: JoinRequestStatus.pending.name)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(_joinRequestFrom).toList()
              ..sort(
                (first, second) => first.createdAt.compareTo(second.createdAt),
              ),
          );

  Future<void> reviewJoinRequest({
    required HouseholdJoinRequest request,
    required Caregiver reviewer,
    required bool approve,
  }) async {
    if (!reviewer.isOwner) {
      throw const FirebaseCareException(
        'Only the household owner can review join requests.',
      );
    }
    final requestReference = _joinRequestsRef(
      request.householdId,
    ).doc(request.userId);
    final invitationReference = _invitations.doc(request.invitationId);
    final memberReference = _membersRef(
      request.householdId,
    ).doc(request.userId);

    await _firestore.runTransaction((transaction) async {
      final currentRequest = await transaction.get(requestReference);
      if (!currentRequest.exists ||
          currentRequest.data()?['status'] != JoinRequestStatus.pending.name) {
        throw const FirebaseCareException(
          'This join request is no longer pending.',
        );
      }
      final status = approve
          ? JoinRequestStatus.approved
          : JoinRequestStatus.rejected;
      transaction.update(requestReference, {
        'status': status.name,
        'reviewedBy': reviewer.id,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(invitationReference, {
        'status': approve
            ? InvitationStatus.approved.name
            : InvitationStatus.rejected.name,
        'reviewedBy': reviewer.id,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (approve) {
        final data = currentRequest.data()!;
        transaction.set(memberReference, {
          'userId': request.userId,
          'name': data['name'],
          'role': HouseholdRole.caregiver.name,
          'createdAt': FieldValue.serverTimestamp(),
          'approvedBy': reviewer.id,
        });
      }
    });
  }

  Future<void> revokeInvitation(HouseholdInvitation invitation) =>
      _invitations.doc(invitation.id).update({
        'status': InvitationStatus.revoked.name,
        'revokedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeMember({
    required String householdId,
    required String caregiverId,
  }) => _membersRef(householdId).doc(caregiverId).delete();

  Stream<Household?> householdStream(String householdId) =>
      _householdRef(householdId).snapshots().map(
        (snapshot) => snapshot.exists ? _householdFrom(snapshot) : null,
      );

  Stream<List<Caregiver>> caregiversStream(String householdId) =>
      _membersRef(householdId).snapshots().map(
        (snapshot) =>
            snapshot.docs.map(_caregiverFrom).toList()
              ..sort((first, second) => first.name.compareTo(second.name)),
      );

  Stream<List<CareRoutine>> routinesStream(String householdId) => _routinesRef(
    householdId,
  ).snapshots().map((snapshot) => snapshot.docs.map(_routineFrom).toList());

  Stream<List<CareTask>> tasksStream(String householdId) => _tasksRef(
    householdId,
  ).snapshots().map((snapshot) => snapshot.docs.map(_taskFrom).toList());

  Future<void> addTask({required String householdId, required CareTask task}) =>
      _tasksRef(householdId).doc(task.id).set(_taskData(task));

  Future<void> addRoutine({
    required String householdId,
    required CareRoutine routine,
  }) => _routinesRef(householdId).doc(routine.id).set(_routineData(routine));

  Future<void> updateRoutine({
    required String householdId,
    required CareRoutine routine,
    required List<CareTask> taskOverrides,
  }) async {
    final batch = _firestore.batch();
    batch.set(_routinesRef(householdId).doc(routine.id), _routineData(routine));
    for (final task in taskOverrides) {
      batch.set(_tasksRef(householdId).doc(task.id), _taskData(task));
    }
    await batch.commit();
  }

  Future<void> deleteTask({
    required String householdId,
    required String taskId,
  }) => _tasksRef(householdId).doc(taskId).delete();

  Future<void> deleteRoutine({
    required String householdId,
    required String routineId,
    required List<String> taskOverrideIds,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_routinesRef(householdId).doc(routineId));
    for (final taskId in taskOverrideIds) {
      batch.delete(_tasksRef(householdId).doc(taskId));
    }
    await batch.commit();
  }

  Future<void> replaceTask({
    required String householdId,
    required CareTask task,
  }) => _tasksRef(householdId).doc(task.id).set(_taskData(task));

  Future<void> updateProfile({
    required String householdId,
    required Caregiver caregiver,
    required String householdName,
    required List<Pet> pets,
  }) async {
    final batch = _firestore.batch();
    if (caregiver.isOwner) {
      batch.update(_householdRef(householdId), {
        'name': householdName.trim(),
        'pets': pets.map(_petData).toList(),
        'petName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_membersRef(householdId).doc(caregiver.id), {
      'userId': caregiver.id,
      'name': caregiver.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> leaveHousehold({
    required String householdId,
    required String caregiverId,
  }) => _membersRef(householdId).doc(caregiverId).delete();

  /// Stores an FCM token in a private device subcollection. Tokens are never
  /// placed in a member document because every household member can read that
  /// document to render the caregiver list.
  Future<void> savePushToken({
    required String householdId,
    required String caregiverId,
    required String token,
    required String platform,
  }) => _devicesRef(householdId, caregiverId).doc(_tokenId(token)).set({
    'token': token,
    'platform': platform,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> removePushToken({
    required String householdId,
    required String caregiverId,
    required String token,
  }) => _devicesRef(householdId, caregiverId).doc(_tokenId(token)).delete();

  Future<bool> notificationsEnabled({
    required String householdId,
    required String caregiverId,
  }) async {
    final document = await _membersRef(householdId).doc(caregiverId).get();
    return document.data()?['notificationsEnabled'] == true;
  }

  Future<void> setNotificationsEnabled({
    required String householdId,
    required String caregiverId,
    required bool enabled,
  }) => _membersRef(householdId).doc(caregiverId).set({
    'notificationsEnabled': enabled,
    'notificationUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  String _newInvitationId() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String? invitationIdFrom(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    String token = trimmed;
    if (uri != null && uri.scheme == 'copaw' && uri.host == 'invite') {
      if (uri.pathSegments.isEmpty) return null;
      token = uri.pathSegments.first;
    }
    return RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(token) ? token : null;
  }

  List<CareRoutine> _seedRoutines(Caregiver caregiver, Set<String> petIds) {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    return [
      CareRoutine(
        id: 'brush-coat',
        title: 'Brush coat',
        category: CareCategory.grooming,
        priority: TaskPriority.normal,
        hour: 7,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: startDate,
        createdBy: caregiver,
        petIds: petIds,
      ),
      CareRoutine(
        id: 'morning-meal',
        title: 'Morning meal',
        category: CareCategory.feeding,
        priority: TaskPriority.normal,
        hour: 8,
        minute: 0,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: startDate,
        createdBy: caregiver,
        petIds: petIds,
      ),
      CareRoutine(
        id: 'allergy-medicine',
        title: 'Give allergy medicine',
        category: CareCategory.medication,
        priority: TaskPriority.urgent,
        hour: 10,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: startDate,
        createdBy: caregiver,
        petIds: petIds,
      ),
      CareRoutine(
        id: 'evening-walk',
        title: 'Evening walk',
        category: CareCategory.walking,
        priority: TaskPriority.normal,
        hour: 18,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: startDate,
        createdBy: caregiver,
        petIds: petIds,
      ),
    ];
  }

  Household _householdFrom(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    final storedPets = (data['pets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_petFrom)
        .where((pet) => pet.name.isNotEmpty)
        .toList();
    final legacyPetName = (data['petName'] as String? ?? '').trim();
    return Household(
      id: document.id,
      name: data['name'] as String? ?? 'Untitled household',
      pets: storedPets.isNotEmpty
          ? storedPets
          : [
              Pet(
                id: 'legacy-pet',
                name: legacyPetName.isEmpty ? 'Pet' : legacyPetName,
                species: PetSpecies.other,
              ),
            ],
      inviteCode: data['inviteCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> _petData(Pet pet) => {
    'id': pet.id,
    'name': pet.name.trim(),
    'species': pet.species.name,
  };

  Pet _petFrom(Map<String, dynamic> data) => Pet(
    id: data['id'] as String? ?? '',
    name: (data['name'] as String? ?? '').trim(),
    species:
        PetSpecies.values
            .where((species) => species.name == data['species'])
            .firstOrNull ??
        PetSpecies.other,
  );

  Caregiver _caregiverFrom(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return Caregiver(
      id: data['userId'] as String? ?? document.id,
      name: data['name'] as String? ?? 'Caregiver',
      // Legacy member documents predate roles. Treat them as owners so they
      // can migrate their household instead of being locked out.
      role: data['role'] == HouseholdRole.caregiver.name
          ? HouseholdRole.caregiver
          : HouseholdRole.owner,
      email: data['email'] as String?,
    );
  }

  HouseholdInvitation _invitationFrom(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return HouseholdInvitation(
      id: document.id,
      householdId: data['householdId'] as String? ?? '',
      householdName: data['householdName'] as String? ?? 'Care household',
      petNames: (data['petNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      inviterName: data['inviterName'] as String? ?? 'A caregiver',
      expiresAt:
          _date(data['expiresAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      status:
          InvitationStatus.values
              .where((status) => status.name == data['status'])
              .firstOrNull ??
          InvitationStatus.revoked,
    );
  }

  HouseholdJoinRequest _joinRequestFrom(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return HouseholdJoinRequest(
      userId: data['userId'] as String? ?? document.id,
      householdId: document.reference.parent.parent?.id ?? '',
      invitationId: data['inviteId'] as String? ?? '',
      name: data['name'] as String? ?? 'Caregiver',
      email: data['email'] as String?,
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      status:
          JoinRequestStatus.values
              .where((status) => status.name == data['status'])
              .firstOrNull ??
          JoinRequestStatus.pending,
    );
  }

  CareRoutine _routineFrom(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return CareRoutine(
      id: document.id,
      title: data['title'] as String? ?? 'Care task',
      category: _category(data['category'] as String?),
      priority: _priority(data['priority'] as String?),
      hour: data['hour'] as int? ?? 9,
      minute: data['minute'] as int? ?? 0,
      hasDueTime: data['hasDueTime'] as bool? ?? true,
      weekdays: ((data['weekdays'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((weekday) => weekday.toInt())
          .toSet()),
      startDate: _date(data['startDate']) ?? DateTime.now(),
      createdBy: _caregiver(
        data['createdBy'] as Map<String, dynamic>? ?? const {},
      ),
      petIds: _petIds(data['petIds']),
      assignee: _optionalCaregiver(data['assignee']),
    );
  }

  CareTask _taskFrom(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    final requestData = data['assignmentRequest'] as Map<String, dynamic>?;
    return CareTask(
      id: document.id,
      title: data['title'] as String? ?? 'Care task',
      category: _category(data['category'] as String?),
      dueAt: _date(data['dueAt']) ?? DateTime.now(),
      hasDueTime: data['hasDueTime'] as bool? ?? true,
      kind: data['kind'] == 'routine' ? TaskKind.routine : TaskKind.oneOff,
      priority: _priority(data['priority'] as String?),
      routineId: data['routineId'] as String?,
      createdBy: _caregiver(
        data['createdBy'] as Map<String, dynamic>? ?? const {},
      ),
      status: _status(data['status'] as String?),
      petIds: _petIds(data['petIds']),
      assignee: _optionalCaregiver(data['assignee']),
      assignmentRequest: requestData == null
          ? null
          : _assignmentRequest(requestData),
      completedBy: _optionalCaregiver(data['completedBy']),
      completedAt: _date(data['completedAt']),
    );
  }

  Map<String, dynamic> _routineData(CareRoutine routine) => {
    'title': routine.title,
    'category': routine.category.name,
    'priority': routine.priority.name,
    'hour': routine.hour,
    'minute': routine.minute,
    'hasDueTime': routine.hasDueTime,
    'weekdays': routine.weekdays.toList()..sort(),
    'startDate': Timestamp.fromDate(routine.startDate),
    'startDateKey': _dateKey(routine.startDate),
    'createdBy': _caregiverData(routine.createdBy),
    'petIds': routine.petIds.toList()..sort(),
    'assignee': routine.assignee == null
        ? null
        : _caregiverData(routine.assignee!),
  };

  Map<String, dynamic> _taskData(CareTask task) => {
    'title': task.title,
    'category': task.category.name,
    'dueAt': Timestamp.fromDate(task.dueAt),
    'hasDueTime': task.hasDueTime,
    'kind': task.kind == TaskKind.routine ? 'routine' : 'oneOff',
    'priority': task.priority.name,
    'routineId': task.routineId,
    'createdBy': _caregiverData(task.createdBy),
    'status': task.status.name,
    'petIds': task.petIds.toList()..sort(),
    'assignee': task.assignee == null ? null : _caregiverData(task.assignee!),
    'assignmentRequest': task.assignmentRequest == null
        ? null
        : _assignmentRequestData(task.assignmentRequest!),
    'completedBy': task.completedBy == null
        ? null
        : _caregiverData(task.completedBy!),
    'completedAt': task.completedAt == null
        ? null
        : Timestamp.fromDate(task.completedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _caregiverData(Caregiver caregiver) => {
    'id': caregiver.id,
    'name': caregiver.name,
  };

  Map<String, dynamic> _assignmentRequestData(AssignmentRequest request) => {
    'id': request.id,
    'requestedBy': _caregiverData(request.requestedBy),
    'requestedTo': request.requestedTo == null
        ? null
        : _caregiverData(request.requestedTo!),
    'createdAt': Timestamp.fromDate(request.createdAt),
    'mode': request.mode.name,
  };

  Caregiver _caregiver(Map<String, dynamic> data) => Caregiver(
    id: data['id'] as String? ?? '',
    name: data['name'] as String? ?? 'Caregiver',
  );

  Caregiver? _optionalCaregiver(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return _caregiver(value);
  }

  AssignmentRequest _assignmentRequest(Map<String, dynamic> data) =>
      AssignmentRequest(
        id: data['id'] as String? ?? '',
        requestedBy: _caregiver(
          data['requestedBy'] as Map<String, dynamic>? ?? const {},
        ),
        requestedTo: _optionalCaregiver(data['requestedTo']),
        createdAt: _date(data['createdAt']) ?? DateTime.now(),
        mode: data['mode'] == 'open'
            ? AssignmentMode.open
            : AssignmentMode.direct,
      );

  DateTime? _date(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;

  Set<String> _petIds(Object? value) => value is List
      ? value.whereType<String>().where((id) => id.isNotEmpty).toSet()
      : <String>{};

  String _tokenId(String token) =>
      base64Url.encode(utf8.encode(token)).replaceAll('=', '');

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  CareCategory _category(String? value) =>
      CareCategory.values
          .where((category) => category.name == value)
          .firstOrNull ??
      CareCategory.other;

  TaskPriority _priority(String? value) => value == TaskPriority.urgent.name
      ? TaskPriority.urgent
      : TaskPriority.normal;

  TaskStatus _status(String? value) =>
      TaskStatus.values.where((status) => status.name == value).firstOrNull ??
      TaskStatus.unclaimed;
}

class CloudSession {
  const CloudSession({required this.household, required this.caregiver});

  final Household household;
  final Caregiver caregiver;
}

class FirebaseCareException implements Exception {
  const FirebaseCareException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
