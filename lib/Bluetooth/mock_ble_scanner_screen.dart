import 'package:flutter/material.dart';
import 'package:node_app_2/Bluetooth/mock_ble_service.dart';
import 'mock_ble_service.dart'; // Adjust import path as needed

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

  void connectToDevice(String deviceName) async {
    final paired = await mockBLE.pairWithDevice(deviceName);
    if (!paired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pair with $deviceName')),
      );
      return;
    }

    final prompts = await mockBLE.fetchPrompts();
    final medications = await mockBLE.fetchMedications();

    Navigator.pushNamed(
      context,
      '/home', // Replace with your actual route
      arguments: {
        'deviceName': deviceName,
        'prompts': prompts,
        'medications': medications,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mock BLE Scanner')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: deviceList.length,
              itemBuilder: (context, index) {
                final device = deviceList[index];
                return ListTile(
                  title: Text(device),
                  trailing: Icon(Icons.bluetooth),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}