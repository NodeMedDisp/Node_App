import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theming/colors.dart';
import '../../theming/styles.dart';
import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';

class MedicationEntryPage extends StatefulWidget {
  final Medication? medication; // null = add mode
  final List<Medication> otherMedications;
  final DateTime? fallbackStartDate;

  const MedicationEntryPage({
    super.key,
    this.medication,
    this.otherMedications = const [],
    this.fallbackStartDate,
  });

  @override
  _MedicationEntryPageState createState() => _MedicationEntryPageState();
}

class _MedicationEntryPageState extends State<MedicationEntryPage> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  String? _frequency = 'Once daily';
  int _numTimesPerDay = 1;
  List<TimeOfDay?> _selectedTimes = [null];
  late DateTime _startDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final original = widget.medication;
    // Never silently relabel an existing medication or copy its dose to a new drug.
    _medicationController.text = original?.name ?? 'Methadone';
    _doseController.text = original?.dose ?? '';
    _daysController.text = original?.numDays.toString() ?? '';
    _startDate = DateUtils.dateOnly(
      original?.startDate ?? widget.fallbackStartDate ?? DateTime.now(),
    );
    final minute = original == null ? null : MedicationSchedule.minutes(original.times);
    if (minute != null) {
      _selectedTimes = [TimeOfDay(hour: minute ~/ 60, minute: minute % 60)];
    } else if (original != null) {
      _errorMessage = 'This entry needs one daily time. Select a single time before saving.';
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(_startDate.year < 2000 ? _startDate.year : 2000),
      lastDate: DateTime(_startDate.year > 2100 ? _startDate.year : 2100, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _startDate = DateUtils.dateOnly(picked));
  }

  void _save() {
    final chosen = _selectedTimes.single;
    final original = widget.medication;
    final values = Medication(
      name: _medicationController.text.trim(),
      dose: _doseController.text.trim(),
      frequency: 'Once daily',
      times: chosen == null ? '' : MedicationSchedule.clock(chosen.hour, chosen.minute),
      numDays: int.tryParse(_daysController.text.trim()) ?? 0,
      startDate: _startDate,
    );
    final updated = original == null ? values : original.copyWith(
      name: values.name,
      dose: values.dose,
      frequency: values.frequency,
      times: values.times,
      numDays: values.numDays,
      startDate: values.startDate,
    );
    try {
      MedicationSchedule.validateCandidate(
        updated,
        widget.otherMedications,
        fallbackStartDate: widget.fallbackStartDate,
      );
    } on MedicationScheduleException catch (error) {
      setState(() => _errorMessage = error.message);
      return;
    }
    Navigator.pop(context, updated);
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _doseController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index] ?? TimeOfDay.now(),
    );

    if (mounted && picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.medication == null ? "Add Medication" : "Edit Medication",
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medication Name
            TextField(
              controller: _medicationController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Medication Name (Methadone only)",
                labelStyle: TextStyles.font14Hint500Weight,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[400]!),
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

            // Dose
            TextField(
              controller: _doseController,
              decoration: InputDecoration(
                labelText: "Dose",
                labelStyle: TextStyles.font14Hint500Weight,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[400]!),
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

            // Frequency Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "How often will the medication be taken?",
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
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

                  if (_selectedTimes.length >= _numTimesPerDay) {
                    _selectedTimes = _selectedTimes.sublist(0, _numTimesPerDay);
                  } else {
                    _selectedTimes = [
                      ..._selectedTimes,
                      ...List.filled(
                        _numTimesPerDay - _selectedTimes.length,
                        null,
                      ),
                    ];
                  }
                });
              },
            ),
            SizedBox(height: 20.h),

            // Time Inputs
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

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(MedicationSchedule.dateLabel(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStartDate,
            ),
            SizedBox(height: 12.h),

            // Number of Days
            TextField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Number of Days",
                labelStyle: TextStyles.font14Hint500Weight,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[400]!),
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

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(
                  widget.medication == null ? "Add Medication" : "Save Changes",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
