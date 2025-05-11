import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../attr/habit.dart';
import '../attr/habit_entry.dart';
import '../db/habits_repository.dart';
import '../db/sqflite_habits_repository.dart';
import '../db/db_helper.dart';
import '../db/sync_service.dart';
import 'interactive_trend_chart.dart';
import 'edit_habit_screen.dart';
import '../attr/step_entry.dart';
import '../db/sqflite_steps_repository.dart';
import 'monthly_bar_chart.dart';
import '../screen/home.dart'; // Import your home.dart for navigation

class TrackHabitScreen extends StatefulWidget {
  const TrackHabitScreen({Key? key}) : super(key: key);

  @override
  State<TrackHabitScreen> createState() => _TrackHabitScreenState();
}

class _TrackHabitScreenState extends State<TrackHabitScreen> {
  late String user_email;   //sample user email
  final HabitsRepository _repo = SqfliteHabitsRepository();
  late List<Habit> _habits=[];

  DateTime _selectedDate = DateTime.now();
  String? _selectedHabitTitle;

  // chart / table data
  List<String> _last7Labels = [];
  List<double> _last7Values = [];
  List<HabitEntry> _monthlyTotals = [];

  // Which month to end on (first day of month)
  late final DateTime _selectedMonthlyEndDate;

  // Labels and values for the bar chart
  List<String> _monthlyLabels = [];
  List<double> _monthlyValues = [];

  // pedometer
  StreamSubscription<StepCount>? _stepSub;
  int? _sensorPrev; // last raw StepCount from sensor
  int _runningTotal = 0; // what we show & store
  int? _lastSavedSteps; // last value written to DB

  // Add these two new members here:
  int _selectedIndex = 1; // New state variable for the current tab index (1 for Track Habit)
  // ...

  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    user_email = currentUser?.email ?? 'unknown@example.com';
    if (user_email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      Navigator.of(context).pop();
      return;
    }

    _selectedMonthlyEndDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    Future<void> _initHabits() async {
      final saved = await _repo.fetchHabits(user_email);
      if (saved.isEmpty) {
        // first run: seed defaults and persist them
        _habits = [
          Habit(title: 'Reduce Plastic', unit: 'kg', goal: 1, currentValue: 0, quickAdds: const []),
          Habit(title: 'Short Walk',    unit: 'steps', goal: 10000, currentValue: 0, quickAdds: const [], usePedometer: true),
        ];
        for (var h in _habits) {
          await _repo.upsertHabit(h, user_email);
        }
      } else {
        _habits = saved;
      }
      // now continue with your existing sync, permission and data-loading calls…
      SyncService().start();
      await _initSavedTotal();
      _requestPermission();
      _startPedometer();
      await _loadAllData();
    }
    _initHabits();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SQLite helper – read the latest Short‑Walk total for today
  // ---------------------------------------------------------------------------
  Future<void> _initSavedTotal() async {
    _runningTotal = await DbHelper().getLastSavedSteps() ?? 0;
    _lastSavedSteps = _runningTotal;
  }

  // ---------------------------------------------------------------------------
  // PERMISSION
  // ---------------------------------------------------------------------------
  Future<void> _requestPermission() async {
    final st = await Permission.activityRecognition.request();
    if (!st.isGranted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Motion permission denied')));
    }
  }

