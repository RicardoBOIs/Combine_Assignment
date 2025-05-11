import '../attr/habit_entry.dart';
import '../attr/habit.dart';

abstract class HabitsRepository {
  Future<void> upsertEntry(HabitEntry entry);
  Future<List<HabitEntry>> fetchLast7Days(String user_email, String habitTitle);
  Future<List<HabitEntry>> fetchMonthlyTotals(String user_email, String habitTitle);
  Future<void> clearEntries();
  Future<void> clearEntriesForHabit(String habitTitle);
  Future<List<HabitEntry>> fetchRange(String user_email, String habitTitle, DateTime pivotDate);
  Future<void> deleteDay(String habitTitle, DateTime date);
  Future<void> deleteAllEntriesForHabit(String habitTitle);
  Future<void> upsertHabit(Habit habit, String userEmail);
  Future<List<Habit>> fetchHabits(String userEmail);
  Future<void> deleteHabit(String userEmail, String title);
}