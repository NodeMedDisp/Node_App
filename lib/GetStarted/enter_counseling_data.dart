import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'summary_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/medication.dart';
import '../models/counseling_question.dart';

class EnterCounselingPrompts extends StatefulWidget {
  final List<Medication> medications;
  final BluetoothDevice? device;

  const EnterCounselingPrompts(
      {super.key, required this.medications, this.device});

  @override
  _EnterCounselingPrompts createState() => _EnterCounselingPrompts();
}

class _EnterCounselingPrompts extends State<EnterCounselingPrompts> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  String _responseRequired = 'Require a Response?';
  String? _responseType;
  List<CounselingQuestion> prompts = [];
  String? _errorMessage;

  void _addPrompt() {
    List<String> options = [];

    if (_responseRequired == 'Yes') {
      if (_responseType == null) {
        setState(() {
          _errorMessage =
              'Please select a response type (Yes/No or 1-10 Scale).';
        });
        return;
      }
      if (_responseType == 'Yes/No') {
        options = ['Yes', 'No'];
      } else if (_responseType == '1-10 Scale') {
        options = List.generate(10, (index) => (index + 1).toString());
      }
    } else {
      options = ['Respond in Journal'];
    }

    final newPrompt = CounselingQuestion(
      prompt: _promptController.text,
      resReq: _responseRequired,
      options: options,
      numberOfDays: int.tryParse(_daysController.text) ?? 0,
    );

    // Check if we are in the Provider flow
    ProviderCubit? providerCubit;
    try {
      providerCubit = context.read<ProviderCubit>();
    } catch (_) {}

    if (providerCubit != null) {
      providerCubit.addPromptToSelectedUser(newPrompt);
      Navigator.pop(context);
      return;
    }

    setState(() {
      prompts.add(newPrompt);
      _promptController.clear();
      _daysController.clear();
      _responseRequired = 'Require a Response?';
      _responseType = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isProvider = false;
    try {
      isProvider = context.read<ProviderCubit>().state.selectedUser != null;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Counseling Prompts")),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: "Enter Prompt Here",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1.5),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _responseRequired,
                      items: ['Require a Response?', 'Yes', 'Journal Response']
                          .map((resReq) {
                        return DropdownMenuItem<String>(
                            value: resReq, child: Text(resReq));
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
                            borderSide: BorderSide(color: Colors.grey[400]!)),
                        enabledBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 1.5),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                              color: ColorsManager.mainBlue, width: 2.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
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
                      _errorMessage = null;
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
                      _errorMessage = null;
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
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Number of Days",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1.5),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addPrompt,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: ColorsManager.mainBlue,
                  ),
                  child: Text(
                    isProvider ? "Save Prompt" : "Add Prompt",
                    style: TextStyles.font14Hint500Weight
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              if (!isProvider) ...[
                SizedBox(height: 20.h),
                SizedBox(
                  height: 200.h,
                  child: ListView.builder(
                    itemCount: prompts.length,
                    itemBuilder: (context, index) {
                      final prompt = prompts[index];
                      return ListTile(
                        title: Text(
                            "${prompt.prompt} (${prompt.numberOfDays} day(s))"),
                        subtitle: Text("Response: ${prompt.resReq}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: isProvider
          ? null
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint(
                      'TRACE 5 COUNSELING DATA -> SUMMARY: ${widget.device?.remoteId}',
                    );
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
                    style: TextStyles.font14Hint500Weight
                        .copyWith(color: ColorsManager.mainBlue),
                  ),
                ),
              ),
            ),
    );
  }
}
