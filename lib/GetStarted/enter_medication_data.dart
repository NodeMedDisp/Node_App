import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _streakTitleController = TextEditingController();
  final TextEditingController _tokenTitleController = TextEditingController();
  final TextEditingController _tokenQuantityController =
      TextEditingController(text: '1');

  bool _streakEnabled = false;
  bool _tokenEnabled = false;

  String? _errorMessage;
  String? _frequency;
  List<String> _times = [];
  List<Medication> medications = [];
  int _numTimesPerDay = 0;
  List<TimeOfDay?> _selectedTimes = [];

  Future<void> _addMedication() async {
    final medicationName = _medicationController.text.trim();
    final dose = _doseController.text.trim();
    final numberOfDays = int.tryParse(_daysController.text.trim());
    final tokenQuantity = int.tryParse(_tokenQuantityController.text.trim());

    if (medicationName.isEmpty) {
      _showError('Enter a medication name.');
      return;
    }

    if (dose.isEmpty) {
      _showError('Enter a medication dose.');
      return;
    }

    if (_frequency == null) {
      _showError('Select how often the medication will be taken.');
      return;
    }

    if (numberOfDays == null || numberOfDays <= 0) {
      _showError('Enter a valid number of days.');
      return;
    }

    if (_numTimesPerDay <= 0 ||
        _selectedTimes.length != _numTimesPerDay ||
        _selectedTimes.any((time) => time == null)) {
      _showError('Select every required medication time.');
      return;
    }

    if (_streakEnabled && _streakTitleController.text.trim().isEmpty) {
      _showError('Enter a title for the medication streak.');
      return;
    }

    if (_tokenEnabled && _tokenTitleController.text.trim().isEmpty) {
      _showError('Enter a title for the medication tokens.');
      return;
    }

    if (_tokenEnabled && (tokenQuantity == null || tokenQuantity <= 0)) {
      _showError('Enter a token quantity greater than zero.');
      return;
    }

    final formattedTimes = _selectedTimes
        .whereType<TimeOfDay>()
        .map((time) => time.format(context))
        .toList();

    final newMed = Medication(
      name: medicationName,
      frequency: _frequency!,
      dose: dose,
      times: formattedTimes.join(', '),
      numDays: numberOfDays,

      // Medication rewards happen when the medication event occurs.
      streakEnabled: _streakEnabled,
      streakTitle: _streakEnabled ? _streakTitleController.text.trim() : '',
      streakThreshold: 'None',

      tokenEnabled: _tokenEnabled,
      tokenTitle: _tokenEnabled ? _tokenTitleController.text.trim() : '',
      tokenThreshold: 'None',
      tokenQuantity: _tokenEnabled ? tokenQuantity! : 0,
    );

    ProviderCubit? providerCubit;

    try {
      providerCubit = context.read<ProviderCubit>();
    } catch (_) {
      providerCubit = null;
    }

    if (providerCubit != null) {
      try {
        debugPrint(
          'PROVIDER MEDICATION FORM: '
          'Saving "${newMed.name}"',
        );

        await providerCubit.addMedicationToSelectedUser(
          newMed,
        );

        debugPrint(
          'PROVIDER MEDICATION FORM: Save completed',
        );

        if (!mounted) {
          return;
        }

        Navigator.pop(context);
      } catch (error, stackTrace) {
        debugPrint(
          'PROVIDER MEDICATION FORM ERROR: $error',
        );
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = 'Could not save medication: $error';
        });
      }

      return;
    }

    setState(() {
      medications.add(newMed);

      _medicationController.clear();
      _doseController.clear();
      _daysController.clear();

      _frequency = null;
      _numTimesPerDay = 0;
      _selectedTimes = [];
      _times = [];

      _streakEnabled = false;
      _streakTitleController.clear();

      _tokenEnabled = false;
      _tokenTitleController.clear();
      _tokenQuantityController.text = '1';

      _errorMessage = null;
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
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

  Widget _buildMedicationRewardSection({
    required String rewardName,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required TextEditingController titleController,
    TextEditingController? quantityController,
  }) {
    final isToken = quantityController != null;

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Add a $rewardName?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              value: enabled,
              onChanged: onEnabledChanged,
            ),
            if (enabled) ...[
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isToken ? 'Token Title' : 'Streak Title',
                  hintText: isToken
                      ? 'Example: Medication Completed'
                      : 'Example: Medication Streak',
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              const InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Threshold',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  'None — the reward is triggered when medication is taken',
                ),
              ),
              if (isToken) ...[
                SizedBox(height: 12.h),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Number of Tokens',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _doseController.dispose();
    _daysController.dispose();
    _streakTitleController.dispose();
    _tokenTitleController.dispose();
    _tokenQuantityController.dispose();
    super.dispose();
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
              _buildMedicationRewardSection(
                rewardName: 'streak',
                enabled: _streakEnabled,
                onEnabledChanged: (value) {
                  setState(() {
                    _streakEnabled = value;
                  });
                },
                titleController: _streakTitleController,
              ),
              _buildMedicationRewardSection(
                rewardName: 'token reward',
                enabled: _tokenEnabled,
                onEnabledChanged: (value) {
                  setState(() {
                    _tokenEnabled = value;
                  });
                },
                titleController: _tokenTitleController,
                quantityController: _tokenQuantityController,
              ),
              if (_errorMessage != null) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