  // ---------------------------------------------------------------------------
  // PEDOMETER LISTENER
  // ---------------------------------------------------------------------------
  void _startPedometer() {
    final stepIdx = _habits.indexWhere((h) => h.usePedometer);
    if (stepIdx == -1) return;

    _stepSub = Pedometer.stepCountStream.listen((event) async {
      final today = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      // ── A.  first event after launch → just remember raw value
      if (_sensorPrev == null) {
        _sensorPrev = event.steps;
        return;
      }

      // ── B.  delta = currentRaw – prevRaw  (sensor may reset to 0)
      int delta = event.steps - _sensorPrev!;
      if (delta < 0) delta = event.steps; // handle sensor reset
      _sensorPrev = event.steps;

      // ── C.  accumulate and update UI
      _runningTotal += delta;

      setState(() {
        final h = _habits[stepIdx];
        _habits[stepIdx] = h.copyWith(currentValue: _runningTotal.toDouble());
      });

      final todayId = DateFormat('yyyy-MM-dd').format(today);

      final stepEntry = StepEntry(
        id: todayId,
        user_email: user_email,
        day: today,
        count: _runningTotal.toDouble(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await SqfliteStepsRepository().upsert(stepEntry);

      final last7 = await SqfliteStepsRepository().fetchLast7Days(user_email);
      setState(() {
        _last7Labels =
            last7.map((e) => DateFormat('yyyy-MM-dd').format(e.day)).toList();
        _last7Values = last7.map((e) => e.count).toList();
      });
    });
  }

  // ---------------------------------------------------------------------------
  // DATA LOADERS
  // ---------------------------------------------------------------------------
  Future<void> _loadAllData() async {
    await _updateCurrentValues();
    await _loadDataForSelectedHabit(_selectedHabitTitle!);
  }

  Future<void> _updateCurrentValues() async {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    for (var i = 0; i < _habits.length; i++) {
      final h = _habits[i];
      if (h.usePedometer) continue; // live updated

      final entries = await _repo.fetchRange(user_email, h.title, _selectedDate);
      final todayEntries = entries.where(
            (e) => DateFormat('yyyy-MM-dd').format(e.date) == key,
      );
      final todayTotal =
      todayEntries.isEmpty
          ? 0.0
          : todayEntries
          .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b)
          .value;
      setState(() => _habits[i] = h.copyWith(currentValue: todayTotal));
    }
  }

  Future<void> _loadDataForSelectedHabit(String habitTitle) async {
    // final isStep =
    //     _habits.firstWhere((h) => h.title == habitTitle).usePedometer;
    final isStep = _habits.firstWhere(
          (h) => h.title == habitTitle,
      orElse: () => Habit(
        title: '',
        unit: '',
        goal: 0,
        currentValue: 0,
        quickAdds: [],
      ),
    ).usePedometer;

    if (isStep) {
      _selectedDate = DateTime.now();

      final last7 = await SqfliteStepsRepository().fetchLast7Days(user_email);
      final labels =
      last7.map((e) => DateFormat('yyyy-MM-dd').format(e.day)).toList();
      final values = last7.map((e) => e.count).toList();

      final stepMonths = await SqfliteStepsRepository().fetchMonthlyTotals(user_email);
      _monthlyTotals =
          stepMonths
              .map(
                (e) => HabitEntry(
              id: e.id,
              user_email: e.user_email,
              habitTitle: habitTitle,
              date: e.day,
              value: e.count,
              createdAt: e.createdAt,
              updatedAt: e.updatedAt,
            ),
          )
              .toList();
      _prepareMonthlyChart();

      setState(() {
        _last7Labels = labels;
        _last7Values = values;
        _monthlyTotals = _monthlyTotals;
      });
      return;
    }

    // ── Else: existing ‘entries’ logic
    final entries = await _repo.fetchRange(user_email, habitTitle, _selectedDate);
    final fmt = DateFormat('yyyy-MM-dd');
    final daily = <String, double>{};

    // init last 7 calendar days
    for (var i = 0; i < 7; i++) {
      final d = _selectedDate.subtract(Duration(days: 6 - i));
      daily[fmt.format(d)] = 0.0;
    }
    // sum up the latest-per-day (your existing fix)
    final latestPerDay = <String, HabitEntry>{};
    for (final e in entries) {
      final k = fmt.format(e.date);
      if (!latestPerDay.containsKey(k) ||
          e.updatedAt.isAfter(latestPerDay[k]!.updatedAt)) {
        latestPerDay[k] = e;
      }
    }
    latestPerDay.forEach((k, e) => daily[k] = e.value);

    final monthly = await _repo.fetchMonthlyTotals(user_email, habitTitle);
    setState(() {
      _last7Labels = daily.keys.toList();
      _last7Values = daily.values.toList();
      _monthlyTotals = monthly;
    });
    _prepareMonthlyChart();
  }

  void _prepareMonthlyChart() {
    // Build a list of 13 months ending at _selectedMonthlyEndDate
    final end = DateTime(_selectedMonthlyEndDate.year, _selectedMonthlyEndDate.month, 1);
    final window = <DateTime>[];
    for (int i = 12; i >= 0; i--) {
      window.add(DateTime(end.year, end.month - i, 1));
    }

    // Month labels like "May 24", "Jun 24", …, "May 25"
    final labels = window
        .map((dt) => DateFormat('MMM yy').format(dt))
        .toList();

    // Match against your raw _monthlyTotals (List<HabitEntry>)
    final values = window.map((dt) {
      final match = _monthlyTotals.firstWhere(
            (e) => e.date.year == dt.year && e.date.month == dt.month,
        orElse: () => HabitEntry(
          id: '',
          user_email: user_email,
          habitTitle: _selectedHabitTitle!,
          date: dt,
          value: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return match.value;
    }).toList();

    setState(() {
      _monthlyLabels = labels;
      _monthlyValues = values;
    });
  }


  // ---------------------------------------------------------------------------
  // DELETE HABITS
  // ---------------------------------------------------------------------------
  Future<void> _confirmDelete(BuildContext ctx, int index, String title) async {
    final sure = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete “$title”? '
            'All its data will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (sure != true) return;

    // 3. Remove from database and UI:
    await _deleteHabitAndData(title, index);
  }

  Future<void> _deleteHabitAndData(String title, int index) async {
    // 3a. Remove all local entries for that habit:
    await DbHelper().deleteAllEntriesForHabit(title);
    // 3b. Remove from Firestore:
    await SyncService().deleteEntriesForHabit(title);
    // 3c. Update your in-memory list and refresh the charts:
    setState(() {
      _habits.removeAt(index);
    });
    await _loadAllData();
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _updateCurrentValues();
      await _loadDataForSelectedHabit(_selectedHabitTitle!);
    }
  }

  Future<void> _showAddHabitDialog() async {
    final titleCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');
    final goalCtrl = TextEditingController(text: '5');

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
        title: const Text('Create Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(labelText: 'Goal'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      setState(() {
        _habits.add(
          Habit(
            title: titleCtrl.text.trim(),
            unit: unitCtrl.text.trim(),
            goal: double.tryParse(goalCtrl.text) ?? 0,
            currentValue: 0,
            quickAdds: const [],
          ),
        );
      });
    }
  }

