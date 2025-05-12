import 'package:flutter/material.dart';
import '../models/check_in_challenge.dart';
import '../services/database_helper.dart' as db_helper;
import '../services/firestoreKK.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart'; // For status bar styling

class CheckInPage extends StatefulWidget {
  final String challengeId;
  final String challengeName;

  const CheckInPage({
    Key? key,
    required this.challengeId,
    required this.challengeName,
  }) : super(key: key);

  @override
  _CheckInPageState createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> with SingleTickerProviderStateMixin {
  int _currentTreeGrowthStage = 0;
  DateTime? _lastCheckInDate;
  bool _isLoading = true;
  int _totalCheckInDays = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final db_helper.DatabaseHelper _dbHelper = db_helper.DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  final String _placeholderUserId = 'placeholder_user_id_for_testing';

  // Define colors for better theming
  final Color _primaryColor = const Color(0xFF4CAF50); // Medium green
  final Color _accentColor = const Color(0xFF81C784); // Light green
  final Color _backgroundColor = const Color(0xFFF1F8E9); // Very light green
  final Color _textDarkColor = const Color(0xFF2E7D32); // Dark green
  final Color _textLightColor = const Color(0xFF388E3C); // Medium-dark green

  final List<String> _treeImageAssets = [
    'assets/tree_stage_0.jpeg',
    'assets/tree_stage_1.jpeg',
    'assets/tree_stage_2.jpeg',
    'assets/tree_stage_3.jpeg',
    'assets/tree_stage_4.jpeg',
  ];

  @override
  void initState() {
    super.initState();

    // Set up animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Load data
    _loadCheckInCountAndStage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckInCountAndStage() async {
    final String userId = _placeholderUserId;
    final String habitId = widget.challengeId;

    setState(() {
      _isLoading = true;
    });

    int count = 0;
    DateTime? latestCheckInTime;

    try {
      count = await _firestoreService.getCheckInCount(userId, habitId);
      final latestRecordData = await _firestoreService.getLatestDailyRecord(userId, habitId);

      if (latestRecordData != null) {
        final dynamic timestampData = latestRecordData['checkInTimestamp'];
        if (timestampData is Timestamp) {
          latestCheckInTime = timestampData.toDate();
        }
      }

      try {
        if (latestRecordData != null) {
          final String dateId = latestRecordData['date'] != null
              ? DateFormat('yyyy-MM-dd').format((latestRecordData['date'] as Timestamp).toDate())
              : DateFormat('yyyy-MM-dd').format(DateTime.now());
          await _dbHelper.saveDailyRecord(userId, habitId, dateId, {
            'userId': userId,
            'habitId': habitId,
            'date': DateFormat('yyyy-MM-dd').format(latestCheckInTime ?? DateTime.now()),
            'checkInTimestamp': (latestCheckInTime ?? DateTime.now()).toIso8601String(),
            'treeGrowthStageOnDay': latestRecordData['treeGrowthStageOnDay'] ?? 0,
            'createdAt': (latestRecordData['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('Error caching latest daily record to SQLite: $e');
      }

    } catch (e) {
      print('Error loading check-in count from Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud data unavailable. Using local data.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      try {
        count = await _dbHelper.getCheckInCount(userId, habitId);
        final latestRecordData = await _dbHelper.getLatestDailyRecord(userId, habitId);

        if (latestRecordData != null) {
          final dynamic timestampData = latestRecordData['checkInTimestamp'];
          if (timestampData is String) {
            latestCheckInTime = DateTime.tryParse(timestampData);
          }
        }
      } catch (e) {
        print('Error loading check-in count from SQLite: $e');
      }
    }

    // Calculate the tree stage based on count
    int calculatedStage = 0;
    if (count >= 120) {
      calculatedStage = 4;
    } else if (count >= 90) {
      calculatedStage = 3;
    } else if (count >= 30) {
      calculatedStage = 2;
    } else if (count >= 7) {
      calculatedStage = 1;
    } else {
      calculatedStage = 0;
    }

    setState(() {
      _totalCheckInDays = count;
      _currentTreeGrowthStage = calculatedStage;
      _lastCheckInDate = latestCheckInTime;
      _isLoading = false;
    });

    // Start animation when data is loaded
    _animationController.forward();
  }

  void _submitCheckIn() async {
    if (_isLoading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot submit check-in. Loading state.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final String userId = _placeholderUserId;
    final String habitId = widget.challengeId;
    final now = DateTime.now();
    final String todayDateId = DateFormat('yyyy-MM-dd').format(now);

    try {
      final existingRecord = await _firestoreService.getLatestDailyRecord(userId, habitId);

      if (existingRecord != null) {
        final dynamic timestampData = existingRecord['checkInTimestamp'];
        DateTime? latestCheckInTime;

        if (timestampData is Timestamp) {
          latestCheckInTime = timestampData.toDate();
        } else if (timestampData is String) {
          latestCheckInTime = DateTime.tryParse(timestampData);
        }

        if (latestCheckInTime != null &&
            latestCheckInTime.year == now.year &&
            latestCheckInTime.month == now.month &&
            latestCheckInTime.day == now.day) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You\'ve already checked in today!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          Navigator.pop(context);
          return;
        }
      }
    } catch (e) {
      print('Error checking for existing daily record: $e');
    }

    // Calculate new check-in count and stage
    int newTotalCheckInDays = _totalCheckInDays + 1;
    int newTreeGrowthStage = 0;

    if (newTotalCheckInDays >= 120) {
      newTreeGrowthStage = 4;
    } else if (newTotalCheckInDays >= 90) {
      newTreeGrowthStage = 3;
    } else if (newTotalCheckInDays >= 30) {
      newTreeGrowthStage = 2;
    } else if (newTotalCheckInDays >= 7) {
      newTreeGrowthStage = 1;
    } else {
      newTreeGrowthStage = 0;
    }

    // Create daily record for Firestore
    final Map<String, dynamic> dailyRecordData = {
      'userId': userId,
      'habitId': habitId,
      'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'checkInTimestamp': Timestamp.fromDate(now),
      'treeGrowthStageOnDay': newTreeGrowthStage,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Save to Firestore
      await _firestoreService.saveDailyRecord(userId, habitId, todayDateId, dailyRecordData);

      // Save to SQLite
      final Map<String, dynamic> dailyRecordDataForSQLite = {
        'userId': userId,
        'habitId': habitId,
        'dateId': todayDateId,
        'checkInTimestamp': now.toIso8601String(),
        'treeGrowthStageOnDay': newTreeGrowthStage,
        'createdAt': now.toIso8601String(),
      };
      await _dbHelper.saveDailyRecord(userId, habitId, todayDateId, dailyRecordDataForSQLite);

      // Update state
      setState(() {
        _totalCheckInDays = newTotalCheckInDays;

        // Only animate if stage changed
        if (_currentTreeGrowthStage != newTreeGrowthStage) {
          _animationController.reset();
          _currentTreeGrowthStage = newTreeGrowthStage;
          _animationController.forward();
        } else {
          _currentTreeGrowthStage = newTreeGrowthStage;
        }

        _lastCheckInDate = now;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Great job! Your tree is growing! (${newTotalCheckInDays} total check-ins)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error submitting check-in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving check-in: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    Navigator.pop(context);
  }

  int _getTreeGrowthStage(int checkInCount) {
    if (checkInCount >= 120) {
      return 4;
    } else if (checkInCount >= 90) {
      return 3;
    } else if (checkInCount >= 30) {
      return 2;
    } else if (checkInCount >= 7) {
      return 1;
    } else {
      return 0;
    }
  }

  String _getStageDescription(int stage) {
    switch (stage) {
      case 0:
        return 'Seedling';
      case 1:
        return 'Small Sprout';
      case 2:
        return 'Growing Tree';
      case 3:
        return 'Mature Tree';
      case 4:
        return 'Mighty Oak';
      default:
        return 'Unknown Stage';
    }
  }

  Widget _buildProgressIndicator() {
    // Calculate the percentage of growth to the next stage
    double progressPercentage = 0.0;
    int checksToNextStage = 0;

    if (_currentTreeGrowthStage == 0) {
      // Stage 0 -> 1 needs 7 check-ins
      progressPercentage = _totalCheckInDays / 7;
      checksToNextStage = 7 - _totalCheckInDays;
    } else if (_currentTreeGrowthStage == 1) {
      // Stage 1 -> 2 needs 30 check-ins
      progressPercentage = (_totalCheckInDays - 7) / (30 - 7);
      checksToNextStage = 30 - _totalCheckInDays;
    } else if (_currentTreeGrowthStage == 2) {
      // Stage 2 -> 3 needs 90 check-ins
      progressPercentage = (_totalCheckInDays - 30) / (90 - 30);
      checksToNextStage = 90 - _totalCheckInDays;
    } else if (_currentTreeGrowthStage == 3) {
      // Stage 3 -> 4 needs 120 check-ins
      progressPercentage = (_totalCheckInDays - 90) / (120 - 90);
      checksToNextStage = 120 - _totalCheckInDays;
    } else {
      // Stage 4 is max, so 100% progress
      progressPercentage = 1.0;
      checksToNextStage = 0;
    }

    // Clamp progress to between 0 and 1
    progressPercentage = progressPercentage.clamp(0.0, 1.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress to next stage:',
                style: TextStyle(
                  color: _textDarkColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progressPercentage * 100).toInt()}%',
                style: TextStyle(
                  color: _textDarkColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercentage,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_currentTreeGrowthStage < 4)
          Text(
            checksToNextStage > 0
                ? '$checksToNextStage more check-ins until next stage!'
                : 'Ready to advance to next stage!',
            style: TextStyle(
              color: _textLightColor,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay style for status bar
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _primaryColor,
      statusBarIconBrightness: Brightness.light,
    ));

    String currentTreeAsset = _treeImageAssets[_currentTreeGrowthStage.clamp(0, _treeImageAssets.length - 1)];

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Check In',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading your progress...',
              style: TextStyle(
                color: _textDarkColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Challenge info card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 24,
                              child: Icon(
                                Icons.park_rounded,
                                color: _primaryColor,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Checking in for:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    widget.challengeName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Growing tree section
                      ScaleTransition(
                        scale: _animation,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(12),
                          child: Column(
                            children: [
                              // Tree image
                              Container(
                                width: double.infinity,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F9FF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Hero(
                                  tag: 'tree_${widget.challengeId}',
                                  child: Image.asset(
                                    currentTreeAsset,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Tree status info
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.eco,
                                          color: _primaryColor,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          _getStageDescription(_currentTreeGrowthStage),
                                          style: TextStyle(
                                            color: _textDarkColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: _primaryColor,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '$_totalCheckInDays check-ins',
                                          style: TextStyle(
                                            color: _textDarkColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Progress indicator
                              _buildProgressIndicator(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Last check-in info
                      if (_lastCheckInDate != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 16,
                                color: _textLightColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Last check-in: ${DateFormat('MMM d, yyyy').format(_lastCheckInDate!)}',
                                style: TextStyle(
                                  color: _textLightColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Motivational text
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 8.0,
                        ),
                        child: Text(
                          'Consistency is key! Check in daily to watch your tree grow from a tiny seed to a mighty oak.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textLightColor,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Check-in button at bottom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: _primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Submit Check In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}