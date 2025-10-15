import 'dart:async';
import 'dart:io'; // For file reading
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart'; // For locating the file
import '/GetStarted/get_started.dart';

class BLEScannerWidget extends StatefulWidget {
  const BLEScannerWidget({Key? key}) : super(key: key);

  @override
  _BLEScannerWidgetState createState() => _BLEScannerWidgetState();
}

class _BLEScannerWidgetState extends State<BLEScannerWidget> {
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice; // Track the connected device
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Request necessary Bluetooth permissions
  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      startScanning();
    } else {
      showPermissionDialog();
    }
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
              'Bluetooth and Location permissions are required to scan for BLE devices.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Start scanning for BLE devices
  void startScanning() {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return; // Ensure widget is mounted
      setState(() {
        scanResults = results;
      });
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return; // Ensure widget is mounted
      setState(() {
        isScanning = scanning;
      });
    });
  }

  // Stop scanning
  void stopScanning() {
    FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        isScanning = false;
      });
    }
  }

  // Function to connect to a BLE device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print('Connecting to ${device.platformName}');
      await device.connect();
      if (mounted) {
        setState(() {
          connectedDevice = device; // Mark the device as connected
        });
      }
      print('Connected to ${device.platformName}');
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  // Locate the file in local storage
  Future<String?> locateFile() async {
    try {
      final directory =
      await getApplicationDocumentsDirectory(); // Use path_provider to get the file directory
      final filePath = '${directory.path}/user_responses.txt';
      return filePath;
    } catch (e) {
      print('Error locating file: $e');
      return null;
    }
  }

  // Read the file's contents
  Future<String> readFile(String path) async {
    try {
      final file = File(path);
      return await file.readAsString(); // Read file content as a string
    } catch (e) {
      print('Error reading file: $e');
      return '';
    }
  }

  // Function to send the file content to the connected BLE device
  Future<void> sendFileToDevice(BluetoothDevice device) async {
    try {
      // Locate and read the file
      final filePath = await locateFile();
      if (filePath == null) {
        print("File not found.");
        return;
      }

      String fileContent = await readFile(filePath);
      if (fileContent.isEmpty) {
        print("File is empty.");
        return;
      }

      // Discover services and characteristics
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            List<int> bytes = fileContent.codeUnits;
            int chunkSize = 20; // BLE payload size is typically 20 bytes

            // Send the file content in chunks
            for (int i = 0; i < bytes.length; i += chunkSize) {
              List<int> chunk = bytes.sublist(
                  i, (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize);
              await characteristic.write(chunk, withoutResponse: false);
            }
            print('File sent successfully!');
          }
        }
      }
    } catch (e) {
      print('Error sending file: $e');
    }
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
            onPressed: startScanning, // Start scanning
          ),
        ],
      ),
      body: Column(
        children: [
          // Top banner for connected device
          if (connectedDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.green,
              child: Text(
                'Connected to: ${connectedDevice!.platformName.isNotEmpty ? connectedDevice!.platformName : "Unknown Device"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: scanResults.isEmpty
                ? Center(
              child: Text(
                isScanning
                    ? 'Scanning for devices...'
                    : 'No devices found',
                style: const TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                final isConnected =
                    connectedDevice?.remoteId == device.remoteId;

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  elevation: 3,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 15),
                        title: Text(
                          device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Unknown Device',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          device.remoteId.toString(),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: ElevatedButton(
                          onPressed: isConnected
                              ? null
                              : () => connectToDevice(device),
                          child: Text(
                              isConnected ? 'Connected' : 'Connect'),
                        ),
                      ),
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GetStartedPage(device: device),
                                    ),
                                  );
                                },
                                child: const Text('Configure Device'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () =>
                                    sendFileToDevice(device),
                                child: const Text('Receive Data'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? stopScanning : startScanning,
        child: Icon(isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}
