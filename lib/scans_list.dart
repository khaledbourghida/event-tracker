import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ScansList extends StatefulWidget {
  const ScansList({super.key});

  @override
  State<ScansList> createState() => _ScansListState();
}

class _ScansListState extends State<ScansList> {
  bool isLoading = true;
  List<Map<String, dynamic>> scans = [];

  @override
  void initState() {
    super.initState();
    getScans();
  }

  Future<void> getScans() async {
    try {
      QuerySnapshot scanSnapshot = await FirebaseFirestore.instance.collection("time").get();
      
      List<Map<String, dynamic>> tempScans = [];
      for (var doc in scanSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tempScans.add({
          'name': doc.id,
          'startTime': data['start time'],
          'endTime': data['end time'],
          'isSpecial': data['isSpecial'] ?? false,
          'specialDays': data['specialDays'] ?? [],
        });
      }

      // Sort scans by start time
      tempScans.sort((a, b) {
        DateTime timeA = DateFormat("HH:mm").parse(a['startTime']);
        DateTime timeB = DateFormat("HH:mm").parse(b['startTime']);
        return timeA.compareTo(timeB);
      });

      setState(() {
        scans = tempScans;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching scans: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Scans List",
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
          : scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No scans found",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Add scans to get started",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: getScans,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: scans.length,
                    itemBuilder: (context, index) {
                      final scan = scans[index];
                      final timeRange = "${scan['startTime']} - ${scan['endTime']}";
                      final isSpecial = scan['isSpecial'];
                      final specialDays = (scan['specialDays'] as List).cast<String>();

                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      scan['name'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      timeRange,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    isSpecial
                                        ? Icons.event_available
                                        : Icons.event_repeat,
                                    size: 20,
                                    color: isSpecial
                                        ? Colors.green[600]
                                        : Colors.orange[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    isSpecial ? "Specific Days" : "All Days",
                                    style: TextStyle(
                                      color: isSpecial
                                          ? Colors.green[600]
                                          : Colors.orange[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSpecial && specialDays.isNotEmpty) ...[
                                SizedBox(height: 12),
                                Text(
                                  "Applied Days:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: specialDays.map((day) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
} 