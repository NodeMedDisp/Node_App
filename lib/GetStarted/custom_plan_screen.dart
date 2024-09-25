import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:node_app_2/HomePage/home_page.dart';

class CustomPlanScreen extends StatelessWidget {
  final String surgeryType;

  const CustomPlanScreen({super.key, required this.surgeryType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Custom Physical Therapy Plan")),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              "We have designed a customized plan based on your surgery: $surgeryType.",
              style: TextStyle(fontSize: 18.sp),
            ),
            SizedBox(height: 20.h),
            _buildPlanDetails(surgeryType),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back if rejected
                  },
                  child: Text("Reject"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Save and proceed to home page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(),
                      ),
                    );
                  },
                  child: Text("Accept"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetails(String surgeryType) {
    String plan;
    if (surgeryType == 'Hip Replacement') {
      plan = '1. Hip stretches\n2. Strengthen glutes\n3. Walk daily for 30 minutes.';
    } else if (surgeryType == 'Knee Replacement') {
      plan = '1. Quad exercises\n2. Hamstring stretches\n3. Walk daily for 20 minutes.';
    } else {
      plan = 'General plan for healthy living.';
    }

    return Text(
      plan,
      style: TextStyle(fontSize: 16.sp),
    );
  }
}
