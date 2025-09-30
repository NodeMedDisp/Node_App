/*
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'summary_screen.dart';

class CustomPlanScreen extends StatelessWidget {
  final String selectedSurgery;
  final List<Map<String, String>> medications;

  const CustomPlanScreen({super.key, required this.selectedSurgery, required this.medications});

  @override
  Widget build(BuildContext context) {
    // Create the activities list here, outside of _buildPlanDetails
    final List<Map<String, String>> activities = _buildActivities(selectedSurgery);

    return Scaffold(
      appBar: AppBar(title: const Text("Custom Physical Therapy Plan")),
      body: SingleChildScrollView( // Make the content scrollable
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons take full width
            children: [
              Center( // Center the first text in the screen
                child: Text(
                  "We have designed a customized plan based on your $selectedSurgery surgery.",
                  style: TextStyle(fontSize: 18.sp),
                  textAlign: TextAlign.center, // Center-align the text inside the widget
                ),
              ),
              SizedBox(height: 20.h),
              _buildPlanDetails(activities), // Assuming _buildPlanDetails returns a widget
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back if rejected
                    },
                    child: const Text("Reject"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the next screen with the medications and activities
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhysicalTherapySummaryScreen(
                            medications: medications,
                            activities: activities, // Pass the activities list
                          ),
                        ),
                      );
                    },
                    child: const Text("Accept"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // This function generates the activities list based on the surgery type
  List<Map<String, String>> _buildActivities(String selectedSurgery) {
    List<Map<String, String>> activities = [];
    if (selectedSurgery == 'Hip Replacement') {
      activities = [
        {
          'activity': 'Hip stretches',
          'startDay': '1',
          'endDay': '7',
          'metric': 'Reps',
          'value': '10',
          'timesPerDay': '3'
        },
        {
          'activity': 'Donkey Kicks',
          'startDay': '8',
          'endDay': '14',
          'metric': 'Reps',
          'value': '15',
          'timesPerDay': '2'
        },
        {
          'activity': 'Walk daily',
          'startDay': '1',
          'endDay': '30',
          'metric': 'Minutes',
          'value': '30',
          'timesPerDay': '1'
        }
      ];
    } else if (selectedSurgery == 'Knee Replacement') {
      activities = [
        {
          'activity': 'Air Squats',
          'startDay': '1',
          'endDay': '7',
          'metric': 'Reps',
          'value': '10',
          'timesPerDay': '3'
        },
        {
          'activity': 'Hamstring stretches',
          'startDay': '8',
          'endDay': '14',
          'metric': 'Reps',
          'value': '15',
          'timesPerDay': '2'
        },
        {
          'activity': 'Walk daily',
          'startDay': '1',
          'endDay': '30',
          'metric': 'Minutes',
          'value': '20',
          'timesPerDay': '1'
        }
      ];
    } else {
      activities = [
        {
          'activity': 'General stretches',
          'startDay': '1',
          'endDay': '30',
          'metric': 'Minutes',
          'value': '15',
          'timesPerDay': '1'
        }
      ];
    }
    return activities;
  }

  // Modified _buildPlanDetails to take the generated activities list
  Widget _buildPlanDetails(List<Map<String, String>> activities) {
    // Convert activities into a formatted string
    String activitiesDetails = activities.map((activity) {
      return '''
Activity: ${activity['activity']}
Start Day: ${activity['startDay']}
End Day: ${activity['endDay']}
Metric: ${activity['metric']}
Value: ${activity['value']}
Times per Day: ${activity['timesPerDay']}
''';
    }).join('\n');

    // Return the formatted plan details as a widget
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Text(
        activitiesDetails,
        style: TextStyle(fontSize: 16.sp),
      ),
    );
  }
}
*/
