import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../YenHan/firestore_service.dart';
import '../YenHan/Databases/UserDao.dart';
import 'package:assignment_test/screen/home.dart';
import 'package:assignment_test/screen/track_habit_screen.dart';
import 'package:assignment_test/YenHan/pages/tips_education.dart';
import 'package:assignment_test/Willie/community_main.dart';
import 'package:assignment_test/YenHan/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedPhoneType = 'Mobile';
  bool _isLoading = false;
  int _currentIndex = 4; // Profile page index

  final FirestoreService _firestoreService = FirestoreService();
  final UserDao _userDao = UserDao();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrackHabitScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CommunityChallengesScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TipsEducationScreen()),
        );
        break;
      case 4:
      // Already on profile page
        break;
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final currentUser = _auth.currentUser;

    if (currentUser?.email != null) {
      _emailController.text = currentUser!.email!;
      try {
        final firestoreData = await _firestoreService.fetchUserProfile(currentUser.email!);
        if (firestoreData != null) {
          _nameController.text = firestoreData['username'] ?? '';
          _phoneController.text = firestoreData['phone'] ?? '';
          _locationController.text = firestoreData['location'] ?? '';
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.saveUserProfile(
          username: _nameController.text,
          phone: _phoneController.text,
          location: _locationController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.green.shade600
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text
                    : 'User Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _buildProfileField(
                controller: _nameController,
                label: 'Username',
                icon: Icons.person_outline,
                validator: (value) => value!.isEmpty ? 'Please enter a username' : null,
              ),
              const SizedBox(height: 16),
              _buildProfileField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildProfileField(
                controller: _locationController,
                label: 'Location',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildProfileField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                readOnly: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: const Text('Update Profile'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.red)
                ),
              ),
            ],
          ),
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
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.green),
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        fillColor: readOnly ? Colors.grey[200] : null,
        filled: readOnly,
      ),
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
    );
  }
}