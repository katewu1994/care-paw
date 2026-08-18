// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_paw/main.dart';
import 'package:care_paw/models/care_models.dart';
import 'package:care_paw/screens/add_task_sheet.dart';
import 'package:care_paw/screens/calendar_page.dart';
import 'package:care_paw/screens/pets_page.dart';
import 'package:care_paw/screens/profile_sheet.dart';
import 'package:care_paw/state/care_store.dart';
import 'package:care_paw/widgets/pet_species_icon.dart';
import 'package:care_paw/widgets/paw_ui.dart';
import 'package:care_paw/widgets/task_card.dart';

void main() {
  testWidgets(
    'calendar filters every view by pet and offers contextual recovery',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = CareStore();
      await store.createHousehold(
        householdName: 'Pet Club',
        pets: const [
          Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog),
          Pet(id: 'luna', name: 'Luna', species: PetSpecies.cat),
        ],
        caregiverName: 'Taylor',
      );
      final now = DateTime.now();
      await store.addTask(
        title: 'Mochi nail trim',
        category: CareCategory.grooming,
        kind: TaskKind.oneOff,
        priority: TaskPriority.normal,
        dueAt: DateTime(now.year, now.month, now.day, 15),
        weekdays: const {},
        petIds: const {'mochi'},
      );
      await store.addTask(
        title: 'Luna play session',
        category: CareCategory.play,
        kind: TaskKind.oneOff,
        priority: TaskPriority.normal,
        dueAt: DateTime(now.year, now.month, now.day, 16),
        weekdays: const {},
        petIds: const {'luna'},
      );
      final selectedDates = <DateTime>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              store: store,
              onSelectedDateChanged: selectedDates.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pet-filter-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-filter-mochi')), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-filter-luna')), findsOneWidget);
      expect(
        store.todayTasks.map((task) => task.title),
        containsAll(['Mochi nail trim', 'Luna play session']),
      );

      Future<void> reveal(Finder target, {bool forward = true}) async {
        for (var attempt = 0; attempt < 12; attempt++) {
          if (target.evaluate().isNotEmpty) {
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            return;
          }
          await tester.drag(
            find.byType(ListView),
            Offset(0, forward ? -300 : 300),
          );
          await tester.pumpAndSettle();
        }
        expect(target, findsWidgets);
      }

      final lunaFilter = find.byKey(const ValueKey('pet-filter-luna'));
      await tester.ensureVisible(lunaFilter);
      await tester.pumpAndSettle();
      await tester.tap(lunaFilter);
      await tester.pumpAndSettle();

      await reveal(find.text('Needs attention'));
      expect(find.text('Needs attention'), findsOneWidget);
      await reveal(find.text('Upcoming'));
      expect(find.text('Upcoming'), findsOneWidget);
      await reveal(find.text('Luna play session'));
      expect(find.text('Mochi nail trim'), findsNothing);
      expect(find.text('Luna play session'), findsOneWidget);

      final oneOffFilter = find.byKey(
        const ValueKey('schedule-filter-one-off'),
      );
      await reveal(oneOffFilter, forward: false);
      await tester.tap(oneOffFilter);
      await tester.pumpAndSettle();

      expect(find.text('Morning meal'), findsNothing);
      await reveal(find.text('Luna play session'));

      final nextMonth = find.byTooltip('Next month');
      await reveal(nextMonth, forward: false);
      await tester.tap(nextMonth);
      await tester.pumpAndSettle();

      final emptyState = find.text('No matching care');
      await reveal(emptyState);
      expect(emptyState, findsOneWidget);
      expect(find.textContaining('No one-time care for Luna'), findsOneWidget);

      final clearFilters = find.byKey(const ValueKey('clear-calendar-filters'));
      await tester.ensureVisible(clearFilters);
      await tester.tap(clearFilters);
      await tester.pumpAndSettle();

      expect(find.text('No matching care'), findsNothing);
      await reveal(find.text('Morning meal'));
      expect(find.text('Morning meal'), findsOneWidget);

      final todayButton = find.byKey(const ValueKey('calendar-today'));
      await reveal(todayButton, forward: false);
      await tester.tap(todayButton);
      await tester.pumpAndSettle();

      expect(selectedDates, isNotEmpty);
      expect(selectedDates.last, DateTime(now.year, now.month, now.day));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a task requires a date but can omit its time', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AddTaskSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    final optionalTime = find.byKey(const ValueKey('add-task-time'));
    final formScroll = find
        .descendant(
          of: find.byKey(const ValueKey('task-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(optionalTime, 300, scrollable: formScroll);
    expect(find.text('Date and optional time'), findsOneWidget);
    expect(find.text('Add time (optional)'), findsOneWidget);

    final today = DateTime.now();
    await store.addTask(
      title: 'Clean water bowl',
      category: CareCategory.feeding,
      kind: TaskKind.oneOff,
      priority: TaskPriority.normal,
      dueAt: DateTime(today.year, today.month, today.day, 18, 30),
      hasDueTime: false,
      weekdays: const {},
      petIds: const {'mochi'},
    );

    final task = store.todayTasks.firstWhere(
      (item) => item.title == 'Clean water bowl',
    );
    expect(task.hasDueTime, isFalse);
    expect(task.dueAt.hour, 0);
    expect(task.dueAt.minute, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(task: task, store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Any time'), findsOneWidget);
  });

  testWidgets('a new task can be assigned to a caregiver', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AddTaskSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    final formScroll = find
        .descendant(
          of: find.byKey(const ValueKey('task-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.tap(find.byKey(const ValueKey('task-pet-mochi')));

    final alex = find.byKey(const ValueKey('task-caregiver-alex'));
    await tester.scrollUntilVisible(alex, 250, scrollable: formScroll);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('task-caregiver-unassigned')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(alex);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(alex).selected, isTrue);

    final title = find.byKey(const ValueKey('task-title-field'));
    await tester.scrollUntilVisible(title, 300, scrollable: formScroll);
    await tester.enterText(title, 'Refill water bowl');

    final save = find.widgetWithText(FilledButton, 'Save task');
    await tester.scrollUntilVisible(save, 400, scrollable: formScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final task = store.todayTasks.firstWhere(
      (item) => item.title == 'Refill water bowl',
    );
    expect(task.status, TaskStatus.claimed);
    expect(task.assignee?.name, 'Alex');
  });

  testWidgets('supports common pet species with a distinct icon for each', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: PetSpecies.values
              .map(
                (species) => PetSpeciesIcon(species: species, color: pawPurple),
              )
              .toList(),
        ),
      ),
    );

    expect(PetSpecies.values, hasLength(13));
    expect(
      PetSpecies.values.map((species) => species.label),
      containsAll([
        'Hamster',
        'Guinea pig',
        'Ferret',
        'Turtle',
        'Amphibian',
        'Horse',
      ]),
    );
    expect(
      find.byType(PetSpeciesIcon),
      findsNWidgets(PetSpecies.values.length),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('care categories use icons and include common care types', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: CareCategory.values
                .map((category) => CategoryIcon(category: category))
                .toList(),
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNWidgets(CareCategory.values.length));
    expect(
      CareCategory.values.map((category) => category.label),
      containsAll(['Water', 'Playtime', 'Training', 'Toileting', 'Vet care']),
    );
    expect(find.text('🍽️'), findsNothing);
  });

  testWidgets('creates a local household and opens today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CarePawApp());
    await tester.pumpAndSettle();

    expect(find.text('Create your care home'), findsOneWidget);
    expect(find.text('Taylor'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Taylor');
    await tester.enterText(find.byType(TextFormField).at(1), 'Mochi Family');
    await tester.enterText(find.byType(TextFormField).at(2), 'Mochi');
    final species = find.byKey(const ValueKey('pet-type-pet-1-dog'));
    await tester.ensureVisible(species);
    await tester.pumpAndSettle();
    await tester.tap(species);
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, 'Create household');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Mochi'), findsWidgets);
    expect(find.text('Mochi · 4 care tasks left today.'), findsOneWidget);
    expect(find.text('CARE PULSE'), findsNothing);
    expect(find.text('Morning meal'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
    expect(find.text('Activity'), findsNothing);
    expect(find.byTooltip('Household profile'), findsOneWidget);
    expect(find.text('copaw Pro'), findsNothing);
    expect(find.text('I’ll do it'), findsNothing);

    await tester.tap(find.text('Morning meal'));
    await tester.pumpAndSettle();

    expect(find.text('I’ll do it'), findsOneWidget);
    expect(find.text('Or assign to'), findsOneWidget);
    expect(find.text('Anyone in the household'), findsOneWidget);
  });

  testWidgets('pets tab summarizes care and opens routine editing', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PetsPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your pets'), findsOneWidget);
    expect(find.byKey(const ValueKey('pet-card-mochi')), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text("Today's care"), findsOneWidget);
    expect(find.text('Routine care'), findsNothing);
    expect(
      find.byKey(const ValueKey('edit-routine-mochi-brush-coat')),
      findsNothing,
    );
    expect(find.text('Activity'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('pet-toggle-mochi')));
    await tester.pumpAndSettle();
    expect(find.text('Routine care'), findsOneWidget);

    final routineEdit = find.byKey(
      const ValueKey('edit-routine-mochi-brush-coat'),
    );
    await tester.ensureVisible(routineEdit);
    await tester.tap(routineEdit);
    await tester.pumpAndSettle();

    expect(find.text('Edit routine'), findsOneWidget);
    expect(
      find.text('Changes apply to every upcoming occurrence.'),
      findsOneWidget,
    );
    final formScroll = find
        .descendant(
          of: find.byKey(const ValueKey('task-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delete-routine-button')),
      500,
      scrollable: formScroll,
    );
    expect(find.text('Save routine'), findsOneWidget);
    expect(find.text('Delete routine'), findsOneWidget);
  });

  testWidgets('adds multiple named pet species during onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CarePawApp());
    await tester.pumpAndSettle();

    final addPetButton = find.text('Add pet');
    await tester.ensureVisible(addPetButton);
    await tester.tap(addPetButton);
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Taylor');
    await tester.enterText(find.byType(TextFormField).at(1), 'Pet Club');
    await tester.enterText(find.byType(TextFormField).at(2), 'Mochi');
    await tester.enterText(find.byType(TextFormField).at(3), 'Luna');
    final firstSpecies = find.byKey(const ValueKey('pet-type-pet-1-dog'));
    await tester.ensureVisible(firstSpecies);
    await tester.pumpAndSettle();
    await tester.tap(firstSpecies);
    await tester.pumpAndSettle();
    final secondSpecies = find.byKey(const ValueKey('pet-type-pet-2-cat'));
    await tester.ensureVisible(secondSpecies);
    await tester.pumpAndSettle();
    await tester.tap(secondSpecies);
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Create household');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Mochi'), findsWidgets);
    expect(find.text('Luna'), findsWidgets);
    expect(
      find.text('Mochi & Luna · 4 care tasks left today.'),
      findsOneWidget,
    );
    expect(find.text('CARE PULSE'), findsNothing);
  });

  testWidgets('previews an invitation before joining', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CarePawApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Jordan');
    await tester.enterText(find.byType(TextFormField).at(1), 'PAW123');
    await tester.tap(find.widgetWithText(FilledButton, 'Preview invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Check before requesting'), findsOneWidget);
    expect(find.text('Mochi Family'), findsOneWidget);
    expect(find.text('Invited by Alex'), findsOneWidget);

    final requestButton = find.widgetWithText(FilledButton, 'Request to join');
    await tester.ensureVisible(requestButton);
    await tester.pumpAndSettle();
    await tester.tap(requestButton);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
  });

  testWidgets('does not show Google account connection controls', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Google'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsNothing);
  });

  testWidgets('removes a reviewed join request from an open profile', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    store.joinRequests = [
      HouseholdJoinRequest(
        userId: 'yan',
        householdId: store.household!.id,
        invitationId: 'invite-1',
        name: 'Yan',
        createdAt: DateTime(2026, 8, 18),
        status: JoinRequestStatus.pending,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yan'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    store.joinRequests = const [];
    store.notifyListeners();
    await tester.pump();

    expect(find.text('Yan'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  test('local task handoff can be claimed and completed', () {
    final store = CareStore();
    store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    final meal = store.todayTasks.firstWhere(
      (task) => task.title == 'Morning meal',
    );
    expect(meal.status, TaskStatus.unclaimed);

    store.claim(meal);
    final claimed = store.todayTasks.firstWhere((task) => task.id == meal.id);
    expect(claimed.status, TaskStatus.claimed);
    expect(claimed.assignee?.name, 'Taylor');

    store.complete(claimed);
    final completed = store.todayTasks.firstWhere((task) => task.id == meal.id);
    expect(completed.status, TaskStatus.completed);
    expect(store.allCompletedTasks.map((task) => task.id), contains(meal.id));
  });

  testWidgets('unassigned task can be marked done directly from its card', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );

    final meal = store.todayTasks.firstWhere(
      (task) => task.title == 'Morning meal',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final currentTask = store.todayTasks.firstWhere(
                (task) => task.id == meal.id,
              );
              return TaskCard(task: currentTask, store: store);
            },
          ),
        ),
      ),
    );

    expect(find.text('Not claimed yet'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('complete-${meal.id}')));
    await tester.pumpAndSettle();

    final completed = store.todayTasks.firstWhere((task) => task.id == meal.id);
    expect(completed.status, TaskStatus.completed);
    expect(completed.assignee, isNull);
    expect(completed.completedBy?.name, 'Taylor');
    expect(find.textContaining('Done by Taylor'), findsOneWidget);
  });

  testWidgets('task card exposes edit and delete actions', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final original = store.todayTasks.firstWhere(
      (task) => task.kind == TaskKind.oneOff,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final currentTask = store.todayTasks.firstWhere(
                (task) => task.id == original.id,
              );
              return TaskCard(task: currentTask, store: store);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text(original.title));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Delete task'), findsOneWidget);

    final editAction = find.byKey(ValueKey('edit-${original.id}'));
    await tester.ensureVisible(editAction);
    await tester.tap(editAction);
    await tester.pumpAndSettle();
    expect(find.text('Edit care task'), findsOneWidget);

    final formScroll = find
        .descendant(
          of: find.byKey(const ValueKey('task-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final titleField = find.byKey(const ValueKey('task-title-field'));
    await tester.scrollUntilVisible(titleField, 400, scrollable: formScroll);
    await tester.enterText(titleField, 'Updated one-time task');
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      400,
      scrollable: formScroll,
    );
    final saveButton = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      store.todayTasks.firstWhere((task) => task.id == original.id).title,
      'Updated one-time task',
    );
    expect(find.text('Updated one-time task'), findsOneWidget);
  });

  testWidgets('routine task card only offers day-specific changes', (
    WidgetTester tester,
  ) async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final meal = store.todayTasks.firstWhere(
      (task) => task.title == 'Morning meal',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(task: meal, store: store),
        ),
      ),
    );
    await tester.tap(find.text('Morning meal'));
    await tester.pumpAndSettle();

    expect(find.text('Edit this day'), findsOneWidget);
    expect(find.text('Skip this day'), findsOneWidget);
    expect(find.text('Edit routine'), findsNothing);
    expect(find.text('Delete routine'), findsNothing);

    final skipAction = find.byKey(ValueKey('skip-${meal.id}'));
    await tester.ensureVisible(skipAction);
    await tester.pumpAndSettle();
    await tester.tap(skipAction);
    await tester.pumpAndSettle();
    expect(
      store.todayTasks.firstWhere((task) => task.id == meal.id).status,
      TaskStatus.skipped,
    );
  });

  test('recurring local task keeps its selected pet', () async {
    final store = CareStore();
    store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final today = DateTime.now();
    final dueAt = DateTime(today.year, today.month, today.day, 16);

    await store.addTask(
      title: 'Practice tricks',
      category: CareCategory.other,
      kind: TaskKind.routine,
      priority: TaskPriority.normal,
      dueAt: dueAt,
      weekdays: {today.weekday},
      petIds: {'mochi'},
    );

    final task = store
        .tasksOn(today)
        .firstWhere((task) => task.title == 'Practice tricks');
    expect(task.petIds, {'mochi'});
    final tomorrow = today.add(const Duration(days: 1));
    expect(
      store.tasksOn(tomorrow).any((task) => task.title == 'Practice tricks'),
      isFalse,
    );
  });

  test('recurring task keeps its selected caregiver', () async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final alex = store.caregivers.firstWhere((person) => person.name == 'Alex');
    final today = DateTime.now();

    await store.addTask(
      title: 'Evening medicine',
      category: CareCategory.medication,
      kind: TaskKind.routine,
      priority: TaskPriority.normal,
      dueAt: DateTime(today.year, today.month, today.day, 20),
      weekdays: {today.weekday},
      petIds: {'mochi'},
      assignee: alex,
    );

    final task = store.todayTasks.firstWhere(
      (item) => item.title == 'Evening medicine',
    );
    expect(task.status, TaskStatus.claimed);
    expect(task.assignee?.id, alex.id);
  });

  test(
    'editing one routine occurrence leaves the regular routine unchanged',
    () async {
      final store = CareStore();
      await store.createHousehold(
        householdName: 'Mochi Family',
        pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
        caregiverName: 'Taylor',
      );
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final todayMeal = store.todayTasks.firstWhere(
        (task) => task.title == 'Morning meal',
      );
      final routine = store.routineForTask(todayMeal)!;

      await store.updateTaskOccurrence(
        task: todayMeal,
        title: 'Late breakfast',
        category: CareCategory.feeding,
        priority: TaskPriority.normal,
        dueAt: DateTime(today.year, today.month, today.day, 9, 45),
        petIds: {'mochi'},
      );

      final editedToday = store.todayTasks.firstWhere(
        (task) => task.id == todayMeal.id,
      );
      final tomorrowMeal = store
          .tasksOn(tomorrow)
          .firstWhere((task) => task.routineId == routine.id);
      expect(editedToday.title, 'Late breakfast');
      expect(editedToday.dueAt.hour, 9);
      expect(editedToday.dueAt.minute, 45);
      expect(tomorrowMeal.title, 'Morning meal');
      expect(tomorrowMeal.dueAt.hour, 8);
      expect(routine.title, 'Morning meal');
      expect(routine.hour, 8);
    },
  );

  test(
    'skipping and restoring a routine affects only that occurrence',
    () async {
      final store = CareStore();
      await store.createHousehold(
        householdName: 'Mochi Family',
        pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
        caregiverName: 'Taylor',
      );
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final meal = store.todayTasks.firstWhere(
        (task) => task.title == 'Morning meal',
      );

      await store.skipTaskOccurrence(meal);
      final skipped = store.todayTasks.firstWhere((task) => task.id == meal.id);
      expect(skipped.status, TaskStatus.skipped);
      expect(
        store
            .tasksOn(tomorrow)
            .firstWhere((task) => task.routineId == meal.routineId)
            .status,
        TaskStatus.unclaimed,
      );

      await store.restoreTaskOccurrence(skipped);
      expect(
        store.todayTasks.firstWhere((task) => task.id == meal.id).status,
        TaskStatus.unclaimed,
      );
    },
  );

  test('local household keeps multiple pets and their species', () {
    final store = CareStore();
    store.createHousehold(
      householdName: 'Pet Club',
      pets: const [
        Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog),
        Pet(id: 'luna', name: 'Luna', species: PetSpecies.cat),
      ],
      caregiverName: 'Taylor',
    );

    expect(store.household?.pets, hasLength(2));
    expect(store.household?.petNames, 'Mochi, Luna');
    expect(store.household?.pets.last.species, PetSpecies.cat);
  });

  test('one-time task can target multiple pets', () async {
    final store = CareStore();
    store.createHousehold(
      householdName: 'Pet Club',
      pets: const [
        Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog),
        Pet(id: 'luna', name: 'Luna', species: PetSpecies.cat),
      ],
      caregiverName: 'Taylor',
    );
    final today = DateTime.now();

    await store.addTask(
      title: 'Vet visit',
      category: CareCategory.medication,
      kind: TaskKind.oneOff,
      priority: TaskPriority.normal,
      dueAt: DateTime(today.year, today.month, today.day, 15),
      weekdays: const {},
      petIds: {'mochi', 'luna'},
    );

    final task = store.todayTasks.firstWhere(
      (task) => task.title == 'Vet visit',
    );
    expect(task.petIds, {'mochi', 'luna'});
    expect(store.petsForTask(task).map((pet) => pet.name), ['Mochi', 'Luna']);
  });

  test('one-time task can be edited and deleted', () async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final today = DateTime.now();
    await store.addTask(
      title: 'Call the vet',
      category: CareCategory.vet,
      kind: TaskKind.oneOff,
      priority: TaskPriority.normal,
      dueAt: DateTime(today.year, today.month, today.day, 14),
      weekdays: const {},
      petIds: {'mochi'},
    );
    final original = store.todayTasks.firstWhere(
      (task) => task.title == 'Call the vet',
    );

    await store.updateTask(
      task: original,
      title: 'Confirm vet appointment',
      category: CareCategory.medication,
      priority: TaskPriority.urgent,
      dueAt: DateTime(today.year, today.month, today.day, 16, 30),
      weekdays: const {},
      petIds: {'mochi'},
    );

    final updated = store.todayTasks.firstWhere(
      (task) => task.id == original.id,
    );
    expect(updated.title, 'Confirm vet appointment');
    expect(updated.category, CareCategory.medication);
    expect(updated.priority, TaskPriority.urgent);
    expect(updated.dueAt.hour, 16);
    expect(updated.dueAt.minute, 30);

    await store.deleteTask(updated);
    expect(store.todayTasks.any((task) => task.id == original.id), isFalse);
  });

  test(
    'editing and deleting a routine applies to upcoming occurrences',
    () async {
      final store = CareStore();
      await store.createHousehold(
        householdName: 'Mochi Family',
        pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
        caregiverName: 'Taylor',
      );
      final today = DateTime.now();
      final original = store.todayTasks.firstWhere(
        (task) => task.title == 'Morning meal',
      );

      await store.updateTask(
        task: original,
        title: 'Morning breakfast',
        category: CareCategory.feeding,
        priority: TaskPriority.urgent,
        dueAt: DateTime(today.year, today.month, today.day, 9, 15),
        weekdays: {today.weekday},
        petIds: {'mochi'},
      );

      final updated = store.todayTasks.firstWhere(
        (task) => task.routineId == original.routineId,
      );
      expect(updated.title, 'Morning breakfast');
      expect(updated.priority, TaskPriority.urgent);
      expect(updated.dueAt.hour, 9);
      expect(updated.dueAt.minute, 15);
      expect(store.routineForTask(updated)?.weekdays, {today.weekday});

      await store.deleteTask(updated);
      expect(
        store.todayTasks.any((task) => task.routineId == original.routineId),
        isFalse,
      );
      expect(
        store.routines.any((routine) => routine.id == original.routineId),
        isFalse,
      );
    },
  );

  test('deleting a routine keeps its completed care history', () async {
    final store = CareStore();
    await store.createHousehold(
      householdName: 'Mochi Family',
      pets: const [Pet(id: 'mochi', name: 'Mochi', species: PetSpecies.dog)],
      caregiverName: 'Taylor',
    );
    final completed = store.todayTasks.firstWhere(
      (task) => task.title == 'Brush coat',
    );
    expect(completed.status, TaskStatus.completed);

    await store.deleteTask(completed);

    expect(store.todayTasks.any((task) => task.id == completed.id), isFalse);
    expect(
      store.allCompletedTasks.any((task) => task.id == completed.id),
      isTrue,
    );
  });
}
