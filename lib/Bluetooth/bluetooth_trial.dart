import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../LoginComp/logic/provider/provider_cubit.dart'; // Accessing the Cubit
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class BLEScannerWidget extends StatefulWidget {
  const BLEScannerWidget({Key? key}) : super(key: key);

  @override
  _BLEScannerWidgetState createState() => _BLEScannerWidgetState();
}

class _BLEScannerWidgetState extends State<BLEScannerWidget> {
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  /// NEW: Simulates a successful data transfer from a device without using Bluetooth hardware
  void simulateFakeImport() {
    // This is the EXACT format the hardware will eventually send
    String fakeDeviceData = """
Medication: Buprenorphine
Dose: 8mg
Frequency: Daily
Times: 9:00 AM, 9:00 PM
Days: 0 to 45
-------------------
Medication: Naloxone
Dose: 2mg
Frequency: As Needed
Times: 12:00 PM
Days: 0 to 14
-------------------
""";

    debugPrint("DEBUG: Simulating import of fake device data...");

    // Use our existing parser
    List<Map<String, dynamic>> parsedMeds = _parseIncomingData(fakeDeviceData);

    if (parsedMeds.isNotEmpty) {
      context.read<ProviderCubit>().importPatientFromDevice(
        deviceName: "Simulated-NODE-01",
        medications: parsedMeds,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Simulated Import Successful!"),
          backgroundColor: Colors.orange,
        ),
      );

      // Return to dashboard to see the new patient
      Navigator.pop(context);
    }
  }

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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void startScanning() {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        scanResults = results;
      });
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() {
        isScanning = scanning;
      });
    });
  }

  void stopScanning() {
    FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('Connecting to ${device.platformName}');
      await device.connect();
      if (mounted) {
        setState(() {
          connectedDevice = device;
        });
      }
    } catch (e) {
      debugPrint('Error connecting to device: $e');
    }
  }

  /// Formats the Patient Medication objects into a text string
  String _formatMedicationData(List<dynamic> medications) {
    if (medications.isEmpty) return "No Medication Data Found";

    StringBuffer buffer = StringBuffer();
    for (var med in medications) {
      buffer.writeln("Medication: ${med.name}");
      buffer.writeln("Dose: ${med.dose}");
      buffer.writeln("Frequency: ${med.frequency}");
      buffer.writeln("Times: ${med.times}");
      buffer.writeln("Days: 0 to ${med.numDays}");
      buffer.writeln("-------------------");
    }
    return buffer.toString();
  }

  /// Sends the specific patient configuration to the device
  Future<void> sendPatientConfigToDevice(BluetoothDevice device, List<dynamic> patientMeds) async {
    try {
      String fileContent = _formatMedicationData(patientMeds);

      debugPrint("DEBUG: Sending Patient Config:\n$fileContent");

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            List<int> bytes = fileContent.codeUnits;
            int chunkSize = 20;

            for (int i = 0; i < bytes.length; i += chunkSize) {
              List<int> chunk = bytes.sublist(
                  i, (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize);
              await characteristic.write(chunk, withoutResponse: false);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Device Configured Successfully!"), backgroundColor: Colors.green),
            );

            Navigator.pop(context);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error sending configuration: $e');
    }
  }

  /// Parses a text string from the device back into Medication objects
  List<Map<String, dynamic>> _parseIncomingData(String data) {
    List<Map<String, dynamic>> newMeds = [];
    List<String> entries = data.split("-------------------");

    for (var entry in entries) {
      if (entry.trim().isEmpty) continue;

      Map<String, dynamic> med = {};
      List<String> lines = entry.trim().split("\n");

      for (var line in lines) {
        if (line.contains("Medication:")) med['name'] = line.split(":")[1].trim();
        if (line.contains("Dose:")) med['dose'] = line.split(":")[1].trim();
        if (line.contains("Frequency:")) med['frequency'] = line.split(":")[1].trim();
        if (line.contains("Times:")) med['times'] = line.split(":")[1].trim();
        if (line.contains("Days:")) {
          String daysPart = line.split(":")[1].trim();
          med['numDays'] = int.tryParse(daysPart.split("to").last.trim()) ?? 0;
        }
      }
      if (med.containsKey('name')) newMeds.add(med);
    }
    return newMeds;
  }

  /// Receives data from device and creates a new patient (Hardware implementation)
  Future<void> receiveDataAndCreatePatient(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      String receivedText = "";

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Property safety check to avoid PlatformException
          if (characteristic.properties.read) {
            List<int> value = await characteristic.read();
            receivedText = String.fromCharCodes(value);

            if (receivedText.isNotEmpty) {
              List<Map<String, dynamic>> parsedMeds = _parseIncomingData(receivedText);

              if (parsedMeds.isNotEmpty) {
                context.read<ProviderCubit>().importPatientFromDevice(
                    deviceName: device.platformName.isNotEmpty ? device.platformName : "New Device",
                    medications: parsedMeds
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New Patient Imported!"), backgroundColor: Colors.blue),
                );
                Navigator.pop(context);
                return;
              }
            }
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No readable data found on this device.")),
      );
    } catch (e) {
      debugPrint('Error receiving data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final List<dynamic> patientMeds = args?['medications'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Configuration'),
      ),
      body: Column(
        children: [
          // TEST SECTION: Simulated Import (Bypasses Bluetooth errors)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.orange.withOpacity(0.1),
            child: Column(
              children: [
                const Text(
                  "Testing Mode",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.science),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: simulateFakeImport,
                    label: const Text("Simulate Device Import"),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (connectedDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.blueAccent,
              child: Text(
                'Ready to configure: ${connectedDevice!.platformName.isNotEmpty ? connectedDevice!.platformName : "Device"}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: scanResults.isEmpty
                ? Center(child: Text(isScanning ? 'Scanning for devices...' : 'No devices found'))
                : ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                final isConnected = connectedDevice?.remoteId == device.remoteId;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: ElevatedButton(
                          onPressed: isConnected ? null : () => connectToDevice(device),
                          child: Text(isConnected ? 'Connected' : 'Connect'),
                        ),
                      ),
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.upload),
                                  onPressed: () => sendPatientConfigToDevice(device, patientMeds),
                                  label: const Text('Configure Selected Patient'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => receiveDataAndCreatePatient(device),
                                  label: const Text('Import Patient from Device'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                ),
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
