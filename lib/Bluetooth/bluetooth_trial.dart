import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';


class BLEScannerWidget extends StatefulWidget {
  const BLEScannerWidget({super.key});

  @override
  State<BLEScannerWidget> createState() => _BLEScannerWidgetState();
}

class _BLEScannerWidgetState extends State<BLEScannerWidget> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  StreamSubscription<List<ScanResult>>? scanResultsSubscription;
  StreamSubscription<bool>? isScanningSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkPermissionsThenStartScan();
    });
  }

/*
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
    final parsedMeds = _parseIncomingData(fakeDeviceData);

    if (parsedMeds.isNotEmpty) {
      context.read<ProviderCubit>().importPatientFromDevice(
        displayName: "Simulated NODE Patient",
        deviceId: "Simulated-NODE-01",
        medications: parsedMeds,
        prompts: const [],
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
  */

  Future<void> checkPermissionsThenStartScan() async {
    final hasPermissions = await requestBluetoothPermissions();

    if (!mounted) return;

    if (hasPermissions) {
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

  Future<void> startScanning() async {
      final adapterState = await FlutterBluePlus.adapterState.first;

      debugPrint("DEBUG: Bluetooth adapter state: $adapterState");

      if (adapterState != BluetoothAdapterState.on) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please turn Bluetooth on.")),
        );
        return;
      }

      await scanResultsSubscription?.cancel();
      await isScanningSubscription?.cancel();

      scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        debugPrint("DEBUG: Scan results count: ${results.length}");

        for (final result in results) {
          debugPrint(
            "DEBUG: Found device: "
            "platformName='${result.device.platformName}', "
            "advName='${result.advertisementData.advName}', "
            "remoteId='${result.device.remoteId}', "
            "rssi='${result.rssi}', "
            "serviceUuids='${result.advertisementData.serviceUuids}'",
          );
        }

        if (!mounted) return;

        setState(() {
          scanResults = results;
        });
      });

      isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (!mounted) return;

        setState(() {
          isScanning = scanning;
        });
      });

      if (!mounted) return;

      setState(() {
        isScanning = true;
        scanResults.clear();
      });

      debugPrint("DEBUG: Starting BLE scan...");
      debugPrint("SCAN: ${await Permission.bluetoothScan.status}");
      debugPrint("CONNECT: ${await Permission.bluetoothConnect.status}");
      debugPrint("ADVERTISE: ${await Permission.bluetoothAdvertise.status}");

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
      );
    }
  

  void stopScanning() {
    FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    scanResultsSubscription?.cancel();
    isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    final hasPermissions = await requestBluetoothPermissions();

    if (!mounted) return;

    if (!hasPermissions) {
      showPermissionDialog();
      return;
    }

    try {
      debugPrint(
        'BLE SCANNER: Connecting to '
        '${device.platformName} (${device.remoteId})',
      );

      await FlutterBluePlus.stopScan();
      await device.connect();

      if (!mounted) return;

      debugPrint(
        'BLE SCANNER: Connected. Returning device '
        '${device.remoteId}',
      );

      Navigator.pop(context, device);
    } catch (e) {
      debugPrint('BLE SCANNER: Connection failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect to device: $e'),
        ),
      );
    }
  }

/*
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
  List<Medication> _parseIncomingData(String data) {
    final List<Medication> newMeds = [];
    final List<String> entries = data.split("-------------------");

    String valueAfterColon(String line) {
      final colonIndex = line.indexOf(':');

      if (colonIndex == -1) {
        return '';
      }

      return line.substring(colonIndex + 1).trim();
    }

    for (final entry in entries) {
      if (entry.trim().isEmpty) {
        continue;
      }

      String name = '';
      String dose = '';
      String frequency = '';
      String times = '';
      int numDays = 0;

      final List<String> lines = entry.trim().split('\n');

      for (final line in lines) {
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('Medication:')) {
          name = valueAfterColon(trimmedLine);
        } else if (trimmedLine.startsWith('Dose:')) {
          dose = valueAfterColon(trimmedLine);
        } else if (trimmedLine.startsWith('Frequency:')) {
          frequency = valueAfterColon(trimmedLine);
        } else if (trimmedLine.startsWith('Times:')) {
          times = valueAfterColon(trimmedLine);
        } else if (trimmedLine.startsWith('Days:')) {
          final daysPart = valueAfterColon(trimmedLine);

          numDays =
              int.tryParse(
                daysPart.split('to').last.trim(),
              ) ??
              0;
        }
      }

      if (name.isNotEmpty) {
        newMeds.add(
          Medication(
            name: name,
            dose: dose,
            frequency: frequency,
            times: times,
            numDays: numDays,
          ),
        );
      }
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
              final List<Medication> parsedMeds =_parseIncomingData(fakeDeviceData);

              if (parsedMeds.isNotEmpty) {
                context.read<ProviderCubit>().importPatientFromDevice(
                displayName:
                    device.platformName.isNotEmpty
                        ? device.platformName
                        : "New Patient",
                deviceId: device.remoteId.toString(),
                medications: parsedMeds,
                prompts: const [],
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
  */

  ///Request Bluetooth
  Future<bool> requestBluetoothPermissions() async {
      if (!Platform.isAndroid) {
        return true;
      }

      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ].request();

      final bluetoothScanGranted =
          statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final bluetoothConnectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted =
          statuses[Permission.locationWhenInUse]?.isGranted ?? false;

      debugPrint("SCAN: ${statuses[Permission.bluetoothScan]}");
      debugPrint("CONNECT: ${statuses[Permission.bluetoothConnect]}");
      debugPrint("ADVERTISE: ${statuses[Permission.bluetoothAdvertise]}");
      debugPrint("LOCATION: ${statuses[Permission.locationWhenInUse]}");

      return bluetoothScanGranted && bluetoothConnectGranted && locationGranted;
    }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Configuration'),
      ),
      body: Column(
        children: [
          // TEST SECTION: Simulated Import (Bypasses Bluetooth errors)
          /*
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
          */
          const Divider(height: 1),

/*
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
            */
          Expanded(
            child: scanResults.isEmpty
                ? Center(child: Text(isScanning ? 'Scanning for devices...' : 'No devices found'))
                : ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                //final isConnected = connectedDevice?.remoteId == device.remoteId;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(
                      device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device',
                    ),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: ElevatedButton(
                      onPressed: () => connectToDevice(device),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? stopScanning : checkPermissionsThenStartScan,
        child: Icon(isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}