  Future<void> _clearAll() async {
    await DbHelper().deleteAllEntries();
    await _loadAllData();
  }

  // ---------------------------------------------------------------------------
  // Bottom Navigation Bar Tap Handler
  // ---------------------------------------------------------------------------
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) { // Home tab tapped
      Navigator.pop(context); // Assumes TrackHabitScreen was pushed from HomePage
    } else if (index == 1) {
      // Already on Track Habit screen, do nothing or refresh
      _loadAllData(); // Optional: refresh data if user taps current tab
    }
    // You can add navigation logic for other tabs (e.g., Community, Tips & Learning) here
  }


  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // backgroundColor: Colors.lightGreen.shade100,
      appBar: AppBar(
        title: const Text('Habit Tracking'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First show only the Short Walk card
            if (_habits.any((h) => h.usePedometer)) ...[
              _buildHabitCard(_habits.indexWhere((h) => h.usePedometer), theme),
              const SizedBox(height: 16),
            ],

            // Then show all the other habits
            for (var i = 0; i < _habits.length; i++)
              if (!_habits[i].usePedometer) ...[
                // only before Reduce Plastic insert our date + icon row
                if (_habits[i].title == 'Reduce Plastic') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // now the actual Reduce Plastic card (or any other habit)
                _buildHabitCard(i, theme),
                const SizedBox(height: 16),
              ],

            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text( '7 days habits', style: theme.textTheme.titleLarge),
                DropdownButton<String>(
                  value: _selectedHabitTitle,
                  items:
                  _habits
                      .map(
                        (h) => DropdownMenuItem(
                      value: h.title,
                      child: Text(h.title),
                    ),
                  )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedHabitTitle = v);
                      _loadDataForSelectedHabit(v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            InteractiveTrendChart(
              values: _last7Values,
              labels: _last7Labels,
            ),
            const SizedBox(height: 24),
            Text('Monthly Totals (Last 12 months)',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            MonthlyBarChart(
              labels: _monthlyLabels,
              values: _monthlyValues,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: 'New Habit',
        onPressed: _showAddHabitDialog,
      ),
      // Add the Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes), // Example icon for Track Habit
            label: 'Track Habit',
          ),
          BottomNavigationBarItem( // Assuming these tabs exist in your design
            icon: Icon(Icons.group),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Tips & Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex, // Set the current selected index
        selectedItemColor: Colors.green, // Highlight color for selected item
        unselectedItemColor: Colors.grey, // Unselected item color
        showUnselectedLabels: true, // Always show labels
        type: BottomNavigationBarType.fixed, // Ensures tabs are evenly spaced
        onTap: _onItemTapped, // Handle tap events
      ),
    );

  }

  // ---------------------------------------------------------------------------
  Widget _buildHabitCard(int index, ThemeData theme) {
    final h = _habits[index];
    final progress =
    h.goal == 0 ? 0.0 : (h.currentValue / h.goal).clamp(0.0, 1.0);

    return Card(
      color:
      h.usePedometer
          ? Colors.lightGreen.shade400
          : Colors.green.shade300,
      // Differentiate color
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(h.title, style: theme.textTheme.titleMedium),
                if (!h
                    .usePedometer) // Do not display edit button for Short Walk
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final todayEntries = await _repo.fetchRange(
                            user_email,
                            h.title,
                            _selectedDate,
                          );
                          final key = DateFormat(
                            'yyyy-MM-dd',
                          ).format(_selectedDate);

                          HabitEntry? existing;
                          try {
                            existing = todayEntries.firstWhere(
                                  (e) => DateFormat('yyyy-MM-dd').format(e.date) == key,
                            );
                          } catch (_) {
                            existing = null;
                          }

                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EditHabitScreen(
                                habit: h,
                                existingEntry: existing,
                                initialDate: _selectedDate,
                              ),
                            ),
                          );
                          if (result != null) {
                            final updated = result['habit'] as Habit;
                            final entry = result['entry'] as HabitEntry?;
                            if (entry != null) {
                              await _repo.deleteDay(entry.habitTitle, entry.date);
                              await _repo.upsertEntry(entry);
                              await SyncService().pushEntry(entry);
                            }
                            await _repo.upsertHabit(updated, user_email);
                            setState(() => _habits[index] = updated);
                            await _loadAllData();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Habit',
                        onPressed: () => _confirmDelete(context, index, h.title),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              h.usePedometer
                  ? '${h.currentValue.toInt()}/${h.goal.toInt()} ${h.unit}' // integer for Short Walk
                  : '${h.currentValue.toStringAsFixed(2)}/${h.goal} ${h.unit}', // double for normal habits
            ),
            // For the Short Walk, show the date at the bottom of its card
            if (h.usePedometer) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}