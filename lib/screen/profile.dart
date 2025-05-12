import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure these imports point to the correct locations relative to profile.dart
import '../YenHan/firestore_service.dart'; // <--- Corrected import path to match standard practice
import '../YenHan/Databases/UserDao.dart'; // Correct import for UserDao

// Import other screens for navigation
import 'package:assignment_test/screen/home.dart'; // For navigating back to HomePage
import 'package:assignment_test/screen/track_habit_screen.dart';
import 'package:assignment_test/YenHan/pages/tips_education.dart';
import 'package:assignment_test/Willie/community_main.dart'; // For CommunityChallengesScreen


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedPhoneType = 'Mobile';

  final FirestoreService _firestoreService = FirestoreService();
  final UserDao _userDao = UserDao();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = _auth.currentUser;

    if (_currentUser != null && _currentUser!.email != null) { // Ensure email is not null
      _emailController.text = _currentUser!.email!; // Use non-null asserted email

      try {
        // Always try Firestore first to get the most up-to-date profile
        final firestoreData = await _firestoreService.fetchUserProfile(_currentUser!.email!);

        if (firestoreData != null) {
          // If data is found in Firestore, populate controllers with it
          _nameController.text = firestoreData['username'] as String? ?? '';
          _phoneController.text = firestoreData['phone'] as String? ?? '';
          _locationController.text = firestoreData['location'] as String? ?? '';

          // Also, ensure this Firestore data is synced to the local SQLite database.
          // EnsureUser will insert if the user doesn't exist locally.
          // If they do exist, it will do nothing (due to ConflictAlgorithm.ignore in UserDao).
          // Local updates will happen when the user clicks 'Save' via `updateProfile`.
          await _userDao.EnsureUser(
            email: _currentUser!.email!,
            username: _nameController.text,
            phone: _phoneController.text,
            location: _locationController.text,
          );
        } else {
          // No profile found in Firestore.
          // This could mean a brand new user, or a user who hasn't saved their profile to Firestore yet.
          print('User profile not found in Firestore for ${_currentUser!.email}. Initializing local profile from defaults (if not existing locally).');

          // As per your request, we DO NOT try to load from local via `getUserByEmail`.
          // Instead, we ensure a basic local SQLite entry exists for this email.
          // The controllers will remain empty strings (their initial state)
          // unless the user enters data and saves.
          await _userDao.EnsureUser(
            email: _currentUser!.email!,
            username: '', // Default empty values for a new profile
            phone: '',
            location: '',
          );
        }
      } catch (e) {
        print('Error loading user profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
        );
      }
    } else {
      // User not logged in or email is missing.
      print('User not logged in or email is missing.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not logged in. Please log in to view your profile.')),
      );
      // Navigate back if profile page requires login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) { // Check if there's a route to pop
          Navigator.pop(context);
        } else {
          // If no previous route, perhaps navigate to a login/splash screen.
          // For now, assuming it's okay to push to home as a fallback.
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
        }
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Updated _onItemTapped for consistent MaterialPageRoute navigation
  void _onItemTapped(int index) {
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1: // Track Habit
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrackHabitScreen()),
        );
        break;
      case 2: // Community
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CommunityChallengesScreen()),
        );
        break;
      case 3: // Tips & Learning
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TipsEducationScreen()),
        );
        break;
      case 4: // Profile (already on this page)
      // Optionally scroll to top or do nothing
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine the current index for the BottomNavigationBar
    int _currentIndex = 4; // Set index 4 for the Profile item on this page

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Color is set by AppBarTheme in main.dart
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
        title: const Text('Profile'), // Color is set by AppBarTheme
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), // Color is set by AppBarTheme
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Profile Info'),
                    content: const Text('This is your profile information.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Close'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Profile Header
            CircleAvatar(
              radius: 40,
              backgroundImage: const AssetImage('assets/profile_pic.png'), // Placeholder asset
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            Text(
              _nameController.text.isNotEmpty ? _nameController.text : 'Your Name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registered User', // You can make this dynamic based on user roles if you have them
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Editable Fields
            _buildEditableField(
              icon: Icons.description, // More appropriate for a username/description
              controller: _nameController,
              hintText: 'Username',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildEditableField(
                    icon: Icons.phone,
                    controller: _phoneController,
                    hintText: 'Phone Number',
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown for Phone Type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPhoneType,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      elevation: 16,
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedPhoneType = newValue;
                          });
                        }
                      },
                      items: <String>['Mobile', 'Home', 'Work']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildEditableField(
              icon: Icons.location_on,
              controller: _locationController,
              hintText: 'Location',
            ),
            const SizedBox(height: 16),
            _buildEditableField(
              icon: Icons.email,
              controller: _emailController,
              hintText: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              readOnly: true, // Email should typically not be editable here
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (_currentUser == null || _currentUser!.email == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in to save your profile.')),
                    );
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    // Saving to Firestore first
                    await _firestoreService.saveUserProfile(
                      username: _nameController.text,
                      phone: _phoneController.text,
                      location: _locationController.text,
                    );

                    // Then, update local SQLite profile.
                    // This `updateProfile` will apply the changes made by the user to the local DB.
                    await _userDao.updateProfile(
                      email: _currentUser!.email!,
                      username: _nameController.text,
                      phone: _phoneController.text,
                      location: _locationController.text,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile saved successfully!')),
                    );
                    print('Profile saved:');
                    print('Name: ${_nameController.text}');
                    print('Phone: ${_phoneController.text}');
                    print('Location: ${_locationController.text}');
                    print('Email: ${_emailController.text}');
                    print('Phone Type: $_selectedPhoneType');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
                    );
                    print('Error saving profile: $e');
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Save',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info cards have been removed, so this section is no longer used.
            // If you plan to re-introduce them, ensure you fetch the data for them.
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes),
            label: 'Track Habit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Tips & Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped, // Use the function to handle taps and navigation
      ),
    );
  }

  // Helper function to build an editable text field row
  Widget _buildEditableField({
    required IconData icon,
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false, // Added readOnly parameter
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly, // Use the readOnly parameter
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Colors.green[700]!),
              ),
              fillColor: readOnly ? Colors.grey[100] : null, // Gray background for read-only
              filled: readOnly,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // The _buildInfoCard helper function is no longer used in the current build method,
  // but kept here in case you re-introduce cards later.
  Widget _buildInfoCard({required String title, required Widget content}) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}
