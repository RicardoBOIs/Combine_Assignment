import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For DateFormat
import 'dart:io'; // For File.existsSync() for image paths

// Adjust paths if your file structure is different.
import '../../attr/habit.dart'; // The Habit model used by track_habit_screen
import '../../attr/habit_entry.dart'; // The HabitEntry model (for chart data processing)
import '../../attr/step_entry.dart'; // The StepEntry model for pedometer data
import '../../db/habits_repository.dart';
import 'package:uuid/uuid.dart';
import '../../db/sqflite_habits_repository.dart';
import '../../db/sqflite_steps_repository.dart'; // For fetching step data for charts
import '../../screen/interactive_trend_chart.dart'; // The chart widget
import '../../screen/monthly_bar_chart.dart'; // The chart widget
import '../../screen/track_habit_screen.dart'; // For navigation to the dedicated habit tracking screen
import '../../screen/edit_habit_screen.dart'; // <--- Import EditHabitScreen for the FAB

// Assuming you have this page for check-ins based on previous context
import '../screen/check_in_page.dart';
import 'package:assignment_test/YenHan/pages/tips_education.dart';

// Community Module Imports
import '../../Willie/community_main.dart'; // For CommunityChallengesScreen and EventDetailScreen
import '../../Willie/community_main_model.dart'; // For CommunityMain model
import '../../Willie/community_repository_service.dart'; // For fetching community data
import '../../Willie/join_event_model.dart'; // For checking join status
import '../../Willie/community_leaderboard.dart'; // Optional: If you want to link directly to a leaderboard from here

import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth.instance.currentUser

