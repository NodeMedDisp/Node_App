import 'package:flutter/material.dart';
import 'mock_ble_service.dart';

class MockBLEScannerScreen extends StatefulWidget {
  const MockBLEScannerScreen({Key? key}) : super(key: key);

  @override
  State<MockBLEScannerScreen> createState() => _MockBLEScannerScreenState();
}

class _MockBLEScannerScreenState extends State<MockBLEScannerScreen> {
  final MockBLEService mockBLE = MockBLEService();
  List<String> deviceList = [];
  bool isScanning = false;

  void startScan() async {
    setState(() {
      isScanning = true;
      deviceList.clear();
    });

    final devices = await mockBLE.scanForDevices();
    setState(() {
      deviceList = devices;
      isScanning = false;
    });
  }

  /// Connects to the device and sends the specific patient medication data
  void connectToDevice(String deviceName, List<dynamic> patientMeds) async {
    final paired = await mockBLE.pairWithDevice(deviceName);
    if (!paired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pair with $deviceName')),
      );
      return;
    }

    // 1. Format the patient-specific data into the requested text "file" format
    String configData = _formatMedicationData(patientMeds);

    // --- TEST LINE: PRINT TO CONSOLE ---
    debugPrint("DEBUG: Sending the following config to $deviceName:\n$configData");

    // 2. Send the specific text file to the device via the BLE service
    await mockBLE.writeToDevice(configData);

    // 3. Provide feedback and return to the Provider Dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // --- TEST LINE: SHOW SNACKBAR WITH DATA PREVIEW ---
        content: Text('Sent ${patientMeds.length} medications to $deviceName!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    // This pops back to the ProviderMainScreen
    Navigator.pop(context);
  }

  /// Formats medication objects into the specific string format for the device
  String _formatMedicationData(List<dynamic> medications) {
    if (medications.isEmpty) return "No Medication Data";

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

  @override
  Widget build(BuildContext context) {
    // Extract the patient medications passed from ProviderMainScreen
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final List<dynamic> patientMeds = args?['medications'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Device'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              patientMeds.isEmpty
                  ? "Warning: No medication data to send."
                  : "Scanning for device to configure...",
              style: TextStyle(
                  color: patientMeds.isEmpty ? Colors.red : Colors.black54,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: isScanning ? null : startScan,
            icon: const Icon(Icons.search),
            label: Text(isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: deviceList.length,
              itemBuilder: (context, index) {
                final device = deviceList[index];
                return ListTile(
                  title: Text(device),
                  subtitle: const Text("Tap to pair and configure"),
                  trailing: const Icon(Icons.bluetooth_connected, color: Colors.blue),
                  onTap: () => connectToDevice(device, patientMeds),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}