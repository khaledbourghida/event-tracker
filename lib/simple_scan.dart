import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleScanPage extends StatefulWidget {
  @override
  State<SimpleScanPage> createState() => _SimpleScanPageState();
}

class _SimpleScanPageState extends State<SimpleScanPage> {
  bool isScanning = true;
  String? userName;
  String? scanStatus;
  MobileScannerController controller = MobileScannerController();

  Future<void> scanCode(String? qrString) async {
    if (!isScanning || qrString == null) return;

    setState(() {
      isScanning = false;
      scanStatus = "Processing...";
    });

    try {
      // Check if user exists
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("qr", isEqualTo: qrString)
          .get();

      if (userSnapshot.docs.isEmpty) {
        setState(() {
          scanStatus = "User not found!";
          userName = null;
        });
        return;
      }

      // Get user name
      setState(() {
        userName = userSnapshot.docs.first["name"];
        scanStatus = "User found!";
      });

    } catch (e) {
      print("Error during scan: $e");
      setState(() {
        scanStatus = "Error occurred during scan";
        userName = null;
      });
    } finally {
      // Re-enable scanning after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
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
          "Simple Scanner",
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

                // User Name Display
                if (userName != null)
                  Positioned(
                    bottom: 160,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        children: [
                          Text(
                            "User Name",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            userName!,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                          _getStatusIcon(),
                          color: _getStatusColor(),
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
    if (scanStatus == "User found!") return Icons.check_circle;
    if (scanStatus == "User not found!") return Icons.error_outline;
    if (scanStatus!.startsWith("Error")) return Icons.error_outline;
    return Icons.qr_code_scanner;
  }

  Color _getStatusColor() {
    if (scanStatus == null) return Colors.white;
    if (scanStatus == "Processing...") return Colors.blue[400]!;
    if (scanStatus == "User found!") return Colors.green[400]!;
    if (scanStatus == "User not found!") return Colors.red[400]!;
    if (scanStatus!.startsWith("Error")) return Colors.red[400]!;
    return Colors.white;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
} 