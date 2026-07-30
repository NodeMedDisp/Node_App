import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
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

  void _appendRewardSection(
    StringBuffer buffer, {
    required String sectionName,
    required bool enabled,
    required String title,
    required String threshold,
    int? quantity,
  }) {
    buffer.writeln('$sectionName: ${enabled ? 'Yes' : 'No'}');

    if (!enabled) {
      return;
    }

    buffer.writeln('Title: ${title.trim()}');

    final normalizedThreshold = threshold.trim().isEmpty
        ? 'None'
        : threshold.trim();

    buffer.writeln('Threshold: $normalizedThreshold');

    if (sectionName == 'Token') {
      buffer.writeln('Quantity: ${quantity ?? 0}');
    }
  }

  Future<void> _saveDataToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');

      final currentTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final buffer = StringBuffer();

      buffer.writeln('Current Time: $currentTime');
      buffer.writeln();

      for (final medication in widget.medications) {
        buffer.writeln('Medication: ${medication.name}');
        buffer.writeln('Dose: ${medication.dose}');
        buffer.writeln('Frequency: ${medication.frequency}');
        buffer.writeln('Times: ${medication.times}');
        buffer.writeln('Days: 1 to ${medication.numDays}');

        _appendRewardSection(
          buffer,
          sectionName: 'Streak',
          enabled: medication.streakEnabled,
          title: medication.streakTitle,
          threshold: medication.streakThreshold,
        );

        _appendRewardSection(
          buffer,
          sectionName: 'Token',
          enabled: medication.tokenEnabled,
          title: medication.tokenTitle,
          threshold: medication.tokenThreshold,
          quantity: medication.tokenQuantity,
        );

        // Blank line ends this medication block.
        buffer.writeln();
      }

      for (final prompt in widget.prompts) {
        buffer.writeln('Prompt: ${prompt.prompt}');
        buffer.writeln('Required Response: ${prompt.resReq}');
        buffer.writeln('Options: ${prompt.options.join(', ')}');
        buffer.writeln('Days: 1 to ${prompt.numberOfDays}');

        _appendRewardSection(
          buffer,
          sectionName: 'Streak',
          enabled: prompt.streakEnabled,
          title: prompt.streakTitle,
          threshold: prompt.streakThreshold,
        );

        _appendRewardSection(
          buffer,
          sectionName: 'Token',
          enabled: prompt.tokenEnabled,
          title: prompt.tokenTitle,
          threshold: prompt.tokenThreshold,
          quantity: prompt.tokenQuantity,
        );

        // Blank line ends this prompt block.
        buffer.writeln();
      }

      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.write,
        flush: true,
      );

      debugPrint('File saved at: ${file.path}');

      final savedText = await file.readAsString();

      debugPrint('========== SAVED FILE CONTENTS ==========');
      debugPrint(savedText);
      debugPrint('========== END SAVED FILE CONTENTS ==========');
    } catch (error, stackTrace) {
      debugPrint('Error saving data to file: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
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
            // EOF is a BLE transport marker. It is not stored in the
            // clean local configuration file.
            final payload = '${fileContent.trimRight()}\nEOF\n';

            final List<int> bytes = utf8.encode(payload);
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