// NEW: Import your ProfilePage
import '../screen/profile.dart'; // <--- Adjust path if profile.dart is in a different location


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HabitsRepository _habitsRepo = SqfliteHabitsRepository();
  final RepositoryService _communityRepo = RepositoryService.instance; // Instance for community data
  List<Habit> _habits = []; // List of all tracked habits
  String _selectedHabitForCharts = '-'; // Currently selected habit for trend/monthly charts
  DateTime _selectedDateForHabitsOverview = DateTime.now(); // Date for displaying habit current values

  // Chart data
  List<String> _last7Labels = [];
  List<double> _last7Values = [];
  List<HabitEntry> _monthlyTotalsForCharts = []; // Used to prepare monthly chart data
  List<String> _monthlyLabelsForCharts = [];
  List<double> _monthlyValuesForCharts = [];

  // Placeholder data for challenges (kept if you want to show generic challenges too)
  final List<Map<String, String>> _currentChallenges = [
    {
      'id': 'daily_eco_check_in',
      'name': 'Daily check-in',
      'description': 'Check-in for planting your own tree',
      'image': 'assets/planting.jpg', // Ensure this asset exists in your pubspec.yaml
    },
  ];

  // User email for data fetching - now guaranteed to be non-null
  late String _userEmail;
  // FIX: Initialize _futureJoinedCommunityEvents synchronously in initState
  late Future<List<CommunityMain>> _futureJoinedCommunityEvents;

  @override
  void initState() {
    super.initState();
    // This line ensures _futureJoinedCommunityEvents is initialized immediately.
    _futureJoinedCommunityEvents = Future.value([]); // Initialize with an empty list Future.

    _initializeUserAndLoadData(); // This will later assign the actual data-fetching future.
  }

  Future<void> _initializeUserAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    assert(user != null && user.email != null, 'User must be logged in and have an email before accessing HomePage.');

    _userEmail = user!.email!; // Assign the user's email

    // Assign the actual future for community events here within setState.
    // This causes the FutureBuilder to rebuild when the actual data fetching Future completes.
    setState(() {
      _futureJoinedCommunityEvents = _loadJoinedCommunityEvents(_userEmail);
    });

    // Keep loading other habit data asynchronously
    await _loadAllHabitsAndChartData();
  }

  Future<void> _loadAllHabitsAndChartData() async {
    // _userEmail is guaranteed non-null here due to _initializeUserAndLoadData
    final fetchedHabits = await _habitsRepo.fetchHabits(_userEmail);
    setState(() {
      _habits = fetchedHabits;
      if (_habits.isNotEmpty) {
        _selectedHabitForCharts = _habits.first.title;
      } else {
        _selectedHabitForCharts = '-'; // No habits to select
      }
    });
    await _updateAllHabitCurrentValues();
    if (_habits.isNotEmpty && _selectedHabitForCharts != '-') {
      await _loadChartDataForSelectedHabit(_selectedHabitForCharts);
    } else {
      setState(() {
        _last7Labels = [];
        _last7Values = [];
        _monthlyLabelsForCharts = [];
        _monthlyValuesForCharts = [];
      });
    }
  }

  // New method to load joined community events
  Future<List<CommunityMain>> _loadJoinedCommunityEvents(String email) async {
    final joins = await _communityRepo.getJoinsForUser(email);
    final joinedEventIds = joins
        .where((j) => j.status == 'joined')
        .map((j) => j.communityID)
        .toSet();

    if (joinedEventIds.isEmpty) {
      return [];
    }

    // This will try Firestore first, then fallback to SQLite
    final allCommunities = await _communityRepo.getCommunities();
    return allCommunities.where((c) => joinedEventIds.contains(c.id)).toList();
  }


  // Fetches and updates the currentValue for all habits based on _selectedDateForHabitsOverview
  Future<void> _updateAllHabitCurrentValues() async {
    // _userEmail is guaranteed non-null here
    final key = DateFormat('yyyy-MM-dd').format(_selectedDateForHabitsOverview);
    for (var i = 0; i < _habits.length; i++) {
      final h = _habits[i];
      if (h.usePedometer) {
        // For pedometer habits, fetch the specific day's step count
        final stepsRepo = SqfliteStepsRepository();
        final last7StepEntries = await stepsRepo.fetchLast7Days(_userEmail);
        final stepsForSelectedDate = last7StepEntries.firstWhere(
              (entry) => DateFormat('yyyy-MM-dd').format(entry.day) == key,
          orElse: () => StepEntry(
            id: const Uuid().v4(), // Generate a new UUID for placeholder
            user_email: _userEmail,
            day: _selectedDateForHabitsOverview,
            count: 0.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        setState(() => _habits[i] = h.copyWith(currentValue: stepsForSelectedDate.count));
        continue;
      }

      // For non-pedometer habits, fetch the latest entry for the selected date
      final entries = await _habitsRepo.fetchRange(_userEmail, h.title, _selectedDateForHabitsOverview);
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

  // Loads data for the InteractiveTrendChart and MonthlyBarChart for the selected habit
  Future<void> _loadChartDataForSelectedHabit(String habitTitle) async {
    // _userEmail is guaranteed non-null here
    if (_habits.isEmpty) {
      setState(() {
        _last7Labels = [];
        _last7Values = [];
        _monthlyLabelsForCharts = [];
        _monthlyValuesForCharts = [];
      });
      return;
    }

    final selectedHabit = _habits.firstWhere((h) => h.title == habitTitle,
        orElse: () => _habits.first); // Fallback to first habit if not found
    final isStep = selectedHabit.usePedometer;

    if (isStep) {
      final stepsRepo = SqfliteStepsRepository();
      final last7 = await stepsRepo.fetchAllSteps(_userEmail);
      final labels = last7.map((e) => DateFormat('yyyy-MM-dd').format(e.day)).toList();
      final values = last7.map((e) => e.count).toList();

      final stepMonths = await stepsRepo.fetchMonthlyTotals(_userEmail);
      _monthlyTotalsForCharts = stepMonths.map((e) => HabitEntry(
        id: const Uuid().v4(), // Generate new UUID for this
        user_email: e.user_email, habitTitle: habitTitle, date: e.day, value: e.count, createdAt: e.createdAt, updatedAt: e.updatedAt,
      )).toList();
      _prepareMonthlyChart();

      setState(() {
        _last7Labels = labels;
        _last7Values = values;
      });
    } else {
      final entries = await _habitsRepo.fetchRange(_userEmail, habitTitle, DateTime.now()); // Use DateTime.now() to get recent trends
      final fmt = DateFormat('yyyy-MM-dd');
      final daily = <String, double>{};

      // Init last 7 calendar days
      for (var i = 0; i < 7; i++) {
        final d = DateTime.now().subtract(Duration(days: 6 - i));
        daily[fmt.format(d)] = 0.0;
      }
      // Sum up the latest-per-day entries
      final latestPerDay = <String, HabitEntry>{};
      for (final e in entries) {
        final k = fmt.format(e.date);
        if (!latestPerDay.containsKey(k) ||
            e.updatedAt.isAfter(latestPerDay[k]!.updatedAt)) {
          latestPerDay[k] = e;
        }
      }
      latestPerDay.forEach((k, e) => daily[k] = e.value);

      _monthlyTotalsForCharts = await _habitsRepo.fetchMonthlyTotals(_userEmail, habitTitle);
      _prepareMonthlyChart();

      setState(() {
        _last7Labels = daily.keys.toList();
        _last7Values = daily.values.toList();
      });
    }
  }

  // Prepares data for the monthly bar chart based on _monthlyTotalsForCharts
  void _prepareMonthlyChart() {
    // Build a list of 13 months ending at the current month
    final end = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final window = <DateTime>[];
    for (int i = 12; i >= 0; i--) {
      window.add(DateTime(end.year, end.month - i, 1));
    }

    final labels = window.map((dt) => DateFormat('MMM yy').format(dt)).toList();
    final values = window.map((dt) {
      final match = _monthlyTotalsForCharts.firstWhere(
            (e) => e.date.year == dt.year && e.date.month == dt.month,
        orElse: () => HabitEntry( // Provide a default if no entry for the month
          id: const Uuid().v4(), // Generate new UUID for this
          user_email: _userEmail, habitTitle: _selectedHabitForCharts,
          date: dt, value: 0.0, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
      );
      return match.value;
    }).toList();

    setState(() {
      _monthlyLabelsForCharts = labels;
      _monthlyValuesForCharts = values;
    });
  }

  // Date picker for the habits overview section
  Future<void> _pickDateForHabitsOverview() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateForHabitsOverview,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)), // 5 years back
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateForHabitsOverview) {
      setState(() => _selectedDateForHabitsOverview = picked);
      await _updateAllHabitCurrentValues();
    }
  }

  // Helper method to build a Habit Tracking Overview item (adapted from TrackHabitScreen's _buildHabitCard)
  Widget _buildHabitProgressCard(Habit h, ThemeData theme) {
    final progress = h.goal == 0 ? 0.0 : (h.currentValue / h.goal).clamp(0.0, 1.0);

    return Card(
      color: h.usePedometer ? Colors.lightGreen.shade400 : Colors.green.shade300,
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Add margin between cards
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              h.usePedometer
                  ? '${h.currentValue.toInt()}/${h.goal.toInt()} ${h.unit}'
                  : '${h.currentValue.toStringAsFixed(2)}/${h.goal} ${h.unit}',
              style: theme.textTheme.bodySmall,
            ),
            if (h.usePedometer) ...[
              const SizedBox(height: 8),
              Text(
                'For: ${DateFormat('yyyy-MM-dd').format(_selectedDateForHabitsOverview)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to build a Challenge Card (existing logic for static challenges)
  Widget _buildChallengeCard(Map<String, String> challenge) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
            child: Image.asset(
              challenge['image']!,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge['name']!,
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4.0),
                Text(
                  challenge['description']!,
                  style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                ),
                const SizedBox(height: 16.0),
                if (challenge['id'] == 'daily_eco_check_in')
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckInPage(
                            challengeId: challenge['id']!,
                            challengeName: challenge['name']!,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Check-in'),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Implement Join Challenge action for static challenges
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Join Challenge'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Implement info button action
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar (Remains at the top)
            TextField(
              decoration: InputDecoration(
                hintText: 'Search challenges...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 24.0),

            // --- Daily Check-in Section (NEW FIRST ORDER) ---
            const Text(
              'Daily Check-in', // Changed the title
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentChallenges.length,
              itemBuilder: (context, index) {
                final challenge = _currentChallenges[index];
                return _buildChallengeCard(challenge);
              },
            ),
            const SizedBox(height: 24.0),
            // --- End of Daily Check-in Section ---


            // Habit Tracking Overview Section (SECOND ORDER)
            const Text(
              'Habit Tracking Overview',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDateForHabitsOverview)}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickDateForHabitsOverview,
                ),
              ],
            ),
            const SizedBox(height: 12), // Space before habit cards
            _habits.isEmpty
                ? const Center(child: Text('No habits tracked yet. Add some!'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _habits.length,
              itemBuilder: (context, index) {
                return _buildHabitProgressCard(_habits[index], theme);
              },
            ),
            const SizedBox(height: 24.0),


            // Habit Trends & Monthly Totals Section (THIRD ORDER)
            const Divider(), // Separator before this section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Habit Trends & Monthly Totals',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedHabitForCharts,
                  items: _habits
                      .map((h) => DropdownMenuItem(
                    value: h.title,
                    child: Text(h.title),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null && v != _selectedHabitForCharts) {
                      setState(() => _selectedHabitForCharts = v);
                      _loadChartDataForSelectedHabit(v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display trend chart only if a habit is selected and data is available
            _selectedHabitForCharts != '-' && _habits.isNotEmpty
                ? InteractiveTrendChart(
              values: _last7Values,
              labels: _last7Labels,
              // maxY: _habits.firstWhere((h) => h.title == _selectedHabitForCharts).goal,
            )
                : const SizedBox(
                height: 120,
                child: Center(child: Text('Select a habit to see trends'))),
            const SizedBox(height: 24),
            // Monthly Bar Chart
            Text('Monthly Totals (Last 12 months)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            MonthlyBarChart(
              labels: _monthlyLabelsForCharts,
              values: _monthlyValuesForCharts,
            ),
            const SizedBox(height: 24.0), // Space after charts

            // --- My Joined Community Events Section (LAST ORDER) ---
            Text(
              'My Joined Community Events',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 16.0),
            FutureBuilder<List<CommunityMain>>(
              future: _futureJoinedCommunityEvents, // This is where the error is occurring
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading events: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'You haven\'t joined any community events yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ),
                  );
                } else {
                  final joinedEvents = snapshot.data!;
                  final fmt = DateFormat('MMM d, HH:mm'); // Date format for display
                  return ListView.separated(
                    shrinkWrap: true, // Important for ListView inside Column/SingleChildScrollView
                    physics: const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
                    itemCount: joinedEvents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = joinedEvents[index];
                      final img = (event.imagePath != null && File(event.imagePath!).existsSync())
                          ? Image.file(File(event.imagePath!), fit: BoxFit.cover)
                          : Image.asset('assets/images/default.jpg', fit: BoxFit.cover);

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.zero, // Remove default margin
                        child: ListTile(
                          leading: SizedBox(width: 60, height: 60, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img)),
                          title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Ends: ${fmt.format(event.endDate)}\n${event.shortDescription}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                            onPressed: () {
                              // Navigate to EventDetailScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailScreen(
                                    community: event,
                                    email: _userEmail, // Pass current user email
                                    joined: true, // Assuming it's joined if in this list
                                    joinCount: 0, // Placeholder, fetch if needed in detail screen
                                    onJoinConfirmed: () => setState(() => _futureJoinedCommunityEvents = _loadJoinedCommunityEvents(_userEmail)),
                                    onExitConfirmed: () => setState(() => _futureJoinedCommunityEvents = _loadJoinedCommunityEvents(_userEmail)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 24.0),
            // --- End of My Joined Community Events Section ---
          ],
        ),
      ),
      // Placeholder for Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes), // Example icon
            label: 'Track Habit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group), // Example icon
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline), // Example icon
            label: 'Tips & Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), // Example icon
            label: 'Profile', // Label for the new Profile page
          ),
        ],
        currentIndex: 0, // Highlight the Home item by default
        selectedItemColor: Colors.green, // Color for selected item
        unselectedItemColor: Colors.grey, // Color for unselected items
        showUnselectedLabels: true, // Show labels for unselected items
        type: BottomNavigationBarType.fixed, // Ensures items are fixed width
        onTap: (index) async {
          if (index == 0) {
            // Already on Home page, maybe do nothing or refresh
          } else if (index == 1) { // 'Track Habit' is at index 1
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TrackHabitScreen()),
            );
            if (result == true) {
              // Reload all data when returning from TrackHabitScreen
              _initializeUserAndLoadData();
            }
          } else if (index == 2) { // 'Community' is at index 2
            final result = await Navigator.push( // Use result for community too
              context,
              MaterialPageRoute(builder: (context) => const CommunityChallengesScreen()),
            );
            if (result == true) {
              _initializeUserAndLoadData(); // Refresh HomePage if changes occurred in community
            }
          } else if (index == 3){ // 'Tips & Learning' is at index 3
            final result = await Navigator.push( // Use result for tips too
              context,
              MaterialPageRoute(builder: (context) => TipsEducationScreen() ),
            );
            if (result == true) {
              _initializeUserAndLoadData(); // Refresh HomePage if needed
            }
          } else if (index == 4) { // 'Profile' is at index 4
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()), // Navigate to ProfilePage
            );
            if (result == true) {
              // Reload all data on HomePage when returning from ProfilePage,
              // as profile updates might affect displayed username, etc.
              _initializeUserAndLoadData();
            }
          }
        },
      ),
    );
  }
}

// ... (rest of the _HomePageState methods and helper widgets like _buildHabitProgressCard, _buildChallengeCard)