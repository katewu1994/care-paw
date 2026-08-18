import 'package:flutter/material.dart';

import '../models/care_models.dart';
import '../state/care_store.dart';
import '../widgets/pet_species_icon.dart';
import '../widgets/paw_ui.dart';
import 'qr_scanner_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.store, super.key});

  final CareStore store;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _name = TextEditingController();
  final _household = TextEditingController();
  final _invite = TextEditingController();
  final List<_PetEntry> _pets = [_PetEntry(id: 'pet-1')];
  int _nextPetId = 2;
  bool _isJoinMode = false;
  String? _shownInvitationId;

  bool get _joining => _isJoinMode || widget.store.invitationPreview != null;

  @override
  void dispose() {
    _scrollController.dispose();
    _name.dispose();
    _household.dispose();
    _invite.dispose();
    for (final pet in _pets) {
      pet.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_joining) {
      if (widget.store.invitationPreview == null) {
        await widget.store.previewInvitation(_invite.text);
      } else {
        await widget.store.requestToJoin(caregiverName: _name.text);
      }
    } else {
      await widget.store.createHousehold(
        householdName: _household.text,
        pets: _pets.map((pet) => pet.toPet()).toList(),
        caregiverName: _name.text,
      );
    }
  }

  Future<void> _scanInvitation() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const InvitationScannerPage()),
    );
    if (value == null || !mounted) return;
    _invite.text = value;
    setState(() => _isJoinMode = true);
    await widget.store.previewInvitation(value);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.store.errorMessage;
    final preview = widget.store.invitationPreview;
    if (preview != null && preview.id != _shownInvitationId) {
      _shownInvitationId = preview.id;
      _invite.text = preview.deepLink;
    }
    final pendingRequest = widget.store.pendingJoinRequest;
    return PawBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                PawSpace.xl,
                PawSpace.xl,
                PawSpace.xl,
                PawSpace.xxxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _brand(),
                      if (pendingRequest != null) ...[
                        const SizedBox(height: 26),
                        _pendingRequestCard(pendingRequest),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          _errorBanner(error),
                        ],
                      ] else ...[
                        const SizedBox(height: PawSpace.xxl),
                        Text(
                          _joining
                              ? 'Join your care team'
                              : 'Create your care home',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: PawSpace.sm),
                        Text(
                          _joining
                              ? 'Preview the household first. The owner must approve your request before any care data is shared.'
                              : 'Add the people and pets you care for. You can change these later.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: pawMuted),
                        ),
                        const SizedBox(height: PawSpace.xl),
                        _modeSelector(),
                        const SizedBox(height: PawSpace.lg),
                        PawCard(
                          padding: const EdgeInsets.all(PawSpace.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Your name'),
                              const SizedBox(height: PawSpace.sm),
                              TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                decoration: _input('Enter your name'),
                                validator: _required,
                              ),
                              const SizedBox(height: PawSpace.xl),
                              if (_joining) _joinFields() else _createFields(),
                            ],
                          ),
                        ),
                        if (preview != null) ...[
                          const SizedBox(height: PawSpace.md),
                          _invitationPreview(preview),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: PawSpace.md),
                          _errorBanner(error),
                        ],
                        const SizedBox(height: PawSpace.lg),
                        PawFilledButton(
                          label: _joining
                              ? preview == null
                                    ? 'Preview invitation'
                                    : 'Request to join'
                              : 'Create household',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: widget.store.isLoading ? null : _submit,
                        ),
                        const SizedBox(height: PawSpace.lg),
                        Center(
                          child: Text(
                            'Shared care for every pet, in one place.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: pawMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() => Row(
    children: [
      const _BrandMark(),
      const SizedBox(width: PawSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('copaw', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PawSpace.xxs),
            Text(
              'Care together, every day.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: pawMuted),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _modeSelector() => SizedBox(
    width: double.infinity,
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Create'),
          icon: Icon(Icons.add_home_rounded),
        ),
        ButtonSegment(
          value: true,
          label: Text('Join'),
          icon: Icon(Icons.group_add_rounded),
        ),
      ],
      selected: {_joining},
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(pawPurpleDark),
        side: WidgetStatePropertyAll(
          BorderSide(color: pawPurple.withValues(alpha: .28)),
        ),
      ),
      onSelectionChanged: (value) {
        setState(() {
          _isJoinMode = value.first;
          if (!_isJoinMode) {
            _shownInvitationId = null;
            _invite.clear();
            widget.store.clearInvitationPreview();
          }
          widget.store.clearError();
        });
      },
    ),
  );

  Widget _joinFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('Invitation link'),
      const SizedBox(height: PawSpace.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _invite,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _input('Paste a copaw invitation link'),
              validator: _required,
              onChanged: (_) {
                if (widget.store.invitationPreview != null) {
                  _shownInvitationId = null;
                  widget.store.clearInvitationPreview();
                }
              },
            ),
          ),
          const SizedBox(width: PawSpace.sm),
          IconButton.filledTonal(
            tooltip: 'Scan QR code',
            onPressed: widget.store.isCloudBacked ? _scanInvitation : null,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      const SizedBox(height: PawSpace.sm),
      Text(
        widget.store.isCloudBacked
            ? 'Invitations expire after 24 hours and can only be claimed once.'
            : 'Local demo code: PAW123',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: pawMuted),
      ),
    ],
  );

  Widget _invitationPreview(HouseholdInvitation invitation) => PawCard(
    padding: const EdgeInsets.all(PawSpace.lg),
    color: pawLavender.withValues(alpha: .62),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_rounded, color: pawPurpleInk, size: 20),
            const SizedBox(width: PawSpace.sm),
            Expanded(
              child: Text(
                'Check before requesting',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: PawSpace.md),
        Text(
          invitation.householdName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: PawSpace.xs),
        Text(
          'Invited by ${invitation.inviterName}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: pawMuted),
        ),
        const SizedBox(height: PawSpace.sm),
        Text(
          'Pets: ${invitation.petNames.join(', ')}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: PawSpace.sm),
        Text(
          'No household tasks or history are visible until the owner approves you.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: pawMuted),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _invite.clear();
              _shownInvitationId = null;
              widget.store.clearInvitationPreview();
            },
            child: const Text('This is not my household'),
          ),
        ),
      ],
    ),
  );

  Widget _pendingRequestCard(HouseholdJoinRequest request) {
    final rejected = request.status == JoinRequestStatus.rejected;
    return PawCard(
      padding: const EdgeInsets.all(PawSpace.xxl),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: (rejected ? pawRose : pawPurple).withValues(
              alpha: .14,
            ),
            child: Icon(
              rejected ? Icons.close_rounded : Icons.hourglass_top_rounded,
              color: rejected ? pawRoseInk : pawPurpleInk,
              size: 30,
            ),
          ),
          const SizedBox(height: PawSpace.lg),
          Text(
            rejected ? 'Request declined' : 'Waiting for owner approval',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: PawSpace.sm),
          Text(
            rejected
                ? 'Ask the household owner for a new invitation if this was unexpected.'
                : 'Your request was sent as ${request.name}. The household will open automatically after approval.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: pawMuted),
          ),
          if (request.email != null) ...[
            const SizedBox(height: PawSpace.md),
            PawTag(
              label: request.email!,
              color: pawGreen,
              ink: pawGreenInk,
              icon: Icons.verified_user_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _createFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('Household name'),
      const SizedBox(height: PawSpace.sm),
      TextFormField(
        controller: _household,
        textCapitalization: TextCapitalization.words,
        decoration: _input('e.g. The Smith family'),
        validator: _required,
      ),
      const SizedBox(height: PawSpace.xxl),
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pets', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: PawSpace.xxs),
                  Text(
                    'Add at least one pet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: pawMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: PawSpace.sm),
          OutlinedButton.icon(
            onPressed: _pets.length >= 20 ? null : _addPet,
            style: OutlinedButton.styleFrom(
              foregroundColor: pawPurpleInk,
              side: BorderSide(color: pawPurple.withValues(alpha: .28)),
              padding: const EdgeInsets.symmetric(horizontal: PawSpace.md),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add pet'),
          ),
        ],
      ),
      const SizedBox(height: PawSpace.md),
      ...List.generate(_pets.length, _petFields),
    ],
  );

  Widget _errorBanner(String error) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(PawSpace.md),
      decoration: BoxDecoration(
        color: pawRose.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(PawRadius.md),
        border: Border.all(color: pawRoseInk.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: pawRoseInk, size: 20),
          const SizedBox(width: PawSpace.sm),
          Expanded(
            child: Text(error, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    ),
  );

  Widget _fieldLabel(String label) =>
      Text(label, style: Theme.of(context).textTheme.titleSmall);

  InputDecoration _input(String hint) => InputDecoration(hintText: hint);

  InputDecoration _petInput(String hint) => _input(hint).copyWith(
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: PawSpace.md,
      vertical: PawSpace.md,
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  void _addPet() {
    setState(() {
      _pets.add(_PetEntry(id: 'pet-${_nextPetId++}'));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _removePet(int index) {
    if (_pets.length == 1) return;
    setState(() {
      final removed = _pets.removeAt(index);
      removed.dispose();
    });
  }

  Widget _petFields(int index) {
    final pet = _pets[index];
    return Container(
      key: ValueKey(pet.id),
      margin: const EdgeInsets.only(bottom: PawSpace.md),
      padding: const EdgeInsets.all(PawSpace.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(PawRadius.lg),
        border: Border.all(color: pawPurple.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pawLavender,
                  borderRadius: BorderRadius.circular(PawRadius.sm),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: pawPurpleDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: PawSpace.sm),
              Expanded(
                child: Text(
                  'Pet ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_pets.length > 1)
                IconButton(
                  tooltip: 'Remove pet ${index + 1}',
                  onPressed: () => _removePet(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: pawRoseInk,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PawSpace.sm),
          _miniLabel('Type'),
          const SizedBox(height: PawSpace.sm),
          FormField<PetSpecies>(
            key: ValueKey('species-${pet.id}'),
            initialValue: pet.species,
            validator: (species) => species == null ? 'Choose a type' : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PetSpecies.values
                        .map(
                          (species) => Padding(
                            padding: const EdgeInsets.only(right: PawSpace.sm),
                            child: _speciesOption(
                              pet: pet,
                              species: species,
                              selected: field.value == species,
                              onTap: () {
                                pet.species = species;
                                field.didChange(species);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (field.hasError) ...[
                  const SizedBox(height: PawSpace.sm),
                  Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PawSpace.lg),
          _miniLabel('Name'),
          const SizedBox(height: PawSpace.sm),
          TextFormField(
            controller: pet.name,
            textCapitalization: TextCapitalization.words,
            decoration: _petInput('Pet name'),
            validator: _required,
          ),
        ],
      ),
    );
  }

  Widget _speciesOption({
    required _PetEntry pet,
    required PetSpecies species,
    required bool selected,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: '${species.label} pet type',
    child: InkWell(
      key: ValueKey('pet-type-${pet.id}-${species.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(PawRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 68,
        constraints: const BoxConstraints(minHeight: pawMinTouch + 16),
        padding: const EdgeInsets.symmetric(
          horizontal: PawSpace.xs,
          vertical: PawSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? pawPurpleInk : Colors.white,
          borderRadius: BorderRadius.circular(PawRadius.md),
          border: Border.all(
            color: selected ? pawPurpleInk : pawPurple.withValues(alpha: .18),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: pawPurple.withValues(alpha: .18),
                    blurRadius: 9,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PetSpeciesIcon(
              species: species,
              color: selected ? Colors.white : pawPurpleDark,
              size: 24,
            ),
            const SizedBox(height: PawSpace.xs),
            Text(
              species.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : pawInk,
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _miniLabel(String label) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: pawMuted),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8067E2), pawPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(PawRadius.lg),
      boxShadow: [
        BoxShadow(
          color: pawPurple.withValues(alpha: .22),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: const Icon(Icons.pets_rounded, color: Colors.white, size: 24),
  );
}

class _PetEntry {
  _PetEntry({required this.id}) : name = TextEditingController();

  final String id;
  final TextEditingController name;
  PetSpecies? species;

  Pet toPet() => Pet(id: id, name: name.text.trim(), species: species!);

  void dispose() => name.dispose();
}
