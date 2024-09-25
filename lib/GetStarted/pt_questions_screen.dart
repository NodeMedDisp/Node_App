import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'enter_pt_data.dart';
import 'enter_prescription_data.dart';
import 'custom_plan_screen.dart';
import 'package:node_app_2/HomePage/home_page.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';


class PhysicalTherapyQuestionScreen extends StatefulWidget {
  final List<Map<String, String>> medications;
  PhysicalTherapyQuestionScreen({required this.medications});

  @override
  _PhysicalTherapyQuestionScreenState createState() =>
      _PhysicalTherapyQuestionScreenState();
}

class _PhysicalTherapyQuestionScreenState
    extends State<PhysicalTherapyQuestionScreen> {
  String? _selectedOption;
  List<String> _activities = [];

  // Function to save the response to a file
  Future<void> _saveResponseToFile(String response) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/user_responses.txt');
    await file.writeAsString('Physical Therapy: $response\n', mode: FileMode.append);
  }

  void _handleContinue() async {
    await _saveResponseToFile(_selectedOption!);
    if (_selectedOption == 'Yes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhysicalTherapyActivityEntry(medications: widget.medications),
        ),
      );
    } else if (_selectedOption == 'Customized plan') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomPlanScreen(surgeryType: 'Hip Replacement',), //Change this later
        ),
      );
    } else if (_selectedOption == 'No physical therapy') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoPTScreen(),
        ),
      );
    }
  }

  void _addActivity() {
    setState(() {
      _activities.add("Activity ${_activities.length + 1}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Physical Therapy")),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Have you already seen a physical therapist?",
              style: TextStyle(fontSize: 18.sp),
            ),
            SizedBox(height: 20.h),
            _buildOptionButton("Yes, I have already seen one", "Yes"),
            SizedBox(height: 20.h),
            _buildOptionButton(
                "No, I would like a customized physical therapy plan",
                "Customized plan"),
            SizedBox(height: 20.h),
            _buildOptionButton(
                "No, I do not want physical therapy", "No physical therapy"),
            SizedBox(height: 20.h),
            if (_selectedOption != null)
              SizedBox(height: 20.h),
            if (_selectedOption != null)
              ElevatedButton(
                onPressed: _handleContinue,
                child: Text(
                    "Continue",
                  style:
                  TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
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
        style: TextStyle(color: Colors.black),
      ),
    );
  }
}




class NoPTScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("No Physical Therapy")),
      body: Padding(
        padding: EdgeInsets.all(16.w),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Are you sure you do not want a personalized physical therapy plan to aid in your recovery?",
            style: TextStyle(fontSize: 18.sp),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () {
              // Navigate to home page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text("Yes, I'm sure"),
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: () {
              // Navigate back to previous page
              Navigator.pop(context);
            },
            child: Text("No, go back"),
          ),
        ],
      ),
      ));
  }
}
