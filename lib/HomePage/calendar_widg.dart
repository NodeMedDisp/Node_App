import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../GetStarted/enter_counseling_data.dart';
import '../GetStarted/enter_medication_data.dart';
import '../GetStarted/get_started.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CalendarWidget extends StatefulWidget {
  final List<Map<String, dynamic>> prompts;
  final List<Map<String, dynamic>> medications;
  final DateTime StartDate; // To calculate days for activities and medications

  const CalendarWidget({
    super.key,
    required this.prompts,
    required this.medications,
    required this.StartDate,
  });

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool isBluetoothConnected = false; // Track Bluetooth connection status
  BluetoothCharacteristic? fileCharacteristic; // For the file characteristic
  String fileContent = ""; // To store received file content

  Map<DateTime, List<String>> recoveryProgress =
      {}; // Stores progress entries by date

// Test content to simulate recovery progress data
  String testContent = '''
  Date: 2024-12-14
  Medication Taken: 13:58:40
  Prompt: How stressed are you today? Response: 7
  Prompt: Have you taken non-prescribed opioids in the past 24 hours? Response: No
  Prompt: Consider who your closest support network is. Response: Respond in Journal
  Date: 2024-12-15
  Medication Taken: 13:57:40
  Prompt: How stressed are you today? Response: 4
  Prompt: Have you taken non-prescribed opioids in the past 24 hours? Response: No
  Prompt: What makes you feel most calm? Response: Respond in Journal
  Date: 2024-12-16
  Medication Taken: 13:59:00
  Prompt: How stressed are you today? Response: 6
  Prompt: Have you taken non-prescribed opioids in the past 24 hours? Response: No
  Prompt: What are you proud about from yesterday? Response: Respond in Journal
  Date: 2025-01-07
  Medication Taken: 07:59:00
  Prompt: How stressed are you today? Response: 4
  Prompt: Have you taken non-prescribed opioids in the past 24 hours? Response: No
  Prompt: What are your goals for today? Response: Respond in Journal
  ''';


  @override
  void initState() {
    super.initState();
    _focusedDay = widget.StartDate;
    _selectedDay = widget.StartDate;

    // Load persisted data into memory
    _loadRecoveryProgress();

// Parse test content
 // _parseProgressData(testContent);

    _checkBluetoothConnection(); // Check Bluetooth connection on init
  }

  // Get prompts for day with Hive integration
  List<Map<String, dynamic>> _getPromptsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    final box = Hive.box<Map>('promptsData');

    // Retrieve stored prompts from Hive
    final storedData = box.get(normalizedDate.toIso8601String());
    final hivePrompts = storedData?['prompts'];

    // Parse Hive data safely
    final parsedHivePrompts = hivePrompts != null && hivePrompts is List
        ? hivePrompts.map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];

    // Calculate prompts from widget data
    final widgetPrompts = widget.prompts.where((prompt) {
      final numberOfDaysStr = prompt['numberOfDays'];
      if (numberOfDaysStr == null) return false;

      final numberOfDays = int.tryParse(numberOfDaysStr);
      if (numberOfDays == null) return false;

      final activityStart = widget.StartDate;
      final activityEnd = activityStart.add(Duration(days: numberOfDays - 1));

      final normalizedDay = DateTime(day.year, day.month, day.day);
      return normalizedDay.isAfter(activityStart.subtract(const Duration(days: 1))) &&
          normalizedDay.isBefore(activityEnd.add(const Duration(days: 1)));
    }).toList();

    // Merge prompts while avoiding duplicates
    final mergedPrompts = <Map<String, dynamic>>[
      ...parsedHivePrompts,
      ...widgetPrompts.where((newPrompt) =>
      !parsedHivePrompts.any((existing) => existing['prompt'] == newPrompt['prompt']))
    ];

    // Save merged data back to Hive only if it has changed
    if (mergedPrompts.length != parsedHivePrompts.length) {
      final updatedData = {'prompts': mergedPrompts};
      box.put(normalizedDate.toIso8601String(), updatedData);
    }

    return mergedPrompts;
  }

// Get medications for the specific day
  List<Map<String, dynamic>> _getMedicationsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    final box = Hive.box<Map>('medicationsData');

    // Retrieve stored medications from Hive
    final storedData = box.get(normalizedDate.toIso8601String());
    final hiveMedications = storedData?['medications'];

    // Parse Hive data safely
    final parsedHiveMedications = hiveMedications != null && hiveMedications is List
        ? hiveMedications.map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];

    // Parse widget medications
    final widgetMedications = widget.medications.where((medication) {
      // FIX: Support both old and new field names
      final numDaysStr = medication['numberOfDays'] ?? medication['numDays'];
      final numDays = int.tryParse(numDaysStr ?? '') ?? 0;

      // Prevent crashes if numDays is missing
      if (numDays == 0) return false;

      final medicationStartDay = widget.StartDate.add(Duration(days: -1));
      final lastMedicationDay =
      widget.StartDate.add(Duration(days: numDays - 1));

      return day.isAfter(medicationStartDay.subtract(const Duration(days: 1))) &&
          day.isBefore(lastMedicationDay.add(const Duration(days: 1)));
    }).toList();

    // Merge medications while avoiding duplicates
    final mergedMedications = <Map<String, dynamic>>[
      ...parsedHiveMedications,
      ...widgetMedications.where((newMedication) =>
      !parsedHiveMedications.any(
              (existing) => existing['medication'] == newMedication['medication']))
    ];

    // Save merged data back to Hive only if it has changed
    if (mergedMedications.length != parsedHiveMedications.length) {
      final updatedData = {'medications': mergedMedications};
      box.put(normalizedDate.toIso8601String(), updatedData);
    }

    return mergedMedications;
  }


