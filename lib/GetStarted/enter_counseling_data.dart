import 'package:flutter/material.dart';
import 'summary_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Import FlutterBluePlus

class EnterCounselingPrompts extends StatefulWidget {
  final List<Map<String, String>> medications;
  final BluetoothDevice? device; // Add this to accept the Bluetooth device

  const EnterCounselingPrompts({super.key, required this.medications, this.device});

  @override
  _EnterCounselingPrompts createState() => _EnterCounselingPrompts();
}

class _EnterCounselingPrompts extends State<EnterCounselingPrompts> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _startDayController = TextEditingController();
  final TextEditingController _endDayController = TextEditingController();

  String _responseRequired = 'Require a Response?'; // Default dropdown value
  String? _responseType; // Holds the selected response type ("Yes/No" or "1-10 Scale")
  List<Map<String, dynamic>> prompts = []; // Store prompts
  String? _errorMessage; // Error message for invalid input

  // Add Prompt method
  void _addPrompt() {
    List<String> options = [];

    if (_responseRequired == 'Yes') {
      if (_responseType == null) {
        setState(() {
          _errorMessage = 'Please select a response type (Yes/No or 1-10 Scale).';
        });
        return;
      }

      // Generate options based on the selected response type
      if (_responseType == 'Yes/Journal Response') {
        options = ['Yes', 'Journal Response'];
      } else if (_responseType == '1-10 Scale') {
        options = List.generate(10, (index) => (index + 1).toString()); // 1-10 as options
      }
    } else {
      options = ['Respond in Journal']; // Default for no response required
    }

    setState(() {
      // Add the current prompt data
      prompts.add({
        "prompt": _promptController.text,
        "resReq": _responseRequired,
        "responseType": _responseRequired == 'Yes' ? _responseType : null,
        "options": options,
        "startDay": _startDayController.text,
        "endDay": _endDayController.text,
      });

      // Clear all fields after adding the prompt
      _promptController.clear();
      _startDayController.clear();
      _endDayController.clear();
      _responseRequired = 'Require a Response?';
      _responseType = null;
      _errorMessage = null; // Clear any error messages
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Counseling Prompts")),
      resizeToAvoidBottomInset: true, // Resizes content when the keyboard appears
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Prompt Name Input
              TextField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: "Enter Prompt Here",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ColorsManager.mainBlue,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Response Required Dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _responseRequired,
                      items: ['Require a Response?', 'Yes', 'Journal Response'].map((resReq) {
                        return DropdownMenuItem<String>(
                          value: resReq,
                          child: Text(resReq),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _responseRequired = value!;
                          if (_responseRequired == 'Journal Response') {
                            _responseType = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
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
              SizedBox(height: 10.h),

              // Response Type Selection (Only shown if response is required)
              if (_responseRequired == 'Yes') ...[
                const Text(
                  "Select Response Type:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  title: const Text('Yes/No'),
                  value: 'Yes/No',
                  groupValue: _responseType,
                  onChanged: (value) {
                    setState(() {
                      _responseType = value;
                      _errorMessage = null; // Clear error message
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('1-10 Scale'),
                  value: '1-10 Scale',
                  groupValue: _responseType,
                  onChanged: (value) {
                    setState(() {
                      _responseType = value;
                      _errorMessage = null; // Clear error message
                    });
                  },
                ),
              ],
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp),
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
                        labelText: "Start Day (ie. enter 1 for 'Day 1')",
                        labelStyle: TextStyles.font14Hint500Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
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
                        labelText: "End Day (ie. enter 1 for 'Day 1')",
                        labelStyle: TextStyles.font14Hint500Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
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

              // Add Prompt Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addPrompt,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: ColorsManager.mainBlue,
                  ),
                  child: Text(
                    "Add Prompt",
                    style: TextStyles.font14Hint500Weight.copyWith(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Display Added Prompts
              SizedBox(
                height: 200.h,
                child: ListView.builder(
                  itemCount: prompts.length,
                  itemBuilder: (context, index) {
                    final prompt = prompts[index];
                    return ListTile(
                      title: Text(
                        "${prompt['prompt']} (${prompt['startDay']} to ${prompt['endDay']} days)",
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      subtitle: Text(
                        "Response: ${prompt['resReq'] == 'Yes' ? '${prompt['responseType']}' : 'Respond in Journal'}",
                        style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            prompts.removeAt(index);
                          });
                        },
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
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecoverySummaryScreen(
                    prompts: prompts,
                    medications: widget.medications,
                    device: widget.device,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15.h),
            ),
            child: Text(
              "Continue",
              style: TextStyles.font14Hint500Weight.copyWith(color: ColorsManager.mainBlue),
            ),
          ),
        ),
      ),
    );
  }
}


