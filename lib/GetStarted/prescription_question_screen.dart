import 'package:gap/gap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:node_app_2/GetStarted/enter_prescription_data.dart';
import 'dart:io';  // Required for working with files
import 'package:path_provider/path_provider.dart';  // For accessing device storage
import 'package:flutter/material.dart';
import 'enter_prescription_data.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';

class PrescriptionQuestionScreen extends StatefulWidget {
  @override
  _PrescriptionQuestionScreenState createState() => _PrescriptionQuestionScreenState();
}

class _PrescriptionQuestionScreenState extends State<PrescriptionQuestionScreen> {
  String? selectedOption;

  @override
  Widget build(BuildContext context) {
    List<String> prescriptionOptions = ['Yes', 'No'];

    return Scaffold(
      appBar: AppBar(title: Text('Prescription Question')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Did you receive a prescription?",
                style: TextStyle(fontSize: 18.sp),
              ),
              Gap(20.h),
              for (String optionText in prescriptionOptions)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedOption = optionText;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedOption == optionText
                          ? ColorsManager.mainBlue
                          : Colors.grey[300],
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50.h),
                      side: BorderSide(
                        color: selectedOption == optionText
                            ? Colors.blueAccent
                            : Colors.grey,
                      ),
                    ),
                    child: Text(optionText),
                  ),
                ),
              Gap(20.h),
              if (selectedOption != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnterPrescriptionData(),
                      ),
                    );
                  },
                  child: Text(
                      'Continue',
                    style:
                    TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
