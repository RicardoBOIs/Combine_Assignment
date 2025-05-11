import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screen/track_habit_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'db/sync_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db/db_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await DbHelper().deleteDatabaseFile();
  await DbHelper().dumpSchema();
  await DbHelper().dumpCounts();
  SyncService().start();
  runApp(const EcoApp());
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoLife Habit Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: Colors.lightGreen.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.black,
          centerTitle: true,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.lightGreen.shade50,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(35),
          ),
        ),
        textTheme: GoogleFonts.patrickHandTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          fontSizeFactor: 1.3,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.black,
          ),
        ),
      ),

      navigatorKey: navigatorKey,
      home: const TrackHabitScreen(),
    );
  }
}

Future<void> seedTestData() async {
  await FirebaseFirestore.instance
      .collection('entries')
      .add({
    'habitTitle': 'Reduce Plastic',
    'date': Timestamp.now(),
    'value': 0.42,
  });
  print('⚡️ Seeded one test entry');
}



