import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/tips_education.dart';
import 'pages/admin_dashboard.dart';
import 'tip_repository.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await TipRepository.instance.initFromFirestore();
  runApp(EcoApp());
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      // 👇 具名路由（named routes）
      routes: {
        '/':      (_) => const LoginPage(),      // 默认显示登录
        '/home':  (_) =>  TipsEducationScreen(),  // 登录成功后跳这里
        '/admin': (_) => AdminDashboardScreen()
      },
    );
  }
}