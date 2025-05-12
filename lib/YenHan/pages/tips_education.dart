import 'package:flutter/material.dart';
import 'dart:math';
import 'package:assignment_test/YenHan/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assignment_test/YenHan/tip_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screen/home.dart';
import 'package:assignment_test/YenHan/Databases/CarbonFootPrintDao.dart';
import '../../screen/track_habit_screen.dart';
import 'package:assignment_test/Willie/community_main.dart';

String _selectedRegion = 'MY';

class Tip {
  final String title, subtitle, reference;
  Tip({required this.title, required this.subtitle, required this.reference});

  factory Tip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Tip(
      title: d['title'] ?? '',
      subtitle: d['subtitle'] ?? '',
      reference: d['reference'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'reference': reference,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

final Map<String, Map<String, double>> _emissionFactors = {
  'MY': {
    'vehicle': 0.18,
    'electricity': 0.55,
    'meat': 4.5,
    'public': 0.05,
    'vegetable': 0.5,
    'water': 0.0003,
    'waste': 0.45,
  },
};

class TipsEducationScreen extends StatefulWidget {
  @override
  _TipsEducationScreenState createState() => _TipsEducationScreenState();
}

class _TipsEducationScreenState extends State<TipsEducationScreen> {
  List<Tip> displayedTips = [];

  @override
  void initState() {
    super.initState();
    _shuffleTips();
  }

  void _shuffleTips() {
    setState(() {
      final all = List<Tip>.from(TipRepository.instance.tips);
      all.shuffle(Random());
      displayedTips = all.take(4).toList();
    });
  }

  final _vehicleKmCtrl = TextEditingController();
  final _publicKmCtrl = TextEditingController();
  final _meatKgCtrl = TextEditingController();
  final _vegKgCtrl = TextEditingController();
  final _waterLCtrl = TextEditingController();
  final _wasteKgCtrl = TextEditingController();
  final _energyController = TextEditingController();
  double? _carbonFootprint;

  void _calculateCarbonFootprint() {

    double safeParseNonNegative(String text, String fieldName) {
      final value = double.tryParse(text) ?? 0;
      if (value < 0) {
        // Show warning for negative values
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Negative value entered for $fieldName. Using 0 instead.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return 0;
      }
      return value;
    }

    final vehicleKm = safeParseNonNegative(_vehicleKmCtrl.text, "Car Driven");
    final publicKm = safeParseNonNegative(_publicKmCtrl.text,"Public Transport");
    final electricity = safeParseNonNegative(_energyController.text, "Electricity Usage");
    final meatKg = safeParseNonNegative(_meatKgCtrl.text,"Meat Consumed");
    final vegKg = safeParseNonNegative(_vegKgCtrl.text,"Vegetables Consumed");
    final waterL = safeParseNonNegative(_waterLCtrl.text,"Tap Water Used");
    final wasteKg = safeParseNonNegative(_wasteKgCtrl.text,"Waste Generated");

    final f = _emissionFactors[_selectedRegion]!;

    final transport = vehicleKm * f['vehicle']! + publicKm * f['public']!;
    final power = electricity * f['electricity']!;
    final diet = meatKg * f['meat']! + vegKg * f['vegetable']!;
    final water = waterL * f['water']!;
    final waste = wasteKg * f['waste']!;

    final kgCo2 = transport + power + diet + water + waste;

    setState(() {
      _carbonFootprint = kgCo2;
    });
  }

  void _resetCalculator() {
    setState(() {

      _vehicleKmCtrl.text = "";
      _publicKmCtrl.text = "";
      _energyController.text = "";
      _meatKgCtrl.text = "";
      _vegKgCtrl.text = "";
      _waterLCtrl.text = "";
      _wasteKgCtrl.text = "";
      _carbonFootprint = null;
    });
  }

  int _selectedIndex = 3;

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return; // Don't navigate if we're already on this page

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const TrackHabitScreen();
        break;
      case 2:
        nextPage = const CommunityChallengesScreen();
        break;
      case 3:
        nextPage = TipsEducationScreen();
        break;
      case 4:
        nextPage = const TrackHabitScreen();
        break;
      default:
        nextPage = const HomePage();
    }

    // Use Navigator to push to the new page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }


  void _showTipDetail(Tip tip) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32), // Dark green
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    tip.subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    )
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  "Learn more:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final url = Uri.parse(tip.reference);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  },
                  child: Text(
                    tip.reference,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green.shade700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Tips & Education',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            )
        ),

      ),
      body: RefreshIndicator(
        onRefresh: () async{
          _shuffleTips();
          _resetCalculator();
        },
        color: Colors.green.shade700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* ───────────────── Section Header ───────────────── */
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Eco Tips',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              /* ───────────────── Tips Grid ───────────────── */
              displayedTips.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                  ),
                ),
              )
                  : GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final tip in displayedTips)
                    _TipCard(
                      title: tip.title,
                      onTap: () => _showTipDetail(tip),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              /* ───────────────── Calculator Section ───────────────── */
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: Colors.green.shade700, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Carbon Footprint Calculator',
                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimate your daily carbon emissions',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),



                    /* Transport Section */
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Transportation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _vehicleKmCtrl,
                      decoration: _buildInputDecoration('Kilometres driven (car)', Icons.directions_car),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _publicKmCtrl,
                      decoration: _buildInputDecoration('Kilometres by public transport', Icons.directions_bus),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    /* Energy Section */
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Energy Usage',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _energyController,
                      decoration: _buildInputDecoration('Electricity usage (kWh)', Icons.lightbulb),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    /* Diet Section */
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Diet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _meatKgCtrl,
                      decoration: _buildInputDecoration('Meat consumed (kg)', Icons.fastfood),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _vegKgCtrl,
                      decoration: _buildInputDecoration('Vegetables consumed (kg)', Icons.eco),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    /* Resources Section */
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.opacity, color: Colors.cyan.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Resources',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.cyan.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _waterLCtrl,
                      decoration: _buildInputDecoration('Tap water used (litre)', Icons.water_drop),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _wasteKgCtrl,
                      decoration: _buildInputDecoration('Waste generated (kg)', Icons.delete),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    /* Calculate Button */
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          _calculateCarbonFootprint();
                          if (_carbonFootprint != null) {
                            await FirestoreService().saveDailyFootprint(_carbonFootprint!);
                            final user = FirebaseAuth.instance.currentUser;
                            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                            if (user != null) {
                              await FootprintDao().upsert(user.email!, today, _carbonFootprint!);
                            }
                          }
                        },
                        child: const Text('CALCULATE MY FOOTPRINT'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    /* Results */
                    if (_carbonFootprint != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Carbon Footprint:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.co2,
                                  color: _carbonFootprint! < 13.6
                                      ? Colors.green.shade700
                                      : (_carbonFootprint! <  22.1 ? Colors.orange : Colors.red),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_carbonFootprint!.toStringAsFixed(2)} kg CO₂e',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _carbonFootprint! < 13.6
                                        ? Colors.green.shade700
                                        : (_carbonFootprint! <  22.1 ? Colors.orange : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _carbonFootprint! < 13.6
                                  ? 'Great job! Your carbon footprint is below average.'
                                  : (_carbonFootprint! < 22.1
                                  ? 'Your carbon footprint is about average.'
                                  : 'Your carbon footprint is above average. Check out our tips to reduce it!'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Track Habit'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Tips & Learning'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _TipCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco,
              color: Colors.green.shade700,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}