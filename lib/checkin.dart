import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CheckinPage extends StatefulWidget {
  @override
  State<CheckinPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<CheckinPage> {
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
      CollectionReference userRef = FirebaseFirestore.instance.collection("users");
      QuerySnapshot querySnapshot = await userRef
          .where("qr", isEqualTo: qrString)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          String docId = doc.id;
          dynamic currentValue = doc.get("checkin");
          if (currentValue == true) {
            setState(() => scanStatus = "Already scanned for this session!");
            return;
          } else {
            String currentDate = DateFormat("yyyy-MM-dd").format(DateTime.now());
            String currentTime = DateFormat("HH-mm").format(DateTime.now());
            await userRef.doc(docId).update({
              "checkin": true,
              "check day": currentDate,
              "check time": currentTime,
            });

            setState(() => scanStatus = "Scan successful!");
            return;
          }
        }
      } else {
        setState(() => scanStatus = "User not found!");
        return;
      }
    } catch (e) {
      setState(() => scanStatus = "Error: ${e.toString()}");
    } finally {
      Future.delayed(Duration(seconds: 1), () {
        setState(() => isScanning = true);
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
          "Check-in Scanner",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
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
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
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
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),

                // Status Message
                Positioned(
                  bottom: 100,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          scanStatus == "Scan successful!"
                              ? Icons.check_circle
                              : scanStatus == "User not found!"
                                  ? Icons.error_outline
                                  : scanStatus == "Already scanned for this session!"
                                      ? Icons.warning_amber_rounded
                                      : Icons.qr_code_scanner,
                          color: scanStatus == "Scan successful!"
                              ? Colors.green[400]
                              : scanStatus == "User not found!"
                                  ? Colors.red[400]
                                  : scanStatus == "Already scanned for this session!"
                                      ? Colors.orange[400]
                                      : Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          scanStatus ?? "Scan a QR code",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    "homepage",
                    (route) => false,
                  );
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
