import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Add permission handler

class BleScanner extends StatefulWidget {
  @override
  _BleScannerState createState() => _BleScannerState();
}

class _BleScannerState extends State<BleScanner> {
  List<String> devicelist = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void dispose() {
    scanSubscription
        ?.cancel(); // Cancel the scan subscription to avoid memory leaks
    super.dispose();
  }

  // Function to request necessary permissions
  Future<void> requestPermissions() async {
    try {
      // Request Bluetooth and location permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.bluetoothAdvertise,
      ].request();

      // Check if all permissions are granted
      if (statuses.values.every((status) => status.isGranted)) {
        // All permissions are granted, start scanning
        print("Permissions granted.");
        startScanning();
      } else {
        // Some permissions are denied
        print("Some permissions are denied.");
        showPermissionDialog(); // Show a dialog to notify the user about denied permissions
      }
    } catch (e) {
      print("Error while requesting permissions: $e");
    }
  }

  // Function to show a dialog when permissions are denied
  void showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions Required'),
          content: Text(
              'Bluetooth and location permissions are required to scan for devices.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings(); // Opens app settings to allow user to manually enable permissions
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Function to start scanning for Bluetooth devices
  void startScanning() async {
    try {
      setState(() {
        isScanning = true;
        devicelist.clear(); // Clear the device list before scanning
      });

      print("Starting scan for 10 seconds...");

      // Start scanning for 10 seconds
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Listen for scan results and handle them
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          try {
            // Ensure the device has a name (platformName) and is not already in the list
            if (!devicelist.contains(result.device.platformName) &&
                result.device.platformName.isNotEmpty) {
              if (mounted) {
                // Ensure the widget is still mounted before calling setState
                setState(() {
                  devicelist.add(result.device
                      .platformName); // Add device platformName to the list
                });
              }
              print(
                  "Device found: ${result.device.platformName}"); // Print device platformName
            }
          } catch (e) {
            // Log any errors that occur while processing the scan results
            print("Error while processing scan result: $e");
          }
        }

        // Log if no devices were found
        if (results.isEmpty) {
          print("No devices found.");
        }
      });

      // Stop scanning when done
      FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning) {
          if (mounted) {
            setState(() {
              this.isScanning =
                  false; // Ensure the UI reflects the scanning state
            });
          }
        }
      });
    } catch (e) {
      // Catch any errors in the scanning process itself
      print("Error in scanning: $e");
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  void stopScanning() async {
    try {
      bool isCurrentlyScanning = await FlutterBluePlus.isScanning.first;

      if (isCurrentlyScanning) {
        print("Stopping scan...");
        await FlutterBluePlus.stopScan();
        if (mounted) {
          setState(() {
            isScanning = false;
          });
        }
        print("Scan stopped.");
      } else {
        print("Scan is already stopped.");
      }
    } catch (e) {
      // Catch any errors during the stopping scan process
      print("Error while stopping scan: $e");
    }
  }

  @override
  void initState() {
    print('initiating a new state');
    super.initState();
    requestPermissions(); // Request permissions when the app starts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          isScanning
              ? IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: stopScanning, // Stop scanning
                )
              : IconButton(
                  icon: const Icon(Icons.search),
                  onPressed:
                      requestPermissions, // Check permissions before scanning
                ),
        ],
      ),
      body: devicelist.isEmpty && !isScanning
          ? Center(
              child: Text(
                'No devices found', // Show this only when the scan is not happening
                style: const TextStyle(fontSize: 18),
              ),
            )
          : isScanning
              ? Center(
                  child: Text(
                    'Scanning for devices...', // Show this when scanning is active
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: devicelist.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(devicelist[index]),
                    );
                  },
                ),
      floatingActionButton: isScanning
          ? FloatingActionButton(
              onPressed: stopScanning,
              child: const Icon(Icons.stop),
            )
          : FloatingActionButton(
              onPressed:
                  requestPermissions, // Check permissions before scanning
              child: const Icon(Icons.search),
            ),
    );
  }
}
