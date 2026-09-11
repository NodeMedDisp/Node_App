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
import '../Bluetooth/recovery_program_file_formatter.dart';
import '../Bluetooth/node_ble_file_transfer_service.dart';

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

  Future<String> _saveDataToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');

      final fileContent = RecoveryProgramFileFormatter.build(
        medications: widget.medications,
        prompts: widget.prompts,
      );

      await file.writeAsString(
        fileContent,
        mode: FileMode.write,
        flush: true,
      );

      debugPrint('Recovery program saved at: ${file.path}');
      debugPrint('========== SAVED FILE CONTENTS ==========');
      debugPrint(fileContent);
      debugPrint('========== END SAVED FILE CONTENTS ==========');

      return fileContent;
    } catch (error, stackTrace) {
      debugPrint('Error saving recovery program: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> sendFileToDevice(
    BluetoothDevice device,
    String fileContent,
  ) {
    return const NodeBleFileTransferService().send(
      device: device,
      fileContents: fileContent,
    );
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
              final fileContent = await _saveDataToFile();
              print("SUMMARY DEVICE: ${widget.device?.remoteId}");

              if (widget.device != null) {
                print(
                    "BLE mode: sending file to connected device ${widget.device!.remoteId}");
                await sendFileToDevice(widget.device!, fileContent);
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
