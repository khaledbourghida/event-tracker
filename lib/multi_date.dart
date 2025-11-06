import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class MultiDatePicker extends StatefulWidget {
  @override
  _MultiDatePickerState createState() => _MultiDatePickerState();
}

class _MultiDatePickerState extends State<MultiDatePicker> {
  List<DateTime> selectedDates = [];
  bool isLoading = true; // بدأ التحميل عند تشغيل التطبيق
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, bool> markedDates = {};

  @override
  void initState() {
    super.initState();
    getSavedDays();
  }

  Future<void> getSavedDays() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection("Days").doc("selected_days").get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<DateTime> loadedDates = [];

        data.forEach((key, value) {
          DateTime date = DateFormat("yyyy-MM-dd").parse(value);
          loadedDates.add(date);
        });

        setState(() {
          selectedDates = loadedDates;
          selectedDates.sort(); // ترتيب الأيام
          _updateMarkedDates();
        });
      }
    } catch (e) {
      print("Error fetching dates: $e");
    } finally {
      if (mounted){
        setState(() {
          isLoading = false; // إنهاء التحميل وعرض الصفحة
        });
      }
    }
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    setState(() {
      DateTime normalizedDay = DateTime(day.year, day.month, day.day);
      if (selectedDates.contains(normalizedDay)) {
        selectedDates.remove(normalizedDay);
      } else {
        selectedDates.add(normalizedDay);
      }
      selectedDates.sort(); // ترتيب الأيام بعد التحديد أو الإزالة
      _updateMarkedDates();
    });
  }

  void _updateMarkedDates() {
    markedDates.clear();
    for (var date in selectedDates) {
      markedDates[DateTime(date.year, date.month, date.day)] = true;
    }
  }

  void _saveSelectedDays() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. Get the current days from Firestore
      DocumentSnapshot currentDaysDoc = await FirebaseFirestore.instance
          .collection("Days")
          .doc("selected_days")
          .get();

      // Convert current days to DateTime for comparison
      List<DateTime> currentDays = [];
      if (currentDaysDoc.exists) {
        Map<String, dynamic> data = currentDaysDoc.data() as Map<String, dynamic>;
        data.forEach((key, value) {
          DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(value);
          // Normalize the date by removing time component
          currentDays.add(DateTime(parsedDate.year, parsedDate.month, parsedDate.day));
        });
      }

      // Normalize selected dates
      List<DateTime> normalizedSelectedDates = selectedDates.map((date) => 
        DateTime(date.year, date.month, date.day)
      ).toList();

      // Debug print
      print("Current days in Firestore:");
      for (var day in currentDays) {
        print(DateFormat("yyyy-MM-dd").format(day));
      }
      print("\nSelected days:");
      for (var day in normalizedSelectedDates) {
        print(DateFormat("yyyy-MM-dd").format(day));
      }

      // 2. Find added and removed days using normalized dates
      List<DateTime> addedDays = normalizedSelectedDates
          .where((selectedDate) => !currentDays.any((currentDate) => 
              selectedDate.year == currentDate.year && 
              selectedDate.month == currentDate.month && 
              selectedDate.day == currentDate.day))
          .toList();

      List<DateTime> removedDays = currentDays
          .where((currentDate) => !normalizedSelectedDates.any((selectedDate) => 
              selectedDate.year == currentDate.year && 
              selectedDate.month == currentDate.month && 
              selectedDate.day == currentDate.day))
          .toList();

      // Debug print
      print("\nAdded days:");
      for (var day in addedDays) {
        print(DateFormat("yyyy-MM-dd").format(day));
      }
      print("\nRemoved days:");
      for (var day in removedDays) {
        print(DateFormat("yyyy-MM-dd").format(day));
      }

      // 3. Save new days to Days collection
      Map<String, dynamic> daysData = {};
      for (int i = 0; i < normalizedSelectedDates.length; i++) {
        daysData["day${i + 1}"] = DateFormat("yyyy-MM-dd").format(normalizedSelectedDates[i]);
      }

      print("\nSaving to Firestore:");
      daysData.forEach((key, value) => print("$key: $value"));

      await FirebaseFirestore.instance
          .collection("Days")
          .doc("selected_days")
          .set(daysData);

      // 4. Get all scans to check which ones need to be added to new days
      QuerySnapshot timeSnapshot = await FirebaseFirestore.instance.collection("time").get();
      Map<String, bool> scansToAdd = {};
      
      for (var doc in timeSnapshot.docs) {
        Map<String, dynamic> scanData = doc.data() as Map<String, dynamic>;
        String scanName = doc.id;
        bool isSpecial = scanData['isSpecial'] ?? false;
        List<String> specialDays = isSpecial ? 
            List<String>.from(scanData['specialDays'] ?? []) : [];

        // If scan is not special (applies to all days) or if the new day is in specialDays
        for (var newDay in addedDays) {
          String formattedNewDay = DateFormat("yyyy-MM-dd").format(newDay);
          if (!isSpecial || specialDays.contains(formattedNewDay)) {
            scansToAdd[scanName] = false;
          }
        }
      }

      print("\nScans to add:");
      scansToAdd.forEach((key, value) => print("$key: $value"));

      // 5. Update all users
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;
      const int BATCH_LIMIT = 450;  // Firestore limit is 500, keeping buffer

      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance.collection("users").get();
      print("\nUpdating ${usersSnapshot.docs.length} users");

      for (var userDoc in usersSnapshot.docs) {
        // Handle added days
        for (var newDay in addedDays) {
          String formattedNewDay = DateFormat("yyyy-MM-dd").format(newDay);
          if (scansToAdd.isNotEmpty) {
            batch.set(
              userDoc.reference.collection("days").doc(formattedNewDay),
              scansToAdd,
              SetOptions(merge: true)
            );
            operationCount++;
            print("Adding day $formattedNewDay to user ${userDoc.id}");
          }
        }

        // Handle removed days
        for (var removedDay in removedDays) {
          String formattedRemovedDay = DateFormat("yyyy-MM-dd").format(removedDay);
          batch.delete(userDoc.reference.collection("days").doc(formattedRemovedDay));
          operationCount++;
          print("Removing day $formattedRemovedDay from user ${userDoc.id}");
        }

        // Commit batch if near limit
        if (operationCount >= BATCH_LIMIT) {
          print("Committing batch at $operationCount operations");
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      // Commit any remaining operations
      if (operationCount > 0) {
        print("Committing final batch with $operationCount operations");
        await batch.commit();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Days updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print("Error updating days: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating days. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          "Select Event Days",
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Calendar Card
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: TableCalendar(
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          weekendTextStyle: TextStyle(color: Colors.red[400]),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          todayTextStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                          defaultTextStyle: TextStyle(
                            color: Colors.black87,
                          ),
                          weekendDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: true,
                          formatButtonShowsNext: false,
                          formatButtonDecoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          formatButtonTextStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.blue[700]),
                          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.blue[700]),
                        ),
                        focusedDay: DateTime.now(),
                        firstDay: DateTime(2020),
                        lastDay: DateTime(2030),
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            markedDates.containsKey(DateTime(day.year, day.month, day.day)),
                        onDaySelected: _onDaySelected,
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, date, events) {
                            if (markedDates.containsKey(DateTime(date.year, date.month, date.day))) {
                              return GestureDetector(
                                onTap: () => _onDaySelected(date, DateTime.now()),
                                child: Container(
                                  margin: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),

                  // Selected Dates Section
                  if (selectedDates.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selected Dates",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: selectedDates.map((date) {
                              String formattedDate = DateFormat("yyyy-MM-dd").format(date);
                              return Chip(
                                label: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.blue[50],
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.blue[700],
                                ),
                                onDeleted: () {
                                  setState(() {
                                    selectedDates.remove(date);
                                    _updateMarkedDates();
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.blue[100]!),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 24),

                  // Save Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveSelectedDays,
                        icon: Icon(Icons.save_outlined),
                        label: Text("Save Selected Days"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Loading Indicator
                  if (isLoading)
                    Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Saving selected days...",
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
  }
}



// for (var doc in parentDocs.docs) {
      //   CollectionReference subCollection = doc.reference.collection("days");
        
      //   QuerySnapshot subDocs = await subCollection.get();
      //   for (var subDoc in subDocs.docs) {
      //     await subDoc.reference.delete();
      //   }
      // }
      // Map<String, dynamic> scanData = {}; // Create a map for scan values
      //       for (String scan in scans) {
      //         scanData[scan] = false; // Set all scans to false
      //       }
      // for (var doc in parentDocs.docs) {
      //   CollectionReference subCollection = doc.reference.collection("days");
      //   subCollection.doc(formattedDate).update(scanData);
      // }