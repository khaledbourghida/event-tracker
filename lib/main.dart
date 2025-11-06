import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:text_app/adduser.dart';
import 'package:text_app/checkin.dart';
import 'package:text_app/dashboard.dart';
import 'package:text_app/homepage.dart';
import 'package:text_app/multi_date.dart';
import 'package:text_app/scan.dart';
import 'package:text_app/serchuser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        // scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[200],
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
          iconTheme: IconThemeData(color: Colors.orange),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Homepage(),
      routes: {
        "homepage": (context) => Homepage(),
        "adduser": (context) => AddUser(),
        "scan": (context) => ScanPage(),
        "check in": (context) => CheckinPage(),
        "multi date": (context) => MultiDatePicker(),
        "serch user": (context) => SerchPage(),
        "dashboard": (context) => Dashboard(),
      },
    );
  }
}
