import 'package:flutter/material.dart';
import 'community_main.dart';  // adjust the path as needed
import 'admin_community_add_page.dart';
import 'admin_community_main.dart';

import 'package:firebase_core/firebase_core.dart';

Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      //title: 'Community App',
      title: 'Flutter + Firebase Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // home: const AdminMainPage(),
      home: const CommunityChallengesScreen(),

    );
  }
}


