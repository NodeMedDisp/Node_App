import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'summary_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';

class PhysicalTherapyActivityEntry extends StatefulWidget {
  final List<Map<String, String>> medications;
  PhysicalTherapyActivityEntry({required this.medications});

  @override
  _PhysicalTherapyActivityEntryState createState() =>
      _PhysicalTherapyActivityEntryState();
}

class _PhysicalTherapyActivityEntryState
    extends State<PhysicalTherapyActivityEntry> {
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _repsOrMinutesController =
      TextEditingController();
  final TextEditingController _startDayController = TextEditingController();
  final TextEditingController _endDayController = TextEditingController();
  final TextEditingController _timesPerDayController = TextEditingController();

  String _selectedMetric = 'Repetitions'; // Default dropdown value
  List<Map<String, String>> activities = [];

  // Save the activities to a file
  Future<void> _saveDataToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/user_responses.txt');
    for (var activity in activities) {
      await file.writeAsString(
        'Activity: ${activity["activity"]}, ${activity["metric"]}: ${activity["value"]}, '
        'Times per day: ${activity["timesPerDay"]}, Days: ${activity["startDay"]} to ${activity["endDay"]}\n',
        mode: FileMode.append,
      );
    }
  }

  void _addActivity() {
    setState(() {
      activities.add({
        "activity": _activityController.text,
        "metric": _selectedMetric,
        "value": _repsOrMinutesController.text,
        "startDay": _startDayController.text,
        "endDay": _endDayController.text,
        "timesPerDay": _timesPerDayController.text,
      });

      // Clear the input fields
      _activityController.clear();
      _repsOrMinutesController.clear();
      _startDayController.clear();
      _endDayController.clear();
      _timesPerDayController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enter Physical Therapy Activities")),
      resizeToAvoidBottomInset:
          true, // Resizes content when the keyboard appears
      body: SafeArea(
        child: SingleChildScrollView(
          // Ensures scrolling when content overflows
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Activity Name Input
              TextField(
                controller: _activityController,
                decoration: InputDecoration(
                  labelText: "Activity Name",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black, // Black border for enabled state
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue, // Blue border when focused
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Reps/Minutes Input and Dropdown in a row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _repsOrMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Enter value",
                        labelStyle: TextStyles.font14Hint500Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                Colors.black, // Black border for enabled state
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager
                                .mainBlue, // Blue border when focused
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedMetric,
                      items: ['Repetitions', 'Minutes'].map((metric) {
                        return DropdownMenuItem<String>(
                          value: metric,
                          child: Text(metric),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMetric = value!;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                Colors.black, // Black border for enabled state
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager
                                .mainBlue, // Blue border when focused
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Number of Times per Day Input
              TextField(
                controller: _timesPerDayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Number of Times per Day",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black, // Black border for enabled state
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue, // Blue border when focused
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Timeframe Input (Day X to Day Y from surgery)
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
                            color:
                                Colors.black, // Black border for enabled state
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager
                                .mainBlue, // Blue border when focused
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
                            color:
                                Colors.black, // Black border for enabled state
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorsManager
                                .mainBlue, // Blue border when focused
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Add Activity Button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addActivity,
                  child: Text(
                    "Add Activity",
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

              // Display Added Activities
              Container(
                height: 200.h, // Set a fixed height for the list
                child: ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return ListTile(
                      title: Text(
                        "${activity['activity']} (${activity['startDay']} to ${activity['endDay']} from surgery)",
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
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity, // Full width for the button
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhysicalTherapySummaryScreen(
                    activities: activities,
                    medications: widget.medications,
                    saveDataToFile: _saveDataToFile,
                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
