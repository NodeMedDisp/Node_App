import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../LoginComp/core/widgets/MedicationEntryPage.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'counseling_questions_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/medication.dart';

class EnterPrescriptionData extends StatefulWidget {
  final BluetoothDevice? device;

  const EnterPrescriptionData({super.key, this.device});

  @override
  _EnterPrescriptionDataState createState() => _EnterPrescriptionDataState();
}

class _EnterPrescriptionDataState extends State<EnterPrescriptionData> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  String? _frequency;
  List<String> _times = [];
  List<Medication> medications = [];
  int _numTimesPerDay = 0;
  List<TimeOfDay?> _selectedTimes = [];

  void _addMedication() {
    if (_medicationController.text.isNotEmpty &&
        _doseController.text.isNotEmpty &&
        _frequency != null &&
        _daysController.text.isNotEmpty) {
      _times = _selectedTimes
          .where((time) => time != null)
          .map((time) => time!.format(context))
          .toList();

      final newMed = Medication(
        name: _medicationController.text,
        frequency: _frequency!,
        dose: _doseController.text,
        times: _times.join(', '),
        numDays: int.tryParse(_daysController.text) ?? 0,
      );

      // Check if we are in the Provider flow
      ProviderCubit? providerCubit;
      try {
        providerCubit = context.read<ProviderCubit>();
      } catch (_) {}

      if (providerCubit != null) {
        providerCubit.addMedicationToSelectedUser(newMed);
        Navigator.pop(context);
        return;
      }

      setState(() {
        medications.add(newMed);
        _medicationController.clear();
        _doseController.clear();
        _frequency = null;
        _selectedTimes = List.filled(_numTimesPerDay, null);
        _daysController.clear();
      });
    } else {
      print("Please fill in all fields");
    }
  }

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
    // Hide the list and continue button if we're in the provider dashboard
    bool isProvider = false;
    try {
      isProvider = context.read<ProviderCubit>().state.selectedUser != null;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Prescription Data")),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _medicationController,
                decoration: InputDecoration(
                  labelText: "Medication Name",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1.5),
                  ),
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
              TextField(
                controller: _doseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Number of Milligrams Per Dose",
                  labelStyle: TextStyles.font14Hint500Weight,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1.5),
                  ),
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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "How often will the medication be taken?",
                  labelStyle: TextStyle(
                      color: Colors.grey[600], fontWeight: FontWeight.w400),
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
                value: _frequency,
                items: [
                  'Once daily',
                  'Twice daily',
                  'Three times daily',
                  'Custom'
                ]
                    .map((freq) =>
                        DropdownMenuItem(value: freq, child: Text(freq)))
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
                        _numTimesPerDay = 4;
                        break;
                      default:
                        _numTimesPerDay = 0;
                    }
                    _selectedTimes = List.filled(_numTimesPerDay, null);
                  });
                },
              ),
              SizedBox(height: 20.h),
              if (_numTimesPerDay > 0) ...[
                Column(
                  children: List.generate(_numTimesPerDay, (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _pickTime(index),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                              ),
                              child: Text(
                                _selectedTimes[index] == null
                                    ? 'Select Time'
                                    : 'Time: ${_selectedTimes[index]!.format(context)}',
                                style: TextStyles.font14Hint500Weight
                                    .copyWith(color: ColorsManager.mainBlue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                SizedBox(height: 20.h),
              ],
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
                  onPressed: _addMedication,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: ColorsManager.mainBlue,
                  ),
                  child: Text(
                    isProvider ? "Save Medication" : "Add Medication",
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
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final medication = medications[index];
                      return ListTile(
                          title: Text(
                              "${medication.name} - ${medication.frequency}"),
                          onTap: () async {
                            final updatedMedication =
                                await Navigator.push<Medication>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicationEntryPage(
                                    medication: medications[index]),
                              ),
                            );
                            if (updatedMedication != null) {
                              setState(() {
                                medications[index] = updatedMedication;
                              });
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                medications.removeAt(index);
                              });
                            },
                          ));
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
                      'TRACE 3 PRESCRIPTION -> COUNSELING: ${widget.device?.remoteId}',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CounselingQuestionScreen(
                            medications: medications, device: widget.device),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    backgroundColor: Colors.white,
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
