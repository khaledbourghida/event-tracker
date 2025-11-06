// import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_app/editusers.dart';
import 'package:text_app/multi_date.dart';
import 'package:intl/intl.dart';
import 'package:text_app/viewinfo.dart';
import 'package:text_app/simple_scan.dart';
import 'package:text_app/scans_list.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  TextEditingController scanName = TextEditingController();
  TextEditingController startTime = TextEditingController();
  TextEditingController endTime = TextEditingController();
  GlobalKey<FormState> formstate = GlobalKey<FormState>();
  List<QueryDocumentSnapshot> data = [];
  bool isLoading = true;
  Map<String, bool> copiedUsers = {};
  bool showButtons = false;
  List<DateTime> selectedDates = [];
  late Future<QuerySnapshot> _futureUsers;
  bool isLoadingScan = false;
  bool isSelectionMode = false;
  Set<String> selectedUsers = {};
  String selectedName = "";
  bool isInstall = false;
  List<String> availableDays = [];
  List<String> selectedDays = [];
  String selectedType = "all";

  void copyText(String id) {
    Clipboard.setData(ClipboardData(text: id));
    setState(() {
      copiedUsers[id] = true;
    });
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        copiedUsers[id] = false;
      });
    });
  }

  Future<void> requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  getData() async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    data.addAll(querySnapshot.docs);
    isLoading = false;
    setState(() {});
  }

  void showDialogMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Missing Days'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed("multi date");
              },
              child: Text('go to fill days'),
            ),
          ],
        );
      },
    );
  }

  Future<void> exportUsersToCSV() async {
    try {
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          isInstall = false;
        });
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Users not exist"),
              content: Text("add users befor this opperation"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
                TextButton(
                  onPressed: () {},
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          },
        );
        return;
      }

      List<List<dynamic>> csvData = [];
      csvData.add(["name", "qr"]);
      for (var doc in usersSnapshot.docs) {
        String name = doc["name"] ?? "";
        String qr = doc["qr"] ?? "";
        csvData.add([name, qr]);
      }
      await requestStoragePermission();
      String csv = const ListToCsvConverter().convert(csvData);
      final directory = Directory('/storage/emulated/0/Download');
      final path = directory.path;
      final file = File('$path/users.csv');
      await file.writeAsString(csv);
      setState(() {
        isInstall = false;
      });
      print("✅ Users exported successfully at: $path/users.csv");
    } catch (e) {
      print("❌ Error exporting users: $e");
    }
  }

  void toggleButtons() {
    setState(() {
      showButtons = !showButtons;
    });
  }

  void changeVar(bool i) {
    setState(() {
      i = !i;
    });
  }

  Future<void> cleanupScansFromDays() async {
    try {
      print("Starting cleanup of scan fields from days...");

      // Get all users
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      print("Found ${usersSnapshot.docs.length} users");

      // Get all days from Days collection
      DocumentSnapshot daysDoc =
          await FirebaseFirestore.instance
              .collection("Days")
              .doc("selected_days")
              .get();

      if (!daysDoc.exists) {
        print("No days found in Days collection");
        return;
      }

      Map<String, dynamic> daysData = daysDoc.data() as Map<String, dynamic>;
      List<String> allDays = daysData.values.cast<String>().toList();
      print("Found ${allDays.length} days to clean");

      // Process each user
      for (var userDoc in usersSnapshot.docs) {
        print("Processing user: ${userDoc.id}");

        // Get all day documents for this user
        QuerySnapshot daysSnapshot =
            await userDoc.reference.collection('days').get();

        // For each day document
        for (var dayDoc in daysSnapshot.docs) {
          Map<String, dynamic> dayData = dayDoc.data() as Map<String, dynamic>;

          // Create a map with all fields set to FieldValue.delete()
          Map<String, dynamic> updates = {};
          dayData.forEach((key, value) {
            // Skip if the key is a day (yyyy-MM-dd format)
            if (!key.contains('-')) {
              updates[key] = FieldValue.delete();
            }
          });

          // Only update if there are scan fields to remove
          if (updates.isNotEmpty) {
            print(
              "Removing scan fields from day ${dayDoc.id} for user ${userDoc.id}",
            );
            await dayDoc.reference.update(updates);
          }
        }
      }

      print("Cleanup completed successfully!");
    } catch (e) {
      print("Error during cleanup: $e");
    }
  }

  Future<void> resetCheckInStatus() async {
    try {
      print("Starting check-in status reset...");

      // Get all users
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      print("Found ${usersSnapshot.docs.length} users");

      // Create batch for efficient updates
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;
      const int BATCH_LIMIT = 450; // Firestore limit is 500, keeping buffer

      // Process each user
      for (var userDoc in usersSnapshot.docs) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Only update if user is checked in
        if (userData['checkin'] == true) {
          print("Resetting check-in for user: ${userDoc.id}");

          batch.update(userDoc.reference, {
            'checkin': false,
            'check day': null,
            'check time': null,
          });

          operationCount++;

          // Commit batch if near limit
          if (operationCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }
      }

      // Commit any remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      print("Check-in status reset completed successfully!");
    } catch (e) {
      print("Error during check-in reset: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
    _futureUsers = FirebaseFirestore.instance.collection("users").get();
    // Uncomment the next line to run the cleanup
    // cleanupScansFromDays();
    // Uncomment the next line to reset check-in status
    // resetCheckInStatus();
  }

  Future<void> createNewScanOptimized({
    required String scanName,
    required String startTime,
    required String endTime,
    required List<String> selectedDays,
  }) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int operationCount = 0;
    const int BATCH_LIMIT = 450; // Firestore limit is 500, keeping buffer

    try {
      // 1. First add the scan to time collection
      batch.set(
        FirebaseFirestore.instance.collection("time").doc(scanName.trim()),
        {
          "start time": startTime,
          "end time": endTime,
          "isSpecial": selectedDays.isNotEmpty,
          "specialDays": selectedDays,
        },
      );
      operationCount++;

      // 2. Get all users
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // If no selected days, get all days from Days collection
      List<String> daysToUpdate = [];
      if (selectedDays.isEmpty) {
        DocumentSnapshot daysDoc =
            await FirebaseFirestore.instance
                .collection("Days")
                .doc("selected_days")
                .get();

        if (daysDoc.exists) {
          Map<String, dynamic> data = daysDoc.data() as Map<String, dynamic>;
          daysToUpdate = data.values.cast<String>().toList();
        }
      } else {
        daysToUpdate = selectedDays;
      }

      // 3. Update each user's days
      for (var userDoc in usersSnapshot.docs) {
        for (var day in daysToUpdate) {
          batch.set(userDoc.reference.collection('days').doc(day), {
            scanName.trim(): false,
          }, SetOptions(merge: true));
          operationCount++;

          // If batch is near limit, commit and create new batch
          if (operationCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }
      }

      // Commit any remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      return;
    } catch (e) {
      print("Error creating scan: $e");
      throw e;
    }
  }

  // void _saveSelectedDays() async {
  //   setState(() {
  //     isLoading = true;
  //   });

  //   try {
  //     // Validate time format
  //     if (!isValidTime(startTime.text, endTime.text)) {
  //       throw FormatException("Invalid time format");
  //     }

  //     // Create new scan using optimized function
  //     await createNewScanOptimized(
  //       scanName: scanName.text.trim(),
  //       startTime: startTime.text,
  //       endTime: endTime.text,
  //       selectedDays: selectedDays,
  //     );

  //     if (mounted) {
  //       Navigator.of(context).pop();
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Scan created successfully!"),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     print("Error: $e");
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Error creating scan. Please try again."),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
  //     }
  //   }
  // }

  bool isValidTime(String time1, String time2) {
    try {
      if (time1 == time2) return false;
      DateFormat format = DateFormat("HH:mm");
      format.parseStrict(time1);
      format.parseStrict(time2);
      return true;
    } catch (_) {
      return false;
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
          "Home page",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          !isSelectionMode
              ? Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScansList()),
                      );
                    },
                    icon: Icon(Icons.list_alt_outlined),
                    iconSize: 24,
                    color: Colors.black87,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed("dashboard");
                    },
                    icon: Icon(Icons.dashboard_outlined),
                    iconSize: 24,
                    color: Colors.black87,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil("scan", (route) => false);
                    },
                    icon: Icon(Icons.play_circle_outline),
                    iconSize: 24,
                    color: Colors.black87,
                  ),
                ],
              )
              : Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      for (var userId in selectedUsers) {
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(userId)
                            .delete();
                      }
                      setState(() {
                        selectedUsers.clear();
                        isSelectionMode = false;
                      });
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil("homepage", (context) => false);
                    },
                    icon: Icon(Icons.delete_outline),
                    iconSize: 24,
                    color: Colors.red[400],
                  ),
                  if (selectedUsers.length == 1)
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => EditUsers(
                                  docid: selectedUsers.first,
                                  oldname: selectedName,
                                ),
                          ),
                        );
                      },
                      icon: Icon(Icons.edit_outlined),
                      iconSize: 24,
                      color: Colors.blue[400],
                    ),
                ],
              ),
        ],
      ),
      floatingActionButton:
          !isSelectionMode
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showButtons) ...[
                    FloatingActionButton(
                      heroTag: "btn1",
                      onPressed: () async {
                        DocumentSnapshot documentSnapshot =
                            await FirebaseFirestore.instance
                                .collection("Days")
                                .doc("selected_days")
                                .get();
                        if (!documentSnapshot.exists ||
                            documentSnapshot.data() == null ||
                            (documentSnapshot.data() as Map<String, dynamic>)
                                .isEmpty) {
                          showDialogMessage("fill the days befor add users");
                        } else {
                          Navigator.of(context).pushNamed("adduser");
                        }
                      },
                      mini: true,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person_add_outlined),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn2",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MultiDatePicker(),
                          ),
                        );
                      },
                      mini: true,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.calendar_today_outlined),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn3",
                      onPressed: () async {
                        setState(() {
                          isLoadingScan = true;
                        });

                        availableDays.clear();
                        selectedDays.clear();
                        scanName.clear();
                        startTime.clear();
                        endTime.clear();

                        DocumentSnapshot daySnapshot =
                            await FirebaseFirestore.instance
                                .collection("Days")
                                .doc("selected_days")
                                .get();

                        if (daySnapshot.exists) {
                          Map<String, dynamic> dayData =
                              daySnapshot.data() as Map<String, dynamic>;
                          for (var value in dayData.values) {
                            availableDays.add(value);
                          }
                        }
                        setState(() {
                          isLoadingScan = false;
                        });

                        showDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                "Add new scan",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                ),
                              ),
                              content: Form(
                                key: formstate,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        validator:
                                            (value) =>
                                                value!.isEmpty
                                                    ? "Fill the textfield"
                                                    : null,
                                        controller: scanName,
                                        decoration: InputDecoration(
                                          hintText: "Enter scan Name",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextFormField(
                                        validator:
                                            (value) =>
                                                value!.isEmpty
                                                    ? "Fill the textfield"
                                                    : null,
                                        controller: startTime,
                                        decoration: InputDecoration(
                                          hintText: "Start Time : HH:mm",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextFormField(
                                        validator:
                                            (value) =>
                                                value!.isEmpty
                                                    ? "Fill the textfield"
                                                    : null,
                                        controller: endTime,
                                        decoration: InputDecoration(
                                          hintText: "End Time : HH:mm",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "Select Days to Apply Scan:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Container(
                                        height: 150,
                                        child: StatefulBuilder(
                                          builder: (
                                            BuildContext context,
                                            StateSetter setDialogState,
                                          ) {
                                            return ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: availableDays.length,
                                              itemBuilder: (context, index) {
                                                String day =
                                                    availableDays[index];
                                                return GestureDetector(
                                                  onTap: () {
                                                    setDialogState(() {
                                                      if (selectedDays.contains(
                                                        day,
                                                      )) {
                                                        selectedDays.remove(
                                                          day,
                                                        );
                                                      } else {
                                                        selectedDays.add(day);
                                                      }
                                                    });
                                                    setState(() {});
                                                  },
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          selectedDays.contains(
                                                                day,
                                                              )
                                                              ? Colors.green
                                                                  .withOpacity(
                                                                    0.1,
                                                                  )
                                                              : Colors.white,
                                                      border: Border.all(
                                                        color:
                                                            selectedDays
                                                                    .contains(
                                                                      day,
                                                                    )
                                                                ? Colors.green
                                                                : Colors
                                                                    .grey[300]!,
                                                        width: 1.5,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          day,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                selectedDays
                                                                        .contains(
                                                                          day,
                                                                        )
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .normal,
                                                            color:
                                                                selectedDays
                                                                        .contains(
                                                                          day,
                                                                        )
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .black87,
                                                          ),
                                                        ),
                                                        if (selectedDays
                                                            .contains(day))
                                                          Icon(
                                                            Icons.check_circle,
                                                            color: Colors.green,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      if (isLoadingScan)
                                        Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                                StatefulBuilder(
                                  builder: (
                                    BuildContext context,
                                    StateSetter setButtonState,
                                  ) {
                                    return ElevatedButton(
                                      onPressed:
                                          isLoadingScan
                                              ? null
                                              : () async {
                                                if (!formstate.currentState!
                                                    .validate())
                                                  return;

                                                setState(() {
                                                  isLoading = true;
                                                });

                                                try {
                                                  await createNewScanOptimized(
                                                    scanName:
                                                        scanName.text.trim(),
                                                    startTime: startTime.text,
                                                    endTime: endTime.text,
                                                    selectedDays: selectedDays,
                                                  );

                                                  if (mounted) {
                                                    Navigator.of(context).pop();
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          "Scan created successfully!",
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  print("Error: $e");
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          "Error creating scan. Please try again.",
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(() {
                                                      isLoading = false;
                                                    });
                                                  }
                                                }
                                              },
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child:
                                          isLoadingScan
                                              ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : Text("Save"),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      mini: true,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.qr_code_scanner_outlined),
                    ),

                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn4",
                      onPressed: () {
                        Navigator.of(context).pushNamed("serch user");
                      },
                      mini: true,
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.search_outlined),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn5",
                      onPressed: () {
                        setState(() {
                          isInstall = true;
                        });
                        exportUsersToCSV();
                      },
                      mini: true,
                      backgroundColor: Colors.teal,
                      child:
                          isInstall
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Icon(Icons.download_outlined),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "btn6",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SimpleScanPage(),
                          ),
                        );
                      },
                      mini: true,
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.person_search_outlined),
                    ),
                    SizedBox(height: 10),
                  ],
                  FloatingActionButton(
                    heroTag: "main",
                    onPressed: toggleButtons,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      showButtons ? Icons.close : Icons.menu,
                      key: ValueKey<bool>(showButtons),
                    ),
                  ),
                ],
              )
              : null,
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _futureUsers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Error loading users",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  // Compute user types locally from snapshot
                  List<String> userTypes = [
                    'all',
                    ...snapshot.data!.docs
                        .map(
                          (doc) =>
                              (doc["type"] ?? "participant")
                                  .toString()
                                  .trim()
                                  .toLowerCase(),
                        )
                        .toSet()
                        .toList(),
                  ];

                  var filteredDocs =
                      snapshot.data!.docs.where((doc) {
                        if (selectedType == "all") return true;
                        return (doc["type"] ?? "participant")
                                .toString()
                                .trim()
                                .toLowerCase() ==
                            selectedType;
                      }).toList();

                  return Column(
                    children: [
                      // Type Filter Bar - Only show if there are users
                      Container(
                        height: 50,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: userTypes.length,
                          itemBuilder: (context, index) {
                            String type = userTypes[index];
                            bool isSelected = selectedType == type;
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  type == "all"
                                      ? "All Users"
                                      : StringExtension(type).capitalize(),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedType = type;
                                  });
                                },
                                backgroundColor: Colors.grey[100],
                                selectedColor: Colors.blue,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child:
                            filteredDocs.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "No users found",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Try selecting a different type",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  padding: EdgeInsets.all(16),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, i) {
                                    String id = filteredDocs[i]["qr"]!;
                                    return InkWell(
                                      onLongPress: () {
                                        setState(() {
                                          isSelectionMode = true;
                                          selectedUsers.add(
                                            filteredDocs[i]["qr"],
                                          );
                                          selectedName =
                                              filteredDocs[i]["name"];
                                        });
                                      },
                                      onTap: () {
                                        if (isSelectionMode) {
                                          setState(() {
                                            final qrId = filteredDocs[i]["qr"];
                                            if (selectedUsers.contains(qrId)) {
                                              selectedUsers.remove(qrId);
                                              if (selectedUsers.isEmpty)
                                                isSelectionMode = false;
                                            } else {
                                              selectedUsers.add(qrId);
                                            }
                                          });
                                        } else {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => ViewInfo(
                                                    username:
                                                        filteredDocs[i]["name"],
                                                    userId:
                                                        filteredDocs[i]["qr"],
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Card(
                                        elevation: 0,
                                        margin: EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          title: Text(
                                            filteredDocs[i]["name"],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                id,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  filteredDocs[i]["type"] ??
                                                      "participant",
                                                  style: TextStyle(
                                                    color: Colors.blue[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing:
                                              isSelectionMode
                                                  ? Icon(
                                                    selectedUsers.contains(id)
                                                        ? Icons.check_circle
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color:
                                                        selectedUsers.contains(
                                                              id,
                                                            )
                                                            ? Colors.green
                                                            : Colors.grey[400],
                                                  )
                                                  : IconButton(
                                                    onPressed: () {
                                                      copyText(id);
                                                    },
                                                    icon: Icon(
                                                      copiedUsers[id] == true
                                                          ? Icons.check
                                                          : Icons.copy_outlined,
                                                      color:
                                                          copiedUsers[id] ==
                                                                  true
                                                              ? Colors.green
                                                              : Colors
                                                                  .grey[600],
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  );
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No users found",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Add users to get started",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