// Check Bluetooth connection status and discover services
  void _checkBluetoothConnection() async {
// Get the connected devices
    List<BluetoothDevice> connectedDevices =
        await FlutterBluePlus.connectedDevices;

    if (connectedDevices.isNotEmpty) {
      setState(() {
        isBluetoothConnected = true; // Mark as connected if any devices found
      });

// Discover services and subscribe to the file characteristic
      await _discoverServices(connectedDevices.first);
    } else {
      setState(() {
        isBluetoothConnected = false; // No connected devices
      });
    }
  }

  Future<void> _saveRecoveryProgress(DateTime date, List<String> progress) async {
    final box = Hive.box<Map>('calendarData');
    final formattedDate = DateTime(date.year, date.month, date.day).toIso8601String();

    // Ensure only unique entries are saved
    final uniqueProgress = progress.toSet().toList();

    box.put(formattedDate, {'progress': uniqueProgress});
    print("Saved Recovery Progress for $formattedDate: ${uniqueProgress.length} items");
  }


  List<String> _retrieveRecoveryProgress(DateTime date) {
    final box = Hive.box<Map>('calendarData');
    final formattedDate =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final data = box.get(formattedDate);
    return data != null && data['progress'] != null
        ? List<String>.from(data['progress'])
        : [];
  }

  void _loadRecoveryProgress() {
    final box = Hive.box<Map>('calendarData');
    final keys = box.keys;

    for (final key in keys) {
      final data = box.get(key);
      if (data != null && data['progress'] != null) {
        final date = DateTime.parse(key as String);
        recoveryProgress[date] = List<String>.from(data['progress']);
      }
    }
  }

// Discover services and set up the characteristic for file reception
  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
// Subscribe to notifications for this characteristic
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((data) {
            _handleFileData(data);
          });

