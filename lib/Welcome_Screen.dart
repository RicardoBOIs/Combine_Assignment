import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment_test/YenHan/pages/login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set status bar to match theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(

      backgroundColor: Color(0xFF1B5E20),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spacer to push content down from top
              const Spacer(flex: 3),

              // Logo icon
              Image.asset( 'assets/Logo_EcoLife.png',height: 100,
                width: 100,),

              const SizedBox(height: 24.0),

              // App name
              const Text(
                'Green Habit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16.0),

              // Tagline
              const Text(
                'Start your eco-friendly journey today with Green Habit!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
                textAlign: TextAlign.center,
              ),

              // Spacer before buttons
              const Spacer(flex: 2),





              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 56.0,
                child: OutlinedButton(
                  onPressed: () {

                 Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Bottom space
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}