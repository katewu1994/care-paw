import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/pet_species_icon.dart';
import '../widgets/paw_ui.dart';

Future<void> showProfileSheet(BuildContext context, CareStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProfileSheet(store: store),
  );
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({required this.store, super.key});

  final CareStore store;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _caregiver;
  late final TextEditingController _household;
  final List<_ProfilePetEntry> _pets = [];
  bool _changingNotifications = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    _caregiver = TextEditingController(
      text: widget.store.currentCaregiver?.name ?? '',
    );
    _household = TextEditingController(
      text: widget.store.household?.name ?? '',
    );
    _pets.addAll(
      (widget.store.household?.pets ?? const <Pet>[]).map(
        _ProfilePetEntry.fromPet,
      ),
    );
    unawaited(_refreshNotificationState());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _caregiver.dispose();
    _household.dispose();
    for (final pet in _pets) {
      pet.dispose();
    }
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_caregiver.text.trim().isEmpty ||
        _household.text.trim().isEmpty ||
        _pets.isEmpty ||
        _pets.any((pet) => pet.name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please name the household, yourself, and every pet.'),
        ),
      );
      return;
    }
    await widget.store.updateProfile(
      householdName: _household.text,
      pets: _pets.map((pet) => pet.toPet()).toList(),
      caregiverName: _caregiver.text,
    );
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

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this household?'),
        content: Text(
          widget.store.isCloudBacked
              ? 'This removes you from the shared household on this device.'
              : 'This clears the current demo data from the app session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pawRoseInk),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await widget.store.leaveHousehold();
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
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _changingNotifications = true);
    if (enabled) {
      await widget.store.enableNotifications();
    } else {
      await widget.store.disableNotifications();
    }
    if (!mounted) return;
    setState(() => _changingNotifications = false);

    final error = widget.store.errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (enabled && !widget.store.notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow notifications in your device settings, then try again.',
          ),
        ),
      );
    }
  }

  Future<void> _refreshNotificationState() async {
    await widget.store.refreshNotificationState();
    if (mounted) setState(() {});
  }

  Future<void> _createInvitation() async {
    await widget.store.createInvitation();
    if (mounted) setState(() {});
    _showStoreError();
  }

  Future<void> _revokeInvitation() async {
    await widget.store.revokeInvitation();
    if (mounted) setState(() {});
    _showStoreError();
  }

  Future<void> _reviewRequest(
    HouseholdJoinRequest request, {
    required bool approve,
  }) async {
    await widget.store.reviewJoinRequest(request, approve: approve);
    if (mounted) setState(() {});
    _showStoreError();
  }

  Future<void> _removeMember(Caregiver caregiver) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${caregiver.name}?'),
        content: const Text(
          'They will immediately lose access to this household and its care history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pawRoseInk),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    await widget.store.removeMember(caregiver);
    if (mounted) setState(() {});
    _showStoreError();
  }

  void _showStoreError() {
    if (!mounted) return;
    final error = widget.store.errorMessage;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: PawSpace.xxxl,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: pawCream,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PawRadius.xxl),
        ),
        child: SafeArea(
          top: false,
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
                    const CircleAvatar(
                      backgroundColor: pawLavender,
                      child: Icon(Icons.person_rounded, color: pawPurpleInk),
                    ),
                    const SizedBox(width: PawSpace.md),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Household profile',
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
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.xl,
                    PawSpace.sm,
                    PawSpace.xl,
                    PawSpace.xxl,
                  ),
                  children: [
                    PawCard(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: pawLavender,
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: pawPurpleInk,
                            ),
                          ),
                          const SizedBox(width: PawSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Care notifications',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: PawSpace.xxs),
                                Text(
                                  widget.store.isCloudBacked
                                      ? 'Receive task handoffs and care reminders on this device.'
                                      : 'Available with Firebase sync on Android and iOS.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: pawMuted),
                                ),
                              ],
                            ),
                          ),
                          if (_changingNotifications)
                            const Padding(
                              padding: EdgeInsets.all(PawSpace.md),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: pawPurple,
                                ),
                              ),
                            )
                          else
                            Switch.adaptive(
                              value: widget.store.notificationsEnabled,
                              onChanged: widget.store.isCloudBacked
                                  ? _toggleNotifications
                                  : null,
                              activeTrackColor: pawPurpleInk,
                            ),
                        ],
                      ),
                    ),
                    if (widget.store.isOwner) ...[
                      const SizedBox(height: PawSpace.lg),
                      _invitationCard(),
                      if (widget.store.joinRequests.isNotEmpty) ...[
                        const SizedBox(height: PawSpace.lg),
                        _joinRequestsCard(),
                      ],
                    ],
                    const SizedBox(height: PawSpace.lg),
                    _membersCard(),
                    const SizedBox(height: PawSpace.lg),
                    PawCard(
                      child: Column(
                        children: [
                          _field('Your name', _caregiver, Icons.person_rounded),
                          const SizedBox(height: PawSpace.lg),
                          _field(
                            'Household',
                            _household,
                            Icons.home_rounded,
                            enabled: widget.store.isOwner,
                          ),
                          const SizedBox(height: PawSpace.lg),
                          Row(
                            children: [
                              const Icon(
                                Icons.pets_rounded,
                                size: 14,
                                color: pawPurpleDark,
                              ),
                              const SizedBox(width: PawSpace.sm),
                              const Expanded(
                                child: Text(
                                  'Your pets',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: pawPurpleDark,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    !widget.store.isOwner || _pets.length >= 20
                                    ? null
                                    : _addPet,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                          ...List.generate(
                            _pets.length,
                            (index) => _petFields(
                              index,
                              enabled: widget.store.isOwner,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PawSpace.xl),
                    PawFilledButton(
                      label: 'Save profile',
                      icon: Icons.check_rounded,
                      onPressed: _save,
                    ),
                    const SizedBox(height: PawSpace.md),
                    if (!widget.store.isOwner)
                      PawOutlinedButton(
                        label: 'Leave household',
                        color: pawRoseInk,
                        onPressed: _leave,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invitationCard() {
    final invitation = widget.store.activeInvitation;
    return PawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite a caregiver',
            style: TextStyle(color: pawInk, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PawSpace.sm),
          const Text(
            'Each invitation expires after 24 hours, works once, and still requires your approval.',
            style: TextStyle(color: pawMuted, fontSize: 12),
          ),
          if (invitation == null) ...[
            const SizedBox(height: PawSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.store.isLoading ? null : _createInvitation,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Create one-time invitation'),
              ),
            ),
          ] else ...[
            const SizedBox(height: PawSpace.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(PawSpace.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(PawRadius.xl),
                ),
                child: QrImageView(
                  data: invitation.deepLink,
                  size: 190,
                  eyeStyle: const QrEyeStyle(color: pawPurpleDark),
                  dataModuleStyle: const QrDataModuleStyle(
                    color: pawPurpleDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: PawSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(PawSpace.md),
              decoration: BoxDecoration(
                color: pawLavender.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                invitation.deepLink,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: pawPurpleDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: PawSpace.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: invitation.deepLink),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invitation link copied.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: PawSpace.sm),
                IconButton.outlined(
                  tooltip: 'Revoke invitation',
                  onPressed: widget.store.isLoading ? null : _revokeInvitation,
                  icon: const Icon(Icons.block_rounded, color: pawRose),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _joinRequestsCard() => PawCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join requests',
          style: TextStyle(color: pawInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: PawSpace.md),
        ...widget.store.joinRequests.map(
          (request) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(PawSpace.md),
            decoration: BoxDecoration(
              color: pawLavender.withValues(alpha: .38),
              borderRadius: BorderRadius.circular(PawRadius.md),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: pawPurple,
                      ),
                    ),
                    const SizedBox(width: PawSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.name,
                            style: const TextStyle(
                              color: pawInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (request.email != null)
                            Text(
                              request.email!,
                              style: const TextStyle(
                                color: pawMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PawSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.store.isLoading
                            ? null
                            : () => _reviewRequest(request, approve: false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: PawSpace.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.store.isLoading
                            ? null
                            : () => _reviewRequest(request, approve: true),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _membersCard() => PawCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caregivers',
          style: TextStyle(color: pawInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: PawSpace.sm),
        ...widget.store.caregivers.map(
          (caregiver) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: caregiver.isOwner
                  ? pawLavender
                  : pawGreen.withValues(alpha: .12),
              child: Icon(
                caregiver.isOwner
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_rounded,
                color: caregiver.isOwner ? pawPurple : pawGreen,
              ),
            ),
            title: Text(
              caregiver.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              caregiver.isOwner ? 'Owner' : caregiver.email ?? 'Caregiver',
            ),
            trailing:
                widget.store.isOwner &&
                    !caregiver.isOwner &&
                    caregiver.id != widget.store.currentCaregiver?.id
                ? IconButton(
                    tooltip: 'Remove caregiver',
                    onPressed: () => _removeMember(caregiver),
                    icon: const Icon(
                      Icons.person_remove_outlined,
                      color: pawRoseInk,
                    ),
                  )
                : null,
          ),
        ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 14, color: pawPurpleDark),
          const SizedBox(width: PawSpace.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: pawPurpleDark,
            ),
          ),
        ],
      ),
      const SizedBox(height: PawSpace.sm),
      TextField(
        controller: controller,
        enabled: enabled,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          filled: true,
          fillColor: pawLavender.withValues(alpha: .45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PawRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );

  void _addPet() {
    setState(() {
      _pets.add(
        _ProfilePetEntry(
          id: 'pet-${DateTime.now().microsecondsSinceEpoch}',
          species: PetSpecies.dog,
        ),
      );
    });
  }

  void _removePet(int index) {
    if (_pets.length == 1) return;
    final removed = _pets.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Widget _petFields(int index, {required bool enabled}) {
    final pet = _pets[index];
    return Container(
      key: ValueKey(pet.id),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(PawSpace.md),
      decoration: BoxDecoration(
        color: pawLavender.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(PawRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PetSpecies>(
                  initialValue: pet.species,
                  decoration: _petInput('Type'),
                  items: PetSpecies.values
                      .map(
                        (species) => DropdownMenuItem(
                          value: species,
                          child: Row(
                            children: [
                              PetSpeciesIcon(
                                species: species,
                                color: pawPurpleDark,
                                size: 20,
                              ),
                              const SizedBox(width: PawSpace.sm),
                              Text(species.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (species) {
                          if (species != null) pet.species = species;
                        }
                      : null,
                ),
              ),
              if (enabled && _pets.length > 1) ...[
                const SizedBox(width: PawSpace.xs),
                IconButton(
                  tooltip: 'Remove pet',
                  onPressed: () => _removePet(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: pawRoseInk,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: PawSpace.md),
          TextField(
            controller: pet.name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: _petInput('Pet name'),
          ),
        ],
      ),
    );
  }

  InputDecoration _petInput(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withValues(alpha: .72),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PawRadius.md),
      borderSide: BorderSide.none,
    ),
  );
}

class _ProfilePetEntry {
  _ProfilePetEntry({required this.id, String name = '', required this.species})
    : name = TextEditingController(text: name);

  _ProfilePetEntry.fromPet(Pet pet)
    : id = pet.id,
      name = TextEditingController(text: pet.name),
      species = pet.species;

  final String id;
  final TextEditingController name;
  PetSpecies species;

  Pet toPet() => Pet(id: id, name: name.text.trim(), species: species);

  void dispose() => name.dispose();
}