// Store the characteristic for later use
          setState(() {
            fileCharacteristic = characteristic;
          });
        }
      }
    }
  }

  void _handleFileData(List<int> data) {
    setState(() {
// Decode and append received data
      String chunk = utf8.decode(data);
      fileContent += chunk;

// Parse the updated file content into recovery progress
      _parseProgressData(fileContent);

// Optionally log the received chunk
      print("Received chunk: ${utf8.decode(data)}");

// Write the updated content to a writable file
      _writeRecoveryDataFile(fileContent);
    });
  }

  void _parseProgressData(String progressData) {
    List<String> lines = progressData.split('\n');
    DateTime? currentDate;

    for (String line in lines) {
      line = line.trim();

      if (line.startsWith("Date:")) {
        final dateString = line.substring(5).trim();
        try {
          currentDate = DateTime.parse(dateString);
        } catch (e) {
          currentDate = null;
          print("Invalid Date Format: $dateString");
        }
      } else if (currentDate != null && line.isNotEmpty) {
        final normalizedDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

        // Retrieve existing recovery progress for the day
        final existingProgress = recoveryProgress[normalizedDate] ?? [];

        // Add the new line only if it doesn't already exist
        if (!existingProgress.contains(line)) {
          recoveryProgress.putIfAbsent(normalizedDate, () => []).add(line);

          // Save the updated progress to Hive
          _saveRecoveryProgress(normalizedDate, recoveryProgress[normalizedDate]!);
        }
      }
    }

    print("Parsed Recovery Progress: $recoveryProgress");
  }


  List<String> _getRecoveryProgressForDay(DateTime day) {
    // Normalize the date
    final normalizedDate = DateTime(day.year, day.month, day.day);

    // Step 1: Check in-memory data
    if (recoveryProgress.containsKey(normalizedDate)) {
      return recoveryProgress[normalizedDate]!.toSet().toList(); // Return unique entries
    }

    // Step 2: Retrieve from Hive if not in memory
    try {
      final box = Hive.box<Map>('calendarData');
      final formattedDate = normalizedDate.toIso8601String();
      final data = box.get(formattedDate);

      if (data != null && data['progress'] != null) {
        final retrievedProgress = List<String>.from(data['progress']);
        recoveryProgress[normalizedDate] = retrievedProgress.toSet().toList(); // Cache unique entries
        return recoveryProgress[normalizedDate]!;
      }
    } catch (e) {
      print("Error retrieving recovery progress from Hive: $e");
    }

    // Step 3: Return empty list if no data is found
    return [];
  }



  @override
  Widget build(BuildContext context) {
    final promptsForDay = _getPromptsForDay(_selectedDay);
    final medicationsForDay = _getMedicationsForDay(_selectedDay);
    final recoveryProgressForDay = _getRecoveryProgressForDay(_selectedDay);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Navigation Buttons (responsive with Wrap) ---
              Wrap(
                spacing: 2,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GetStartedPage()),
                      );
                    },
                    child: const Text('Go to Setup'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EnterPrescriptionData()),
                      );
                    },
                    child: const Text('Medications'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EnterCounselingPrompts(medications: []),
                        ),
                      );
                    },
                    child: const Text(
                      'Counseling',
                      textAlign: TextAlign.center, // allow wrapping
                      softWrap: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Calendar widget ---
              TableCalendar(
                firstDay: DateTime(2020, 01, 01),
                lastDay: DateTime(2050, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                calendarBuilders: CalendarBuilders(
                  todayBuilder: (context, day, focusedDay) {
                    return Container(
                      decoration: BoxDecoration(
                        color: ColorsManager.mainBlue.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final normalizedDate = DateTime(day.year, day.month, day.day);
                    final isFutureDate = normalizedDate.isAfter(DateTime.now());
                    final promptsForDay = _getPromptsForDay(normalizedDate);
                    final medicationsForDay = _getMedicationsForDay(normalizedDate);

                    if (isFutureDate && (promptsForDay.isNotEmpty || medicationsForDay.isNotEmpty)) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.purple.withOpacity(0.8), width: 2.0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    }

                    if (recoveryProgress[normalizedDate]?.isNotEmpty ?? false) {
                      return Container(
                        decoration: BoxDecoration(
                          color: ColorsManager.mainGreen.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }

                    return null;
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return Container(
                      decoration: BoxDecoration(
                        color: ColorsManager.mainBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // --- Recovery Progress Section ---
              if (recoveryProgressForDay.isNotEmpty) ...[
                Center(
                  child: Text(
                    "Recovery Progress",
                    style: TextStyles.font14Blue400Weight,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: recoveryProgressForDay.map((progress) {
                      return Container(
                        width: (MediaQuery.of(context).size.width - 40) / 3,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: ColorsManager.mainBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            progress,
                            style: TextStyle(fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- Prompts Section ---
              if (promptsForDay.isNotEmpty) ...[
                Center(
                  child: Text(
                    "Prompts",
                    style: TextStyles.font14Blue400Weight,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: promptsForDay.map((prompt) {
                      return GestureDetector(
                        onTap: () => _showPromptDetails(context, prompt),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 40) / 3,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: ColorsManager.mainBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Center(
                            child: Text(
                              prompt['prompt']!,
                              style: TextStyle(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- Medications Section ---
              if (medicationsForDay.isNotEmpty) ...[
                Center(
                  child: Text(
                    "Medications",
                    style: TextStyles.font14Blue400Weight,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: medicationsForDay.map((medication) {
                      return GestureDetector(
                        onTap: () => _showMedicationDetails(context, medication),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 40) / 3,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: ColorsManager.mainBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Center(
                            child: Text(
                              medication['medication'] ?? "Unknown",
                              style: TextStyle(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

// Show progress details in a dialog, including options
  void _showProgressDetails(BuildContext context, fileContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Recovery Progress"),
          content: Text(fileContent),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

// Show prompt details in a dialog, including options
  void _showPromptDetails(BuildContext context, Map<String, dynamic> prompt) {
    final options = prompt['options'] != null
        ? (prompt['options'] as List<String>).join(', ')
        : 'No options';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(prompt['prompt']!),
          content: Text(
            "Required Response: ${prompt['resReq']}\n"
            "Response Options: $options\n"
            "Duration: ${prompt['numberOfDays']} day(s)",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

// Show medication details in a dialog
  void _showMedicationDetails(
      BuildContext context, Map<String, dynamic> medication) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(medication['medication']!),
          content: Text(
            "Frequency: ${medication['frequency']}\n"
            "Dose: ${medication['dose']}\n"
            "Times: ${medication['times']}\n"
            "Duration: ${medication['numDays']} day(s)",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}

Future<File> _getRecoveryDataFile() async {
  final directory =
      await getApplicationDocumentsDirectory(); // Or getTemporaryDirectory()
  return File('${directory.path}/recovery_data.txt');
}

Future<void> _writeRecoveryDataFile(String content) async {
  try {
    final file = await _getRecoveryDataFile();
    await file.writeAsString(content);
    print("File written successfully at ${file.path}");
  } catch (e) {
    print("Error writing file: $e");
  }
}

Future<String> _readRecoveryDataFile() async {
  try {
    final file = await _getRecoveryDataFile();
    if (await file.exists()) {
      return await file.readAsString();
    } else {
      print("File does not exist");
      return '';
    }
  } catch (e) {
    print("Error reading file: $e");
    return '';
  }
}

Future<void> _deleteRecoveryDataFile() async {
  try {
    final file = await _getRecoveryDataFile();
    if (await file.exists()) {
      await file.delete();
      print("File deleted successfully");
    } else {
      print("File does not exist, nothing to delete");
    }
  } catch (e) {
    print("Error deleting file: $e");
  }
}




