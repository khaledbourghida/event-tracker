import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class AddUser extends StatefulWidget {
  const AddUser({super.key});
  @override
  State<AddUser> createState() => _AddUserState();
}

class _AddUserState extends State<AddUser> {
  TextEditingController username = TextEditingController();
  TextEditingController userType = TextEditingController();
  GlobalKey<FormState> formstate = GlobalKey<FormState>();
  List<QueryDocumentSnapshot> dataDays = [];
  List<String> scans = [];
  late Map<String, dynamic> dayData;
  bool isLoading = false;
  int? numberOfDays;
  String filePath = "Pick File";
  CollectionReference users = FirebaseFirestore.instance.collection("users");
  bool isAdd = false;

  getData() async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('Days').get();
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection("time").get();
    dataDays.addAll(querySnapshot.docs);
    dayData = querySnapshot.docs.first.data() as Map<String, dynamic>;
    for (var doc in snapshot.docs) {
      scans.add(doc.id);
    }
    numberOfDays = dayData.length;
    print(numberOfDays);
    print(dayData);
  }

  void showDialogMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invalid File'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> getScanData(String day) async {
    Map<String, dynamic> scanData = {};
    QuerySnapshot timeSnapshot =
        await FirebaseFirestore.instance.collection("time").get();

    for (var doc in timeSnapshot.docs) {
      Map<String, dynamic> scanInfo = doc.data() as Map<String, dynamic>;
      bool isSpecial = scanInfo['isSpecial'] ?? false;
      List<dynamic> specialDays = scanInfo['specialDays'] ?? [];

      // For regular scans (isSpecial = false), add to all days
      // For special scans (isSpecial = true), only add to selected days
      if (!isSpecial) {
        // Regular scan - add to all days
        scanData[doc.id] = false;
      } else if (specialDays.contains(day)) {
        // Special scan - only add to selected days
        scanData[doc.id] = false;
      }
    }

    return scanData;
  }

  Future<void> addUsersFromCSV(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(
      content,
    );
    setState(() {
      isAdd = true;
    });
    if (rows.isEmpty) {
      setState(() {
        isAdd = false;
      });
      return;
    }
    ;

    final headers = rows[0];
    int nameIndex = headers.indexOf("name");
    int tikiid = headers.indexOf('tikitid');
    int typeIndex = headers.indexOf("type");

    if (nameIndex == -1) {
      showDialogMessage("No column named 'name' found in CSV");
      print("No column named 'name' found in CSV.");
      setState(() {
        isAdd = false;
      });
      return;
    }

    FirebaseFirestore firestore = FirebaseFirestore.instance;

    for (int i = 1; i < rows.length; i++) {
      String name = rows[i][nameIndex].toString().trim();
      String type =
          typeIndex != -1
              ? rows[i][typeIndex].toString().trim()
              : "participant";

      DocumentReference responce = await firestore.collection('users').add({
        "name": name,
        "tikitID": tikiid,
        "type": type,
      });

      await responce.update({
        "qr": responce.id,
        "checkin": false,
        "check day": null,
        "check time": null,
      });

      List<String> days = [];
      for (int i = 0; i < dayData.length; i++) {
        days.add(dayData["day${i + 1}"]);
      }

      for (var day in days) {
        Map<String, dynamic> scanData = await getScanData(day);
        await responce.collection("days").doc(day).set(scanData);
      }
    }

    setState(() {
      isAdd = false;
    });

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil("homepage", (content) => false);
    print("Users added successfully!");
  }

  Future<void> addUsersFromXLSX(String filePath) async {
    var file = File(filePath);
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    setState(() {
      isAdd = true;
    });
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet != null) {
        var rows = sheet.rows;

        if (rows.isEmpty) {
          showDialogMessage("No rows found in Excel");
          print("No rows found in Excel");
          setState(() {
            isAdd = false;
          });
          return;
        }

        List<Data?> headers = rows[0];
        int nameIndex = headers.indexWhere(
          (cell) => cell?.value.toString().toLowerCase() == "name",
        );
        int typeIndex = headers.indexWhere(
          (cell) => cell?.value.toString().toLowerCase() == "type",
        );

        if (nameIndex == -1) {
          showDialogMessage("No column named 'name' found in Excel");
          print("No column named 'name' found in Excel");
          setState(() {
            isAdd = false;
          });
          return;
        }

        for (int i = 1; i < rows.length; i++) {
          List<Data?> row = rows[i];
          String name =
              row.length > nameIndex && row[nameIndex] != null
                  ? row[nameIndex]!.value.toString()
                  : "";
          String type =
              typeIndex != -1 &&
                      row.length > typeIndex &&
                      row[typeIndex] != null
                  ? row[typeIndex]!.value.toString()
                  : "participant";

          if (name.isEmpty) continue;

          DocumentReference responce = await firestore.collection('users').add({
            "name": name,
            "type": type,
          });

          await responce.update({
            "qr": responce.id,
            "checkin": false,
            "check day": null,
            "check time": null,
          });

          List<String> days = [];
          for (int i = 0; i < dayData.length; i++) {
            days.add(dayData["day${i + 1}"]);
          }

          for (var day in days) {
            Map<String, dynamic> scanData = await getScanData(day);
            await responce.collection("days").doc(day).set(scanData);
          }
        }
      }
    }
    setState(() {
      isAdd = false;
    });

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil("homepage", (content) => false);
    print("✅ Users added successfully!");
  }

  Future<void> pickFileAndAddUsers() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String filePath = result.files.single.path!;

      String fileExtension = filePath.split('.').last.toLowerCase();

      if (fileExtension == 'csv') {
        await addUsersFromCSV(filePath);
      } else if (fileExtension == 'xlsx') {
        await addUsersFromXLSX(filePath);
      } else {
        showDialogMessage('Please choose a .csv or .xlsx file.');
      }
    }
  }

  addusers() async {
    if (formstate.currentState!.validate()) {
      try {
        List days = [];
        for (int i = 0; i < dayData.length; i++) {
          days.add(dayData["day${i + 1}"]);
          print(dayData["day${i + 1}"]);
        }
        print("lenght daydata : ${dayData.length}");
        print(days);
        if (days.isNotEmpty) {
          DocumentReference responce = await users.add({
            "name": username.text,
            "type": userType.text.isEmpty ? "participant" : userType.text,
          });
          await responce.update({
            "qr": responce.id,
            "checkin": false,
            "check day": null,
            "check time": null,
          });

          for (var day in days) {
            Map<String, dynamic> scanData = await getScanData(day);
            await responce.collection("days").doc(day).set(scanData);
          }

          setState(() {
            isLoading = false;
          });
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil("homepage", (route) => false);
        } else {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            animType: AnimType.rightSlide,
            title: "Error",
            desc: "Enter the days",
          ).show();
        }
      } catch (e) {
        print("=========================errorrrrr $e");
      }
    } else {
      return "Fill the text field";
    }
  }

  @override
  void initState() {
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Add User",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: formstate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Manual Entry Section
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Single User",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return "Please enter a username";
                                    }
                                    return null;
                                  },
                                  controller: username,
                                  decoration: InputDecoration(
                                    hintText: "Enter username",
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: Colors.grey[600],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: userType,
                                  decoration: InputDecoration(
                                    hintText:
                                        "Enter user type (e.g., participant, organizer)",
                                    prefixIcon: Icon(
                                      Icons.category_outlined,
                                      color: Colors.grey[600],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      addusers();
                                      setState(() {
                                        isLoading = true;
                                      });
                                    },
                                    icon: Icon(Icons.add),
                                    label: Text("Add User"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 32),

                        // Divider with text
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32),

                        // Bulk Upload Section
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Bulk Upload",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Upload a CSV or XLSX file containing user names",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: pickFileAndAddUsers,
                                    icon: Icon(Icons.upload_file),
                                    label: Text("Upload File"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[50],
                                      foregroundColor: Colors.green[700],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isAdd)
                                  Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.green,
                                                ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "Adding users...",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
