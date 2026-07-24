import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'enter_counseling_data.dart';
import 'custom_plan_screen.dart';
import 'summary_screen.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Import FlutterBluePlus
import '../models/medication.dart';
import '../models/counseling_question.dart';

class CounselingQuestionScreen extends StatefulWidget {
  final List<Medication> medications;
  final BluetoothDevice? device;

  const CounselingQuestionScreen({
    super.key,
    required this.medications,
    this.device,
  });

  @override
  _CounselingQuestionScreenState createState() =>
      _CounselingQuestionScreenState();
}

class _CounselingQuestionScreenState extends State<CounselingQuestionScreen> {
  String? _selectedOption;

  // Function to save the response to a file
  Future<void> _saveResponseToFile(String response) async {
    // Fast path for web
    if (kIsWeb) {
      // Optionally persist to localStorage here if desired
      print("Web mode: skipping file write for counseling response.");
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');
      await file.writeAsString(
        'Mental Health Counseling: $response\n',
        mode: FileMode.append,
      );
    } on MissingPluginException catch (e) {
      // Plugin not registered for this platform — skip gracefully
      print(
          'MissingPluginException while saving response: $e — skipping file write.');
      return;
    } on PlatformException catch (e) {
      // Platform channel error — log and continue
      print('PlatformException while saving response: $e');
      return;
    } catch (e, st) {
      // Any other unexpected error — log for debugging but don't block navigation
      print('Unexpected error saving response: $e\n$st');
      return;
    }
  }

  void _handleContinue() async {
    if (_selectedOption == null) return;

    // Ensure saving errors don't block navigation
    await _saveResponseToFile(_selectedOption!);

    if (_selectedOption == 'Yes') {
      debugPrint(
        'TRACE 4 COUNSELING CHOICE -> NEXT: ${widget.device?.remoteId}',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnterCounselingPrompts(
              medications: widget.medications, device: widget.device),
        ),
      );
    } else if (_selectedOption == 'No counseling') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoCounselingScreen(
              medications: widget.medications, device: widget.device),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mental Health Counseling")),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Does the patient have a mental health counseling plan?",
              style: TextStyle(fontSize: 18.sp),
            ),
            SizedBox(height: 20.h),
            _buildOptionButton(
                "Yes, the counselor will enter daily prompts.", "Yes"),
            SizedBox(height: 20.h),
            _buildOptionButton(
                "No, the patient does not have a mental health counseling plan",
                "No counseling"),
            SizedBox(height: 20.h),
            if (_selectedOption != null)
              ElevatedButton(
                onPressed: _handleContinue,
                child: Text(
                  "Continue",
                  style: TextStyles.font14Hint500Weight
                      .copyWith(color: ColorsManager.mainBlue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the option buttons
  Widget _buildOptionButton(String optionText, String value) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedOption = value;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedOption == value
            ? ColorsManager.mainBlue
            : Colors.grey[300], // Highlight selected option
        minimumSize: Size(double.infinity, 50.h), // Full-width button
      ),
      child: Text(
        optionText,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}

class NoCounselingScreen extends StatelessWidget {
  final List<Medication> medications;
  final BluetoothDevice? device;
  final List<CounselingQuestion> prompts = []; // Empty activities list

  NoCounselingScreen({super.key, required this.medications, this.device});

  @override
  Widget build(BuildContext context) {
    // Instead of asking for confirmation, go directly to RecoverySummaryScreen
    return RecoverySummaryScreen(
      medications: medications,
      prompts: prompts,
      device: device,
    );
  }
}
