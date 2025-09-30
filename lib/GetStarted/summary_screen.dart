import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '/../HomePage/home_page.dart';
import '/../HomePage/calendar_widg.dart';  // Import the new CalendarWidget file
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:intl/intl.dart'; // For date and time formatting

class RecoverySummaryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> prompts;
  final List<Map<String, String>> medications;
  final BluetoothDevice? device;

  const RecoverySummaryScreen({
    super.key,
    required this.prompts,
    required this.medications,
    this.device,
  });

  @override
  _RecoverySummaryScreenState createState() => _RecoverySummaryScreenState();
}

class _RecoverySummaryScreenState extends State<RecoverySummaryScreen> {
  DateTime StartDate = DateTime.now(); // Default surgery date

  // Save the prompts and medications to a file
  Future<void> _saveDataToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');

      // Function to get current time in a specific format
      String getCurrentTime() {
        final now = DateTime.now();
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      }

      // Add current time to the file
      final currentTime = getCurrentTime();
      await file.writeAsString('Current Time: $currentTime\n', mode: FileMode.write);

      // Save medications
      for (var medication in widget.medications) {
        await file.writeAsString(
          '\nMedication: ${medication["medication"]}\nDose: ${medication["dose"]}\nFrequency: ${medication["frequency"]}\n'
              'Times: ${medication["times"]}\n'
              'Days: ${medication["startDay"]} to ${medication["endDay"]}\n',
          mode: FileMode.append,
        );
      }

      // Save prompts with
      for (var prompt in widget.prompts) {
        final options = prompt.containsKey('options') && prompt['options'] != null
            ? (prompt['options'] as List<String>).join(', ')
            : 'No options';

        await file.writeAsString(
          '\nPrompt: ${prompt["prompt"]}\n'
              'Required Response: ${prompt["resReq"]}\n'
              'Options: $options\n'
              'Days: ${prompt["startDay"]} to ${prompt["endDay"]}\n',
          mode: FileMode.append,
        );
      }

      // End of file marker
      await file.writeAsString('EOF\n', mode: FileMode.append);
      print('Data saved to file successfully!');
    } catch (e) {
      print('Error saving data to file: $e');
    }
  }

  // Locate the file in local storage
  Future<String?> locateFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();  // Use path_provider to get the file directory
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
      return await file.readAsString();  // Read file content as a string
    } catch (e) {
      print('Error reading file: $e');
      return '';
    }
  }

  // Function to send the file content to the connected BLE device
  Future<void> sendFileToDevice(BluetoothDevice device) async {
    try {
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

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            List<int> bytes = fileContent.codeUnits;
            int chunkSize = 20;  // BLE payload size is typically 20 bytes

            for (int i = 0; i < bytes.length; i += chunkSize) {
              List<int> chunk = bytes.sublist(i, (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize);
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
      appBar: AppBar(title: const Text("Recovery Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              // Use the new CalendarWidget here to display the calendar with prompts and medications
              child: CalendarWidget(
                prompts: widget.prompts,
                medications: widget.medications,
                StartDate: StartDate,  // Pass surgery date here
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await _saveDataToFile();   // Save the data
              if (widget.device != null) {
                await sendFileToDevice(widget.device!); // Send to real BLE device
              } else {
                print("Mock mode: skipping BLE transmission");
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    prompts: widget.prompts,
                    medications: widget.medications,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.white,  // Customize as needed
            ),
            child: const Text(
              "Send to Device and Continue",
              style: TextStyle(color: ColorsManager.mainBlue),
            ),
          ),
        ),
      ),
    );
  }
}
