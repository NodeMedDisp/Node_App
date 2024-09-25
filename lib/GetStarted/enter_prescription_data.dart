import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'pt_questions_screen.dart';

class EnterPrescriptionData extends StatefulWidget {
  @override
  _EnterPrescriptionDataState createState() => _EnterPrescriptionDataState();
}

class _EnterPrescriptionDataState extends State<EnterPrescriptionData> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _startDayController = TextEditingController();
  final TextEditingController _endDayController = TextEditingController();
  String? _frequency;
  List<String> _times = [];
  List<Map<String, String>> medications = [];
  int _numTimesPerDay = 0; // Number of times to take medication per day
  List<TimeOfDay?> _selectedTimes = []; // List of selected times

  // Save the medications to a file
  Future<void> _saveDataToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/user_responses.txt');
    for (var medication in medications) {
      await file.writeAsString(
        'Medication: ${medication["medication"]}, Dose: ${medication["dose"]}, Frequency: ${medication["frequency"]}, '
        'Times: ${medication["times"]}, '
        'Days: ${medication["startDay"]} to ${medication["endDay"]}\n',
        mode: FileMode.append,
      );
    }
  }

  void _addMedication() {
    // Ensure that all fields are filled out
    if (_medicationController.text.isNotEmpty &&
        _doseController.text.isNotEmpty &&
        _frequency != null &&
        _startDayController.text.isNotEmpty &&
        _endDayController.text.isNotEmpty) {
      setState(() {
        // Add the medication to the list
        medications.add({
          "medication": _medicationController.text,
          "frequency": _frequency!,
          "dose": _doseController.text,
          "times": _times.join(', '),
          "startDay": _startDayController.text,
          "endDay": _endDayController.text,
        });

        // Clear the input fields
        _medicationController.clear();
        _doseController.clear();
        _frequency = null; // Reset dropdown value
        _times.clear(); // Clear the times
        _startDayController.clear();
        _endDayController.clear();
      });
    } else {
      // Optional: Display an alert or error message
      print("Please fill in all fields");
    }
  }

  // Handle the time picker for each time input
  Future<void> _pickTime(int index) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enter Prescription Data")),
      resizeToAvoidBottomInset: true,
      // Resizes content when the keyboard appears
      body: SafeArea(
        child: SingleChildScrollView(
          // Ensures scrolling when content overflows
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Medication Name Input
              TextField(
                controller: _medicationController,
                decoration: InputDecoration(
                  labelText: "Medication Name",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              //Number of pills
              TextField(
                controller: _doseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Number of Pills Per Dose",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Frequency Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "How often do you take the medication?",
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue,
                      width: 2.0,
                    ),
                  ),
                ),
                value: _frequency,
                items:
                    ['Once daily', 'Twice daily', 'Three times daily', 'Custom']
                        .map((freq) => DropdownMenuItem(
                              value: freq,
                              child: Text(freq),
                            ))
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _frequency = value;

                    switch (value) {
                      case 'Once daily':
                        _numTimesPerDay = 1;
                        break;
                      case 'Twice daily':
                        _numTimesPerDay = 2;
                        break;
                      case 'Three times daily':
                        _numTimesPerDay = 3;
                        break;
                      case 'Custom':
                        // Handle custom logic
                        _numTimesPerDay = 4;
                        break;
                      default:
                        _numTimesPerDay = 0;
                    }
                    _selectedTimes = List.filled(
                        _numTimesPerDay, null); // Initialize empty time slots
                  });
                },
              ),
              SizedBox(height: 10.h),

              // Time Inputs based on selected frequency
              if (_numTimesPerDay > 0) ...[
                Column(
                  children: List.generate(_numTimesPerDay, (index) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                              onPressed: () => _pickTime(index),
                              child: Text(
                                _selectedTimes[index] == null
                                    ? 'Select Time'
                                    : 'Time: ${_selectedTimes[index]!.format(context)}',
                                style: TextStyles.font14Hint500Weight
                                    .copyWith(color: ColorsManager.mainBlue),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                              )),
                        ),
                      ],
                    );
                  }),
                ),
                SizedBox(height: 10.h),
              ],

              // Timeframe (Start Day to End Day from surgery)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startDayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Start Day (from surgery)",
                        labelStyle: TextStyles.font14Hint500Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager.mainBlue,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: _endDayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "End Day (from surgery)",
                        labelStyle: TextStyles.font14Hint500Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager.mainBlue,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Add Medication Button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addMedication,
                  child: Text(
                    "Add Medication",
                    style: TextStyles.font14Hint500Weight
                        .copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: ColorsManager.mainBlue,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Display Added Medications
              Container(
                height: 200.h, // Set a fixed height for the list
                child: ListView.builder(
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final medication = medications[index];
                    return ListTile(
                      title: Text(
                        "${medication['medication']} - ${medication['frequency']} ",
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await _saveDataToFile();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhysicalTherapyQuestionScreen(medications: medications),
                ),
              );
            },
            child: Text(
              "Continue",
              style:
                  TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15.h),
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
