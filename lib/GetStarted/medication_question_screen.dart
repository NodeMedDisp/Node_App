
import 'package:gap/gap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/GetStarted/enter_medication_data.dart';

import 'package:flutter/material.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';

class PrescriptionQuestionScreen extends StatefulWidget {
  final String selectedSurgery;

  const PrescriptionQuestionScreen({super.key, required this.selectedSurgery});

  get device => null;

  @override
  _PrescriptionQuestionScreenState createState() => _PrescriptionQuestionScreenState();
}

class _PrescriptionQuestionScreenState extends State<PrescriptionQuestionScreen> {
  String? selectedOption;

  @override
  Widget build(BuildContext context) {
    List<String> prescriptionOptions = ['Yes', 'No'];

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription Question')),
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
                        builder: (context) => EnterPrescriptionData(device: widget.device), 
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
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
