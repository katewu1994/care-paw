import 'package:flutter/material.dart';

import '../state/care_store.dart';
import '../widgets/paw_ui.dart';
import 'add_task_sheet.dart';
import 'calendar_page.dart';
import 'pets_page.dart';
import 'profile_sheet.dart';
import 'today_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.store, super.key});

  final CareStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _calendarDate = DateTime.now();

  String get _title => switch (_index) {
    0 => 'Today',
    1 => 'Calendar',
    _ => 'Pets',
  };

  bool get _showsAddTask => _index <= 1;

  void _addTask() => showAddTaskSheet(
    context,
    widget.store,
    initialDate: _index == 1 ? _calendarDate : null,
  );

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: PawSpace.sm),
              child: IconButton(
                tooltip: 'Household profile',
                onPressed: () => showProfileSheet(context, widget.store),
                icon: const Icon(Icons.account_circle_rounded, size: 28),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            TodayPage(store: widget.store),
            CalendarPage(
              store: widget.store,
              onSelectedDateChanged: (date) => _calendarDate = date,
            ),
            PetsPage(store: widget.store),
          ],
        ),
        floatingActionButton: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _showsAddTask
              ? FloatingActionButton.extended(
                  key: const ValueKey('add-task-button'),
                  heroTag: 'add-task',
                  tooltip: 'Add task',
                  onPressed: _addTask,
                  backgroundColor: pawPurple,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Add task',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no-add-task-button')),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist_rounded),
              label: 'Today',
              tooltip: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
              tooltip: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets_rounded),
              label: 'Pets',
              tooltip: 'Pets',
            ),
          ],
        ),
      ),
    );
  }
}
