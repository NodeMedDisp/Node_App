import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../HomePage/home_page.dart';


class PhysicalTherapySummaryScreen extends StatefulWidget {
  final List<Map<String, String>> activities;
  final Future<void> Function() saveDataToFile;
  final List<Map<String, String>> medications;

  PhysicalTherapySummaryScreen({
    required this.activities,
    required this.saveDataToFile,
    required this.medications,
  });

  @override
  _PhysicalTherapySummaryScreenState createState() =>
      _PhysicalTherapySummaryScreenState();
}

class _PhysicalTherapySummaryScreenState
    extends State<PhysicalTherapySummaryScreen> {
  DateTime _focusedDay = DateTime(2023, 10, 12); // Assuming surgery date
  DateTime _selectedDay = DateTime(2023, 10, 12);

  // Get activities for the specific day
  List<Map<String, String>> _getActivitiesForDay(DateTime day) {
    return widget.activities.where((activity) {
      final startDay = int.parse(activity['startDay']!);
      final endDay = int.parse(activity['endDay']!);
      final activityDay = DateTime(2023, 10, 12).add(Duration(days: startDay - 1));
      final lastActivityDay = DateTime(2023, 10, 12).add(Duration(days: endDay - 1));
      return day.isAfter(activityDay.subtract(Duration(days: 1))) &&
          day.isBefore(lastActivityDay.add(Duration(days: 1)));
    }).toList();
  }

  // Get medications for the specific day
  List<Map<String, String>> _getMedicationsForDay(DateTime day) {
    return widget.medications.where((medication) {
      final startDay = int.parse(medication['startDay']!);
      final endDay = int.parse(medication['endDay']!);
      final dose = int.parse(medication['dose']!);
      final medicationStartDay = DateTime(2023, 10, 12).add(Duration(days: startDay - 1));
      final lastMedicationDay = DateTime(2023, 10, 12).add(Duration(days: endDay - 1));
      return day.isAfter(medicationStartDay.subtract(Duration(days: 1))) &&
          day.isBefore(lastMedicationDay.add(Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activitiesForDay = _getActivitiesForDay(_selectedDay);
    final medicationsForDay = _getMedicationsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: Text("Physical Therapy Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Calendar to show activities and medications by day
            TableCalendar(
              firstDay: DateTime(2023, 10, 12), // Surgery date
              lastDay: DateTime(2023, 12, 31), // Adjust the range as needed
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            ),
            SizedBox(height: 20),

            // Show Activities Header
            if (activitiesForDay.isNotEmpty) ...[
              Text("Activities", style: TextStyles.font14Blue400Weight),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Three activities per row
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: activitiesForDay.length,
                  itemBuilder: (context, index) {
                    final activity = activitiesForDay[index];
                    return GestureDetector(
                      onTap: () => _showActivityDetails(context, activity),
                      child: Container(
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: ColorsManager.mainBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            activity['activity']!,
                            style: TextStyle(fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Show Medications Header
            if (medicationsForDay.isNotEmpty) ...[
              Text("Medications", style: TextStyles.font14Blue400Weight),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Three medications per row
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: medicationsForDay.length,
                  itemBuilder: (context, index) {
                    final medication = medicationsForDay[index];
                    return GestureDetector(
                      onTap: () => _showMedicationDetails(context, medication),
                      child: Container(
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: ColorsManager.mainBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            medication['medication']!,
                            style: TextStyle(fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity, // Full width for the button
          child: ElevatedButton(
            onPressed: () async {
              await widget.saveDataToFile();
              Navigator.push(
                context,
                  MaterialPageRoute(
                  builder: (context) => HomePage()
                  )
              );
            },
            child: Text(
              "Save and Continue",
              style: TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.white, // Customize as needed
            ),
          ),
        ),
      ),
    );
  }

  // Show activity details in a dialog
  void _showActivityDetails(BuildContext context, Map<String, String> activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(activity['activity']!),
          content: Text(
            "Metric: ${activity['metric']}\n"
                "Value: ${activity['value']}\n"
                "Times per day: ${activity['timesPerDay']}\n"
                "Days: ${activity['startDay']} to ${activity['endDay']}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // Show medication details in a dialog
  void _showMedicationDetails(BuildContext context, Map<String, String> medication) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(medication['medication']!),
          content: Text(
            "Frequency: ${medication['frequency']}\n"
                "Dose: ${medication['dose']}\n"
                "Times: ${medication['times']}\n"
                "Days: ${medication['startDay']} to ${medication['endDay']}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
