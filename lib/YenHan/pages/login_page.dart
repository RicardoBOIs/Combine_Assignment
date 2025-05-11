import 'package:assignment_test/YenHan/pages/tips_education.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:assignment_test/YenHan/auth_service.dart';
import 'package:assignment_test/YenHan/widgets/fancy_button.dart';
import 'package:assignment_test/YenHan/pages/register_page.dart';
import 'package:assignment_test/YenHan/pages/reset_page.dart';
import 'package:assignment_test/YenHan/Databases//UserDao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const adminEmails = ['admin@example.com', 'johnleeyenhan@gmail.com'];

// Define theme colors for consistency
const Color primaryGreen = Color(0xFF4CAF50);
const Color accentGreen = Color(0xFF8BC34A);
const Color lightGreen = Color(0xFFDCEDC8);
const Color darkGreen = Color(0xFF2E7D32);
const Color textColor = Color(0xFF333333);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mail = TextEditingController();
  final _pwd  = TextEditingController();
  final _form = GlobalKey<FormState>();

  // Separate loading states for each login method
  bool _loadingNormal = false;
  bool _loadingGoogle = false;

  /* ───────────────── Google Login ───────────────── */
  Future<void> _loginWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      /* 1️⃣  pick a Google account (no Firebase sign-in yet) */
      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) throw 'Google sign-in aborted';
      final email = googleUser.email;

      /* 2️⃣  check Firestore: EcoLife/users/profiles/{email} */
      final snap = await FirebaseFirestore.instance
          .collection('Registered_users')
          .doc(email)
          .get();

      if (!snap.exists) {
        /* no profile → jump to RegisterPage with e-mail pre-filled */
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>  RegisterPage(prefillEmail: email),
          ),
        );
        return;                               // stop here
      }

      /*  profile exists → now perform Firebase Auth sign-in */
      final googleAuth = await googleUser.authentication;
      final authCred = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCred = await authService.value.firebaseAuth.signInWithCredential(authCred);


      /* 4️⃣  cache profile locally in SQLite */
        final user = userCred.user!;
        final data = snap.data()!;
        await UserDao().EnsureUser(
          email: email,
        username: data['username'] ?? user.displayName ?? '',
        phone:    data['phone']    ?? '',
        location: data['location'] ?? '',
      );

      /* 5️⃣  route: admin or home */
      final route = adminEmails.contains(email) ? '/admin' : '/home';
      if (mounted) Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google login error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }



  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lightGreen, Colors.white],
        ),
      ),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Center(
                    child: Image.asset(
                      'assets/images/Logo_EcoLife.png',
                      height: 100,
                      width: 100,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      "GreenHabit",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _mail,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email, color: accentGreen),
                      labelStyle: TextStyle(color: textColor),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    validator: (v) =>
                    v != null && v.contains('@') ? null : 'Email Format Incorrect',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pwd,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock, color: accentGreen),
                      labelStyle: TextStyle(color: textColor),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    obscureText: true,
                    validator: (v) =>
                    v != null && v.length >= 6 ? null : 'At least 6 characters',
                  ),
                  const SizedBox(height: 24),
                  // Normal Login Button with its own loading state
                  _loadingNormal
                      ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                    ),
                  )
                      : FancyButton(
                    text: 'Login',
                    onTap: () async {
                      if (!_form.currentState!.validate()) return;
                      setState(() => _loadingNormal = true);

                      try {
                        await authService.value.signIn(
                          email: _mail.text.trim(),
                          password: _pwd.text,
                        );

                        if (!mounted) return;
                        final email = _mail.text.trim();
                        final route = adminEmails.contains(email) ? '/admin' : '/home';

                        final snap = await FirebaseFirestore.instance
                            .collection('Registered_users')
                            .doc(_mail.text.trim())
                            .get();

                        // Use empty string if not data from firestore
                        final data = snap.data() ?? {};

                        await UserDao().EnsureUser(
                          email: _mail.text.trim(),
                          username: data['username'] ?? '',
                          phone: data['phone'] ?? '',
                          location: data['location'] ?? '',
                        );

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => TipsEducationScreen()),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Login failed: $e'),
                              backgroundColor: darkGreen,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loadingNormal = false);
                      }
                    },
                    color: primaryGreen,
                  ),
                  const SizedBox(height: 16),

                  _loadingGoogle
                      ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                    ),
                  )
                      : ElevatedButton.icon(
                    onPressed: _loginWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_icon.png',
                      height: 24.0,
                      width: 24.0,
                    ),
                    label: const Text(
                      'Login with Google',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ResetPage())),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: accentGreen),
                      )),
                  const Divider(height: 32, color: lightGreen, thickness: 1),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage())),
                      child: const Text(
                        'No account? Register',
                        style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}