import 'package:flutter/material.dart';
import 'dart:math' show pi; // Needed for drawing arcs in the pie chart

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController(text: 'Willie Wong');
  final TextEditingController _phoneController = TextEditingController(text: '0123456789');
  final TextEditingController _locationController = TextEditingController(text: 'Sarawak');
  final TextEditingController _emailController = TextEditingController(text: 'wwkx@gmail.com');

  String _selectedPhoneType = 'Mobile';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Function to handle bottom navigation bar taps for the Profile page
  void _onItemTapped(int index) {
    // Assuming bottom nav bar items correspond to routes
    switch (index) {
      case 0:
      // Navigate to Home
        if (ModalRoute.of(context)?.settings.name != '/') {
          // Using pushReplacementNamed to avoid stacking pages if already there
          Navigator.pushReplacementNamed(context, '/');
        }
        break;
      case 1:
      // Navigate to Track Habit (placeholder route)
      // Navigator.pushNamed(context, '/track_habit');
        print('Navigate to Track Habit');
        break;
      case 2:
      // Navigate to Community (placeholder route)
      // Navigator.pushNamed(context, '/community');
        print('Navigate to Community');
        break;
      case 3:
      // Navigate to Tips & Learning (placeholder route)
      // Navigator.pushNamed(context, '/tips_learning');
        print('Navigate to Tips & Learning');
        break;
      case 4:
      // Already on Profile, do nothing or scroll to top
        if (ModalRoute.of(context)?.settings.name != '/profile') {
          // This case should ideally not be reached if navigation is handled correctly from other pages
          Navigator.pushReplacementNamed(context, '/profile');
        }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Profile Header
            CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/profile_pic.png'), // Placeholder asset
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            const Text(
              'Willie Wong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Singer',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Editable Fields
            _buildEditableField(
              icon: Icons.description,
              controller: _nameController,
              hintText: 'Willie Wong',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildEditableField(
                    icon: Icons.phone,
                    controller: _phoneController,
                    hintText: '0123456789',
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
              hintText: 'Sarawak',
            ),
            const SizedBox(height: 16),
            _buildEditableField(
              icon: Icons.email,
              controller: _emailController,
              hintText: 'wwkx@gmail.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print('Name: ${_nameController.text}');
                  print('Phone: ${_phoneController.text}');
                  print('Location: ${_locationController.text}');
                  print('Email: ${_emailController.text}');
                  print('Phone Type: $_selectedPhoneType');
                  // Add logic to save data
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
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Information Cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'Carbon Footprint',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "You've decreased 10%",
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('Today', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4), // Added small space vertically
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.yellow,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('Yesterday', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: CustomPaint(
                              painter: PieChartPainter(
                                percentageGreen: 60,
                                percentageYellow: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard(
                    title: "You've completed",
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'XXX',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Task Today !!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        showUnselectedLabels: true,
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
            icon: Icon(Icons.people),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // Helper function to build an information card
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


// Custom painter for the simple pie chart representation
// This class must be defined outside of the State class.
class PieChartPainter extends CustomPainter {
  final double percentageGreen;
  final double percentageYellow;

  PieChartPainter({required this.percentageGreen, required this.percentageYellow});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..style = PaintingStyle.fill;

    // Draw green arc
    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2),
      -pi / 2, // Start angle (top)
      (percentageGreen / 100) * 2 * pi, // Sweep angle based on percentage
      true, // Use center
      paint,
    );

    // Draw yellow arc
    paint.color = Colors.yellow;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2),
      -pi / 2 + (percentageGreen / 100) * 2 * pi, // Start after green arc
      (percentageYellow / 100) * 2 * pi, // Sweep angle based on percentage
      true, // Use center
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Cast the old delegate to access properties specific to PieChartPainter
    final PieChartPainter oldPainter = oldDelegate as PieChartPainter;
    // Repaint if percentages change
    return oldPainter.percentageGreen != percentageGreen ||
        oldPainter.percentageYellow != percentageYellow;
  }
}