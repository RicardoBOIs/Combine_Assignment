import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

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

// Imports for Bottom Navigation Bar destinations
import '../Community/community_main.dart'; // For CommunityChallengesScreen
import 'package:assignment_test/YenHan/pages/tips_education.dart'; // For TipsEducationScreen
import '../screen/profile.dart'; // For ProfilePage
import 'package:assignment_test/Community/community_database_service.dart';

class TrackHabitScreen extends StatefulWidget {
  const TrackHabitScreen({Key? key}) : super(key: key);

  @override
  State<TrackHabitScreen> createState() => _TrackHabitScreenState();
}

class _TrackHabitScreenState extends State<TrackHabitScreen> {
  final _db = DatabaseService();
  late String user_email;   //sample user email
  final HabitsRepository _repo = SqfliteHabitsRepository();
  late List<Habit> _habits=[];
  late final ScrollController _scrollController;

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

  int _selectedIndex = 1; // New state variable for the current tab index (1 for Track Habit)

  bool _hasChanged = false; // NEW: Flag to indicate if any habit data has changed

  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final currentUser = FirebaseAuth.instance.currentUser;
    user_email = currentUser?.email ?? 'unknown@example.com';
    if (user_email == 'unknown@example.com') { // Use 'unknown@example.com' for check
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in to access Habit Tracking.')),
        );
      });
      return;
    }

    _selectedMonthlyEndDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    Future<void> _initHabits() async {
      final _uuid = const Uuid();
      final saved = await _repo.fetchHabits(user_email);
      if (saved.isEmpty) {
        // first run: seed defaults and persist them
        _habits = [
          Habit(id: _uuid.v4(),title: 'Reduce Plastic', unit: 'kg', goal: 1, currentValue: 0, quickAdds: const []),
          Habit(id: _uuid.v4(),title: 'Short Walk',    unit: 'steps', goal: 10000, currentValue: 0, quickAdds: const [], usePedometer: true),
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
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SQLite helper – read the latest Short‑Walk total for today
  // ---------------------------------------------------------------------------
  Future<void> _initSavedTotal() async {
    _runningTotal = await _db.getLastSavedSteps() ?? 0;
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

      final last7 = await SqfliteStepsRepository().fetchAllSteps(user_email);
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
    // Ensure _selectedHabitTitle is not null before calling _loadDataForSelectedHabit
    if (_habits.isNotEmpty && _selectedHabitTitle == null) {
      _selectedHabitTitle = _habits.first.title;
    }
    if (_selectedHabitTitle != null) {
      await _loadDataForSelectedHabit(_selectedHabitTitle!);
    } else {
      // If no habits, clear chart data
      setState(() {
        _last7Labels = [];
        _last7Values = [];
        _monthlyLabels = [];
        _monthlyValues = [];
      });
    }
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
    final isStep = _habits.firstWhere(
          (h) => h.title == habitTitle,
      orElse: () => Habit(
        id: '',
        title: '',
        unit: '',
        goal: 0,
        currentValue: 0,
        quickAdds: [],
      ),
    ).usePedometer;

    if (isStep) {
      // 1. 拉取所有步数
      final all = await SqfliteStepsRepository().fetchAllSteps(user_email);
      final fmt = DateFormat('yyyy-MM-dd');
      final daily = <String, double>{};

      if (all.isEmpty) {
        // 如果还没任何记录，就今天一条 0
        daily[fmt.format(DateTime.now())] = 0.0;
      } else {
        // 按日期升序找到第一天和今天
        all.sort((a, b) => a.day.compareTo(b.day));
        final first = all.first.day;
        final today = DateTime.now();

        // 2. 生成从 first 到 today 的每一天，初始值 0
        for (var d = first;
        !d.isAfter(today);
        d = d.add(const Duration(days: 1))) {
          daily[fmt.format(d)] = 0.0;
        }

        // 3. 用最新 count 覆盖
        for (final e in all) {
          final key = fmt.format(e.day);
          if (daily.containsKey(key)) {
            daily[key] = max(daily[key]!, e.count);
          }
        }
      }

      // 4. 更新 state，并自动滚到最右（“今天”）
      setState(() {
        _last7Labels = daily.keys.toList();
        _last7Values = daily.values.toList();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });

      // 最后再调月度统计
      final stepMonths = await SqfliteStepsRepository().fetchMonthlyTotals(user_email);
      _monthlyTotals = stepMonths.map((e) => HabitEntry(
        id        : e.id,
        user_email: e.user_email,
        habitTitle: habitTitle,
        date      : e.day,
        value     : e.count,
        createdAt : e.createdAt,
        updatedAt : e.updatedAt,
      )).toList();
      _prepareMonthlyChart();
      return;
    }

    // ── Else: existing ‘entries’ logic
    final entries = await _repo.fetchAllEntries(user_email, habitTitle);
    final fmt = DateFormat('yyyy-MM-dd');
    final daily = <String, double>{};

    if (entries.isEmpty) {
      daily[fmt.format(DateTime.now())] = 0.0;
    } else {
      entries.sort((a, b) => a.date.compareTo(b.date));
      final first = entries.first.date;
      final today = DateTime.now();

      for (var d = first;
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))) {
        daily[fmt.format(d)] = 0.0;
      }

      for (final e in entries) {
        final key = fmt.format(e.date);
        if (daily.containsKey(key)) {
          daily[key] = max(
            daily[key]!,
            e.value,
          );
        }
      }
    }

    setState(() {
      _last7Labels = daily.keys.toList();
      _last7Values = daily.values.toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });


    final monthly = await _repo.fetchMonthlyTotals(user_email, habitTitle);
    setState(() {
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
    setState(() { // NEW: Set flag on deletion
      _hasChanged = true;
    });
  }

  Future<void> _deleteHabitAndData(String title, int index) async {
    await _db.deleteAllEntriesForHabit(title);
    await SyncService().deleteEntriesForHabit(title);
    await _repo.deleteHabit(user_email, title);
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
    final unitCtrl  = TextEditingController(text: 'kg');
    final goalCtrl  = TextEditingController(text: '5');

    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

    // ── If user confirmed and title is not empty ──────────────────────────────
    if (added == true && titleCtrl.text.trim().isNotEmpty) {
      final newHabit = Habit(
        id        : const Uuid().v4(),
        title       : titleCtrl.text.trim(),
        unit        : unitCtrl.text.trim(),
        goal        : double.tryParse(goalCtrl.text) ?? 0,
        currentValue: 0,
        quickAdds   : const [],
      );

      // 1. persist to SQLite (will replace if the title already exists)
      await _repo.upsertHabit(newHabit, user_email);

      // 2. reload lists & charts exactly once → UI refreshed, no duplicates
      setState(() {
        _habits.add(newHabit);
        _hasChanged = true; // NEW: Set flag on addition
      });

      await _loadAllData();
    }
  }

  // ---------------------------------------------------------------------------
  // Bottom Navigation Bar Tap Handler
  // ---------------------------------------------------------------------------
  void _onItemTapped(int index) async { // Make async to use await for Navigator.pushReplacement
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) { // Home tab tapped
      Navigator.pop(context, _hasChanged); // Pass _hasChanged flag to HomePage
    } else if (index == 1) {
      // Already on Track Habit screen, do nothing or refresh
      _loadAllData(); // Optional: refresh data if user taps current tab
    } else if (index == 2) { // Community tab
      final result = await Navigator.pushReplacement( // Use pushReplacement for bottom nav
        context,
        MaterialPageRoute(builder: (context) => const CommunityChallengesScreen()),
      );
      // Handle result if CommunityChallengesScreen also returns true/false
      if (result == true) {
        setState(() {
          _hasChanged = true; // If a change happened in community, propagate flag
        });
      }
    } else if (index == 3) { // Tips & Learning tab
      final result = await Navigator.pushReplacement( // Use pushReplacement for bottom nav
        context,
        MaterialPageRoute(builder: (context) => TipsEducationScreen()),
      );
      // Handle result if TipsEducationScreen also returns true/false
      if (result == true) {
        setState(() {
          _hasChanged = true; // If a change happened in tips, propagate flag
        });
      }
    } else if (index == 4) { // Profile tab
      final result = await Navigator.pushReplacement( // Use pushReplacement for bottom nav
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
      // Handle result if ProfilePage also returns true/false
      if (result == true) {
        setState(() {
          _hasChanged = true; // If a change happened in profile, propagate flag
        });
      }
    }
  }

  Widget _buildMotivationalCard(int steps) {
    String message;
    if (steps >= 10000) {
      message = 'You have walked $steps steps today! Goal achieved, great! 🎉';
    } else if (steps >= 5000) {
      message = 'Keep going! You have walked $steps steps, keep up the good work! 🚶‍';
    } else {
      message = 'You haven\'t moved much today, it\'s healthier to move~ You have walked $steps steps. 👀';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/track_habit.jpg',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.directions_walk, size: 32, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                Text( 'Habit Progress', style: theme.textTheme.titleLarge),
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
            SizedBox(
              height: 120,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _last7Values.length * 45.0, // Adjust width based on number of values
                  child: InteractiveTrendChart(
                    values: _last7Values,
                    labels: _last7Labels,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Monthly Totals (Last 12 months)',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            MonthlyBarChart(
              labels: _monthlyLabels,
              values: _monthlyValues,
            ),
            _buildMotivationalCard(_runningTotal)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        child: const Icon(Icons.add, size: 32.0),
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
                            setState(() {
                              _habits[index] = updated;
                              _hasChanged = true; // NEW: Set flag on habit edit
                            });
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