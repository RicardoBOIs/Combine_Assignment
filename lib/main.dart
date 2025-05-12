import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../screen/home.dart';
import 'YenHan/pages/login_page.dart';
import 'YenHan/tip_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db/db_helper.dart';

// Declare a global key for the Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await TipRepository.instance.initFromFirestore();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      // Assign the global navigatorKey to the MaterialApp
      navigatorKey: navigatorKey, // <--- ADD THIS LINE
      home: const LoginPage(),
    );
  }
}