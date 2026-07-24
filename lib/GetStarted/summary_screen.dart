import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../HomePage/home_page.dart';
import '../HomePage/calendar_widg.dart';
import '../LoginComp/routing/routes.dart';
import '../LoginComp/theming/colors.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../models/counseling_question.dart';

class RecoverySummaryScreen extends StatefulWidget {
  final List<CounselingQuestion> prompts;
  final List<Medication> medications;
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
  DateTime StartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    debugPrint(
      'TRACE 6 SUMMARY RECEIVED DEVICE: ${widget.device?.remoteId}',
    );
  }

  Future<void> _saveDataToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');
      print('File saved at: ${file.path}');

      String getCurrentTime() {
        final now = DateTime.now();
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      }

      final currentTime = getCurrentTime();
      await file.writeAsString('Current Time: $currentTime\n',
          mode: FileMode.write);

      for (var medication in widget.medications) {
        await file.writeAsString(
          '\nMedication: ${medication.name}\nDose: ${medication.dose}\nFrequency: ${medication.frequency}\n'
          'Times: ${medication.times}\n'
          'Days: ${medication.numDays}\n',
          mode: FileMode.append,
        );
      }

      for (var prompt in widget.prompts) {
        final options = prompt.options.join(', ');

        await file.writeAsString(
          '\nPrompt: ${prompt.prompt}\n'
          'Required Response: ${prompt.resReq}\n'
          'Options: $options\n'
          'Days: ${prompt.numberOfDays}\n',
          mode: FileMode.append,
        );
      }

      await file.writeAsString('EOF\n', mode: FileMode.append);
      print('Data saved to file successfully!');

      final savedText = await file.readAsString();

      debugPrint("========== SAVED FILE CONTENTS ==========");
      debugPrint(savedText);
      debugPrint("========== END SAVED FILE CONTENTS ==========");
    } catch (e) {
      print('Error saving data to file: $e');
    }
  }

  Future<void> sendFileToDevice(BluetoothDevice device) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');
      if (!await file.exists()) {
        print("File not found.");
        return;
      }

      String fileContent = await file.readAsString();
      if (fileContent.isEmpty) {
        print("File is empty.");
        return;
      }

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            List<int> bytes = fileContent.codeUnits;
            int chunkSize = 20;

            for (int i = 0; i < bytes.length; i += chunkSize) {
              List<int> chunk = bytes.sublist(
                  i,
                  (i + chunkSize > bytes.length)
                      ? bytes.length
                      : i + chunkSize);
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
              child: CalendarWidget(
                prompts: widget.prompts,
                medications: widget.medications,
                StartDate: StartDate,
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
              await _saveDataToFile();
              print("SUMMARY DEVICE: ${widget.device?.remoteId}");

              if (widget.device != null) {
                print(
                    "BLE mode: sending file to connected device ${widget.device!.remoteId}");
                await sendFileToDevice(widget.device!);
              } else {
                print(
                    "ERROR: No BluetoothDevice was passed into RecoverySummaryScreen.");
                print(
                    "BLE transmission skipped because widget.device is null.");
              }

              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.homeScreen,
                (route) => false,
                arguments: {
                  'prompts': widget.prompts,
                  'medications': widget.medications,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.white,
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
