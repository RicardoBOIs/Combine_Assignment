import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class CarbonHistoryScreen extends StatefulWidget {
  const CarbonHistoryScreen({Key? key}) : super(key: key);

  @override
  _CarbonHistoryScreenState createState() => _CarbonHistoryScreenState();
}

class _CarbonHistoryScreenState extends State<CarbonHistoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  String _timeRange = 'Week'; // Default time range

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not logged in');
      }

      // Calculate date range based on selected time range
      DateTime endDate = DateTime.now();
      DateTime startDate;

      switch (_timeRange) {
        case 'Week':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case 'Month':
          startDate = DateTime(endDate.year, endDate.month - 1, endDate.day);
          break;
        case '3 Months':
          startDate = DateTime(endDate.year, endDate.month - 3, endDate.day);
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 7));
      }

      // Format dates for Firestore query
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      // Query Firestore for carbon footprint data
      final QuerySnapshot snapshot = await _db
          .collection('daily_Carbon_FootPrint_record')
          .doc(user.email)
          .collection('days')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
          .orderBy(FieldPath.documentId)
          .get();

      // Process the data
      List<Map<String, dynamic>> historyData = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = doc.id; // The document ID is the date in yyyy-MM-dd format

        historyData.add({
          'date': date,
          'kgCO2e': data['kgCO2e'] ?? 0.0,
          'formattedDate': _formatDateForDisplay(date),
        });
      }

      setState(() {
        _historyData = historyData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: ${e.toString()}')),
      );
    }
  }

  String _formatDateForDisplay(String dateStr) {
    // Convert yyyy-MM-dd to MM-dd format for display
    final date = DateFormat('yyyy-MM-dd').parse(dateStr);
    return DateFormat('MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Carbon Footprint History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.green.shade700),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Range:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _timeRange,
                    underline: Container(),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _timeRange = newValue;
                        });
                        _fetchHistoryData();
                      }
                    },
                    items: <String>['Week', 'Month', '3 Months']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Your Carbon Footprint Trend',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Track your daily carbon emissions over time',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 24),

            // Chart or No Data message
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                ),
              )
                  : _historyData.isEmpty
                  ? _buildNoDataView()
                  : _buildChartView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.eco,
            size: 64,
            color: Colors.green.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'No Carbon Footprint Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your carbon footprint to see your history',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 10,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _historyData.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                _historyData[value.toInt()]['formattedDate'],
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: 0,
                  maxX: _historyData.length - 1.0,
                  minY: 0,
                  maxY: _getMaxY(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _historyData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value['kgCO2e'].toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green.shade700,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green.shade700,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.shade100.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Legend
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Carbon Footprint (kg CO₂e)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          // Stats summary
          if (_historyData.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Average', _calculateAverage(), 'kg CO₂e'),
                _buildStatItem('Highest', _findHighest(), 'kg CO₂e'),
                _buildStatItem('Lowest', _findLowest(), 'kg CO₂e'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  double _getMaxY() {
    if (_historyData.isEmpty) return 50;
    double maxValue = 0;
    for (var data in _historyData) {
      if (data['kgCO2e'] > maxValue) {
        maxValue = data['kgCO2e'];
      }
    }
    return (maxValue * 1.2).ceilToDouble(); // Add 20% padding to the top
  }

  double _calculateAverage() {
    if (_historyData.isEmpty) return 0;
    double sum = 0;
    for (var data in _historyData) {
      sum += data['kgCO2e'];
    }
    return sum / _historyData.length;
  }

  double _findHighest() {
    if (_historyData.isEmpty) return 0;
    double max = _historyData[0]['kgCO2e'];
    for (var data in _historyData) {
      if (data['kgCO2e'] > max) {
        max = data['kgCO2e'];
      }
    }
    return max;
  }

  double _findLowest() {
    if (_historyData.isEmpty) return 0;
    double min = _historyData[0]['kgCO2e'];
    for (var data in _historyData) {
      if (data['kgCO2e'] < min) {
        min = data['kgCO2e'];
      }
    }
    return min;
  }
}