import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theming/colors.dart';
import '../../theming/styles.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:intl/intl.dart';


class MedicationEntryPage extends StatefulWidget {
  final Map<String, String>? medication; // null = add mode

  const MedicationEntryPage({super.key, this.medication});

  @override
  _MedicationEntryPageState createState() => _MedicationEntryPageState();
}

class _MedicationEntryPageState extends State<MedicationEntryPage> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  String? _frequency;
  int _numTimesPerDay = 0;
  List<TimeOfDay?> _selectedTimes = [];

  @override
  void initState() {
    super.initState();

    if (widget.medication != null) {
      // Pre-fill basic fields
      _medicationController.text = widget.medication!['medication'] ?? '';
      _doseController.text = widget.medication!['dose'] ?? '';
      _daysController.text = widget.medication!['numberOfDays'] ?? '';
      _frequency = widget.medication!['frequency'];

      // Pre-fill times: parse the SAME format you used originally (time.format(context))
      final timesString = widget.medication!['times'];
      if (timesString != null && timesString.isNotEmpty) {
        final timeStrings = timesString.split(',');

        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        final formatter = DateFormat.jm(locale.toString());

        _selectedTimes = timeStrings.map((raw) {
          final t = raw.trim();
          try {
            final dt = formatter.parse(t);
            return TimeOfDay(hour: dt.hour, minute: dt.minute);
          } catch (_) {
            // If parsing fails for any reason, skip this time
            return null;
          }
        }).toList();

        _numTimesPerDay = _selectedTimes.length;
      } else {
        _selectedTimes = [];
        _numTimesPerDay = 0;
      }
    }
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index] ?? TimeOfDay.now(),
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
              decoration: InputDecoration(
                labelText: "Medication Name",
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

            // Frequency Dropdown (your exact style/logic)
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

                  // Keep as many existing times as possible when frequency changes
                  if (_selectedTimes.length >= _numTimesPerDay) {
                    _selectedTimes =
                        _selectedTimes.sublist(0, _numTimesPerDay);
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

            // Time Inputs based on selected frequency
            if (_numTimesPerDay > 0) ...[
              Column(
                children: List.generate(_numTimesPerDay, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h), // Adjust spacing here
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

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Use the SAME format you use in enter_medication_data.dart
                  final times = _selectedTimes
                      .where((time) => time != null)
                      .map((time) => time!.format(context))  // Format the TimeOfDay as a readable string
                      .toList();

                  Navigator.pop(context, {
                    'medication': _medicationController.text,
                    'dose': _doseController.text,
                    'frequency': _frequency ?? '',
                    'numberOfDays': _daysController.text,
                    "times": times.join(', '),
                  });
                },
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