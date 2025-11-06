import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ScanPage extends StatefulWidget {
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool isScanning = true;
  String? scannedQR = "";
  String? scanStatus;
  MobileScannerController controller = MobileScannerController();

  Future<void> scanCode(String? qrString) async {
    if (!isScanning || qrString == null) return;

    setState(() {
      isScanning = false;
      scannedQR = qrString;
      scanStatus = "Processing...";
    });

    try {
      // Get current date and time
      DateTime now = DateTime.now();
      String currentDay = DateFormat("yyyy-MM-dd").format(now);
      String currentTime = DateFormat("HH:mm").format(now);

      // Check if user exists
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance
              .collection("users")
              .where("tikitId", isEqualTo: qrString)
              .get();

      if (userSnapshot.docs.isEmpty) {
        setState(() => scanStatus = "User not found!");
        return;
      }

      // Check if day is in selected days
      DocumentSnapshot selectedDaysDoc =
          await FirebaseFirestore.instance
              .collection("Days")
              .doc("selected_days")
              .get();

      if (!selectedDaysDoc.exists ||
          !(selectedDaysDoc.data() as Map<String, dynamic>).values.contains(
            currentDay,
          )) {
        setState(() => scanStatus = "No event scheduled for today!");
        return;
      }

      // Get all available scans for today
      QuerySnapshot timeSnapshot =
          await FirebaseFirestore.instance.collection("time").get();

      // Find all valid scans for current time
      List<String> validScanNames = [];
      List<String> alreadyCompletedScans = [];

      for (var scanDoc in timeSnapshot.docs) {
        Map<String, dynamic> scanData = scanDoc.data() as Map<String, dynamic>;

        // Check if scan is valid for today
        bool isValidForToday =
            !scanData["isSpecial"] ||
            (scanData["specialDays"] as List<dynamic>).contains(currentDay);

        if (!isValidForToday) continue;

        // Parse scan times
        DateTime startTime = DateFormat("HH:mm").parse(scanData["start time"]);
        DateTime endTime = DateFormat("HH:mm").parse(scanData["end time"]);
        DateTime currentTimeObj = DateFormat("HH:mm").parse(currentTime);

        // Adjust all times to today for proper comparison
        startTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTime.hour,
          startTime.minute,
        );
        endTime = DateTime(
          now.year,
          now.month,
          now.day,
          endTime.hour,
          endTime.minute,
        );
        currentTimeObj = DateTime(
          now.year,
          now.month,
          now.day,
          currentTimeObj.hour,
          currentTimeObj.minute,
        );

        // Check if current time is within scan period
        if (currentTimeObj.isAfter(startTime) &&
            currentTimeObj.isBefore(endTime)) {
          validScanNames.add(scanDoc.id);
        }
      }

      if (validScanNames.isEmpty) {
        setState(() => scanStatus = "No active scan at this time");
        return;
      }

      // Get user's day document
      String userId = userSnapshot.docs.first.id;
      DocumentReference dayDocRef = FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("days")
          .doc(currentDay);

      DocumentSnapshot daySnapshot = await dayDocRef.get();
      Map<String, dynamic> updates = {};

      if (!daySnapshot.exists) {
        // If day document doesn't exist, create it with all scans set to false
        updates = Map.fromIterable(validScanNames, value: (_) => false);
        await dayDocRef.set(updates);
      } else {
        Map<String, dynamic> dayData =
            daySnapshot.data() as Map<String, dynamic>;

        // Check each valid scan
        for (String scanName in validScanNames) {
          if (!dayData.containsKey(scanName)) {
            // If scan doesn't exist in day document, add it
            updates[scanName] = false;
          } else if (dayData[scanName] == true) {
            // If scan is already completed, add to completed list
            alreadyCompletedScans.add(scanName);
          } else {
            // If scan exists but is false, mark for update
            updates[scanName] = true;
          }
        }
      }

      // If there are scans to update
      if (updates.isNotEmpty) {
        await dayDocRef.set(updates, SetOptions(merge: true));

        if (alreadyCompletedScans.isEmpty) {
          setState(
            () =>
                scanStatus =
                    "Scan successful!\nCompleted ${validScanNames.length} scans:\n${validScanNames.map((scan) => "• $scan").join("\n")}",
          );
        } else {
          setState(
            () =>
                scanStatus =
                    "New scans completed:\n${updates.keys.map((scan) => "• $scan").join("\n")}\n\nAlready completed:\n${alreadyCompletedScans.map((scan) => "• $scan").join("\n")}",
          );
        }
      } else if (alreadyCompletedScans.isNotEmpty) {
        // If all scans are already completed
        setState(
          () =>
              scanStatus =
                  "Already completed:\n${alreadyCompletedScans.map((scan) => "• $scan").join("\n")}",
        );
      }
    } catch (e) {
      print("Error during scan: $e");
      setState(() => scanStatus = "Error occurred during scan");
    } finally {
      // Re-enable scanning after 3 seconds to give more time to read longer messages
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() => isScanning = true);
        }
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
          "QR Scanner",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Scanner View
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (BarcodeCapture capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            scanCode(barcode.rawValue);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),

                // Scanner Overlay
                Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),

                // Status Message
                Positioned(
                  bottom: 100,
                  left: 20, // Add left margin
                  right: 20, // Add right margin
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: _getStatusColor(),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                scanStatus ?? "Scan a QR code",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil("homepage", (route) => false);
                },
                icon: Icon(Icons.close),
                label: Text("Close Scanner"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (scanStatus == null) return Icons.qr_code_scanner;
    if (scanStatus == "Processing...") return Icons.hourglass_empty;
    if (scanStatus == "Scan successful!") return Icons.check_circle;
    if (scanStatus == "User not found!") return Icons.error_outline;
    if (scanStatus == "Already scanned for this session!")
      return Icons.warning_amber_rounded;
    if (scanStatus == "No event scheduled for today!") return Icons.event_busy;
    if (scanStatus == "No active scan at this time") return Icons.access_time;
    if (scanStatus!.startsWith("Error")) return Icons.error_outline;
    return Icons.qr_code_scanner;
  }

  Color _getStatusColor() {
    if (scanStatus == null) return Colors.white;
    if (scanStatus == "Processing...") return Colors.blue[400]!;
    if (scanStatus == "Scan successful!") return Colors.green[400]!;
    if (scanStatus == "User not found!") return Colors.red[400]!;
    if (scanStatus == "Already scanned for this session!")
      return Colors.orange[400]!;
    if (scanStatus == "No event scheduled for today!")
      return Colors.purple[400]!;
    if (scanStatus == "No active scan at this time") return Colors.blue[400]!;
    if (scanStatus!.startsWith("Error")) return Colors.red[400]!;
    return Colors.white;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
