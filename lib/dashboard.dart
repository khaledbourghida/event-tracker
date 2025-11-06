import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Map<String, dynamic> dayData;
  List<String> days = [];
  bool isLoading = true;
  int numUser = 0;
  int numScan = 0;
  String selectedDay = ""; // for currently selected day
  Map<String, int> scanStats = {}; // stores current scan stats
  int totalUsers = 0;
  bool isStatsLoading = false;
  Map<String, int>? checkinStats;
  Map<String, int>? scanComparisonStats;
  List<String> docIds = [];


  Future<int> getFieldCountFromFirstSubDoc() async {
  try {
    // Step 1: Get first document in 'users' collection
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .limit(1)
        .get();

    if (userSnapshot.docs.isEmpty) return 0;

    DocumentSnapshot firstUserDoc = userSnapshot.docs.first;
    String userId = firstUserDoc.id;

    // Step 2: Get first document in 'days' subcollection
    QuerySnapshot daysSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("days")
        .limit(1)
        .get();

    if (daysSnapshot.docs.isEmpty) return 0;

    DocumentSnapshot firstDayDoc = daysSnapshot.docs.first;

    // Step 3: Get number of fields inside that document
    Map<String, dynamic> data = firstDayDoc.data() as Map<String, dynamic>;
    return data.length;

  } catch (e) {
    print("Error: $e");
    return 0;
  }
}

  getData() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users") // replace with your collection name
        .get();
      setState(() {
        numUser = snapshot.docs.length;
      });
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .limit(1)
        .get();
      if(userSnapshot.docs.isNotEmpty){
        DocumentSnapshot firstUserDoc = userSnapshot.docs.first;
        String userId = firstUserDoc.id;

        // Step 2: Get first document in 'days' subcollection
        QuerySnapshot daysSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("days")
            .limit(1)
            .get();
        if (daysSnapshot.docs.isNotEmpty){
          DocumentSnapshot firstDayDoc = daysSnapshot.docs.first;

          // Step 3: Get number of fields inside that document
          Map<String, dynamic> data = firstDayDoc.data() as Map<String, dynamic>;
          setState(() {
            numScan = data.length;
          });
        }
      }
        
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection("Days")
          .doc("selected_days")
          .get();
      if (docSnapshot.exists) {
        dayData = docSnapshot.data() as Map<String, dynamic>;
        print(dayData);
        for (int i = 0 ; i < dayData.length ; i++) {
          days.add(dayData["day${i + 1}"]);
          print("================ $days");
        }
      print(days);
      print("======================${days[0]}");
      setState(() {
        // isLoading = false;
        selectedDay = days[0];
      });
      loadStatsForDay(days[0]);
      } else {
        print('Document not found.');
        setState(() {
          isLoading = false;
        });
        return null;
      }
    } catch (e) {
      print('Error getting document: $e');
      return null;
    }
  }

  bool isbefore(String inputDate) {
    DateTime now = DateTime.now();
    DateFormat format = DateFormat('yyyy-MM-dd');
    DateTime parsedDate = format.parse(inputDate);

    // Remove time portion for accurate day comparison
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime checkDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    if(checkDate.isBefore(today)){
      return true;
    }else {
      return false;
    }
  }

  bool isafter(String inputDate) {
    DateTime now = DateTime.now();
    DateFormat format = DateFormat('yyyy-MM-dd');
    DateTime parsedDate = format.parse(inputDate);

    // Remove time portion for accurate day comparison
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime checkDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    if(checkDate.isAfter(today)){
      return true;
    }else{
      return false;
    }
  }


  String getchar(String dateStr) {
    // String dateStr = "2025-04-14";

    // Parse the string to DateTime
    DateTime date = DateFormat("yyyy-MM-dd").parse(dateStr);

    // Get full day name
    String dayName = DateFormat('EEEE').format(date); // "Monday"

    // Get the first character
    String firstChar = dayName[0]; // "M"

    return firstChar;
  }

  Future<Map<String, int>> getScanStats(String dayId) async {
  // Maps to hold counts
  Map<String, int> scanCount = {};
  int totalUsers = 0;

  QuerySnapshot usersSnapshot =
      await FirebaseFirestore.instance.collection("users").get();

  for (var userDoc in usersSnapshot.docs) {
    totalUsers++;

    // Get the day's document inside this user
    DocumentSnapshot daySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(userDoc.id)
        .collection("days")
        .doc(dayId)
        .get();

    if (daySnapshot.exists) {
      Map<String, dynamic> data = daySnapshot.data() as Map<String, dynamic>;

      // Count each scan that is true
      data.forEach((key, value) {
        if (value == true) {
          scanCount[key] = (scanCount[key] ?? 0) + 1;
        } else {
          scanCount.putIfAbsent(key, () => 0);
        }
      });
    }
  }

  // Add total users as an extra field if needed
  scanCount["totalUsers"] = totalUsers;
  print("===============$scanCount");
  return scanCount;
}

  Future<void> loadStatsForDay(String dayId) async {
    setState(() {
      isStatsLoading = true;
    });

    Map<String, int> stats = await getScanStats(dayId);
    setState(() {
      selectedDay = dayId;
      scanStats = stats;
      totalUsers = stats["totalUsers"] ?? 0;
      isStatsLoading = false;
      isLoading = false;
    });
  }

  Future<Map<String, int>> getCheckinStats() async {
    QuerySnapshot usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    int checkedIn = 0;
    int notCheckedIn = 0;

    for (var doc in usersSnapshot.docs) {
      bool checkin = doc['checkin'] ?? false;
      if (checkin) {
        checkedIn++;
      } else {
        notCheckedIn++;
      }
    }

    return {
      'true': checkedIn,
      'false': notCheckedIn,
    };
  }

  Future<Map<String, int>> getScansSummaryForAllUsers() async {
    Map<String, int> scanCounts = {};

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("time")
        .get();

    for (var doc in snapshot.docs) {
      docIds.add(doc.id);
    }

    for (final userDoc in usersSnapshot.docs) {
      final daysSnapshot = await userDoc.reference.collection('days').get();

      for (final dayDoc in daysSnapshot.docs) {
        final scans = dayDoc.data();

        scans.forEach((scanName, value) {
          if (value == true) {
            scanCounts[scanName] = (scanCounts[scanName] ?? 0) + 1;
          }
        });
      }
    }

    return scanCounts;
  }


  initializeData() async{
    getData();
    getCheckinStats().then((result) {
      setState(() {
        checkinStats = result;
      });
    });
    getScansSummaryForAllUsers().then((data) {
    setState(() {
      scanComparisonStats = data;
    });
  });
  }

  @override
  void initState() {
    super.initState();
    initializeData();
    
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Dashboard",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : days.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No days found",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Days Timeline
                      Container(
                        height: 150,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          itemBuilder: (context, i) {
                            return Column(
                              children: [
                                Text(
                                  getchar(days[i]),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    loadStatsForDay(days[i]);
                                  },
                                  child: Container(
                                    margin: EdgeInsets.symmetric(horizontal: 15),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isbefore(days[i])
                                          ? Colors.green[100]
                                          : (!isbefore(days[i]) && !isafter(days[i]))
                                              ? Colors.purple[100]
                                              : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: isbefore(days[i])
                                            ? Colors.green
                                            : (!isbefore(days[i]) && !isafter(days[i]))
                                                ? Colors.purple
                                                : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: isbefore(days[i])
                                          ? Icon(Icons.check, color: Colors.green[700])
                                          : Text(
                                              days[i].split('-').last,
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: (!isbefore(days[i]) && !isafter(days[i]))
                                                    ? Colors.purple[700]
                                                    : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Statistics Cards
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Data Statistics",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Total Users",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "$numUser",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Total Scans",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "$numScan",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Data Analysis Section
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Data Analysis",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              selectedDay,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 16),
                            isStatsLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  )
                                : Column(
                                    children: scanStats.entries
                                        .where((e) => e.key != "totalUsers")
                                        .map((entry) {
                                          double percent = totalUsers == 0
                                              ? 0.0
                                              : entry.value / totalUsers;
                                          return Card(
                                            elevation: 0,
                                            margin: EdgeInsets.only(bottom: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              side: BorderSide(color: Colors.grey[200]!),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  CircularPercentIndicator(
                                                    radius: 40.0,
                                                    lineWidth: 8.0,
                                                    percent: percent.clamp(0.0, 1.0),
                                                    center: Text(
                                                      "${(percent * 100).toInt()}%",
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                    progressColor: Colors.blue,
                                                    backgroundColor: Colors.blue[50]!,
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          entry.key,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 16,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          "${entry.value} / $totalUsers users scanned",
                                                          style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                          ],
                        ),
                      ),

                      // Check-in Chart
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Check-in Status",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 16),
                            checkinStats == null
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  )
                                : Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Container(
                                        height: 250,
                                        child: buildBarChart(checkinStats!),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Scans Comparison Chart
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Scans Comparison",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 16),
                            scanComparisonStats == null
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  )
                                : Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Container(
                                        height: 300,
                                        child: buildScanComparisonBarChart(
                                            scanComparisonStats!, docIds),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// Update the chart builders with modern styling
Widget buildBarChart(Map<String, int> data) {
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: ([data['true'] ?? 0, data['false'] ?? 0]
              .reduce((a, b) => a > b ? a : b))
          .toDouble() +
          5,
      barGroups: [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: (data['true'] ?? 0).toDouble(),
              color: Colors.green[400],
              width: 30,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
        BarChartGroupData(
          x: 1,
          barRods: [
            BarChartRodData(
              toY: (data['false'] ?? 0).toDouble(),
              color: Colors.red[400],
              width: 30,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, _) {
              switch (value.toInt()) {
                case 0:
                  return Text(
                    'Checked In',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                case 1:
                  return Text(
                    'Not Checked In',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                default:
                  return Text('');
              }
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, _) => Text(
              '${value.toInt()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[200],
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    ),
  );
}

Widget buildScanComparisonBarChart(Map<String, int> scanCounts, List<String> docIds) {
  final maxY = (scanCounts.values.isEmpty
          ? 1
          : scanCounts.values.reduce((a, b) => a > b ? a : b)) +
      1;

  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY.toDouble(),
      barGroups: List.generate(docIds.length, (index) {
        final scanName = docIds[index];
        final count = scanCounts[scanName] ?? 0;

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.blue[400],
              width: 22,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        );
      }),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < docIds.length) {
                if (docIds.length > 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Transform.rotate(
                      angle: -1.5708,
                      child: Text(
                        docIds[index],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Text(
                      docIds[index],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  );
                }
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 32,
            getTitlesWidget: (value, _) => Text(
              '${value.toInt()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[200],
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    ),
  );
}

