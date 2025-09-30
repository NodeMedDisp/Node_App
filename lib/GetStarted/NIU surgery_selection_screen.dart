/*
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'prescription_question_screen.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';

class SurgerySelectionScreen extends StatefulWidget {
  const SurgerySelectionScreen({super.key});

  @override
  _SurgerySelectionScreenState createState() => _SurgerySelectionScreenState();
}

class _SurgerySelectionScreenState extends State<SurgerySelectionScreen> {
  String? selectedSurgery;

  // Save the selected response
  Future<void> _saveResponseToFile(String response) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_responses.txt');
      await file.writeAsString('Surgery: $response\n', mode: FileMode.write);
    } catch (e) {
      print('Error saving response: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> surgeryOptions = [
      'Hip Replacement',
      'Knee Replacement',
      'None, I just want to stay healthy',
      'Other'
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Surgery Selection')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "What surgery did you receive?",
                style: TextStyle(fontSize: 18.sp),
              ),
              Gap(20.h),
              for (String optionText in surgeryOptions)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedSurgery = optionText;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedSurgery == optionText
                          ? ColorsManager.mainBlue // Highlight selected option
                          : Colors.grey[300], // Default color
                      foregroundColor: Colors.black, // Text color
                      minimumSize: Size(double.infinity, 50.h), // Full-width
                      side: BorderSide(
                        color: selectedSurgery == optionText
                            ? Colors.blueAccent // Border for selected
                            : Colors.grey, // Border for unselected
                      ),
                    ),
                    child: Text(optionText),
                  ),
                ),
              Gap(20.h),
              // Continue Button, shown only if an option is selected
              if (selectedSurgery != null)
                ElevatedButton(
                  onPressed: () {
                    _saveResponseToFile(selectedSurgery!);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrescriptionQuestionScreen(selectedSurgery: selectedSurgery!),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                    backgroundColor: Colors.white,
                  ),
                  child: Text(
                      'Continue',
                  style:
                      TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
*/