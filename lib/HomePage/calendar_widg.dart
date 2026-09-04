import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../GetStarted/enter_counseling_data.dart';
import '../GetStarted/enter_medication_data.dart';
import '../GetStarted/get_started.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '/../../LoginComp/theming/styles.dart';
import '/../../LoginComp/theming/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/medication.dart';
import '../models/counseling_question.dart';

class CalendarWidget extends StatefulWidget {
  final List<CounselingQuestion> prompts;
  final List<Medication> medications;
  final DateTime StartDate;
  final DateTime? externalFocusDay;
  final Map<DateTime, List<Map<String, dynamic>>>? externalRecoveryProgress;

  /// Identifies whose data is currently being displayed.
  /// For provider mode this is the selected Firestore patient ID.
  final String? dataOwnerId;

  const CalendarWidget({
    super.key,
    required this.prompts,
    required this.medications,
    required this.StartDate,
    this.externalFocusDay,
    this.externalRecoveryProgress,
    this.dataOwnerId,
  });

  @override
  CalendarWidgetState createState() => CalendarWidgetState();
}

class CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool isBluetoothConnected = false;
  BluetoothCharacteristic? fileCharacteristic;
  String fileContent = "";

  Map<DateTime, List<Map<String, dynamic>>> recoveryProgress = {};

  String _formatProgressEntry(Map<String, dynamic> entry) {
    switch (entry["type"]) {
      case "medication":
        return "Medication Taken: ${entry["time"]}";
      case "prompt":
        return "${entry["question"]}\nResponse: ${entry["response"]}";
      default:
        return entry.toString();
    }
  }

  bool _hasRewardsForDay(DateTime day) {
    final promptHasReward = _getPromptsForDay(day).any(
      (prompt) => prompt.streakEnabled || prompt.tokenEnabled,
    );

    final medicationHasReward = _getMedicationsForDay(day).any(
      (medication) => medication.streakEnabled || medication.tokenEnabled,
    );

    return promptHasReward || medicationHasReward;
  }

  Widget _calendarDayContent(
    DateTime day,
    Color textColor,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Text(
            '${day.day}',
            style: TextStyle(color: textColor),
          ),
        ),
        if (_hasRewardsForDay(day))
          Positioned(
            right: 3,
            bottom: 2,
            child: Icon(
              Icons.stars,
              size: 11,
              color: Colors.amber.shade700,
            ),
          ),
      ],
    );
  }

  List<Widget> _rewardChips({
    required bool streakEnabled,
    required String streakTitle,
    required String streakThreshold,
    required bool tokenEnabled,
    required String tokenTitle,
    required String tokenThreshold,
    required int tokenQuantity,
  }) {
    final chips = <Widget>[];

    if (streakEnabled) {
      final title = streakTitle.trim().isEmpty ? 'Streak' : streakTitle.trim();

      chips.add(
        Tooltip(
          message: 'Streak threshold: $streakThreshold',
          child: Chip(
            avatar: const Icon(
              Icons.local_fire_department,
              size: 15,
            ),
            label: Text(
              title,
              style: TextStyle(fontSize: 10.sp),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    if (tokenEnabled) {
      final title = tokenTitle.trim().isEmpty ? 'Token' : tokenTitle.trim();

      chips.add(
        Tooltip(
          message: 'Token threshold: $tokenThreshold',
          child: Chip(
            avatar: const Icon(
              Icons.monetization_on,
              size: 15,
            ),
            label: Text(
              '$tokenQuantity × $title',
              style: TextStyle(fontSize: 10.sp),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return chips;
  }

  String _rewardDetails({
    required bool streakEnabled,
    required String streakTitle,
    required String streakThreshold,
    required bool tokenEnabled,
    required String tokenTitle,
    required String tokenThreshold,
    required int tokenQuantity,
  }) {
    final lines = <String>[];

    if (streakEnabled) {
      lines.add(
        'Streak: '
        '${streakTitle.trim().isEmpty ? 'Enabled' : streakTitle.trim()}',
      );
      lines.add(
        'Streak threshold: '
        '${streakThreshold.trim().isEmpty ? 'None' : streakThreshold.trim()}',
      );
    }

    if (tokenEnabled) {
      lines.add(
        'Token: '
        '${tokenTitle.trim().isEmpty ? 'Enabled' : tokenTitle.trim()}',
      );
      lines.add(
        'Token threshold: '
        '${tokenThreshold.trim().isEmpty ? 'None' : tokenThreshold.trim()}',
      );
      lines.add('Token quantity: $tokenQuantity');
    }

    if (lines.isEmpty) {
      return 'Rewards: None';
    }

    return 'Rewards:\n${lines.join('\n')}';
  }

  @override
  void initState() {
    super.initState();

    _focusedDay = widget.externalFocusDay ?? widget.StartDate;
    _selectedDay = _focusedDay;

    // If we are in the provider dashboard, we don't want to load local Hive progress
    // as that would show the current device's user data for EVERY patient.
    bool isProvider = false;
    try {
      isProvider = context.read<ProviderCubit>().state.selectedUser != null;
    } catch (_) {}

    if (!isProvider) {
      _loadRecoveryProgress();
    }

    if (widget.externalRecoveryProgress != null) {
      recoveryProgress = {
        ...recoveryProgress,
        ...widget.externalRecoveryProgress!,
      };
    }

    checkBluetoothConnection();
  }

  @override
  void didUpdateWidget(covariant CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final patientChanged =
        oldWidget.dataOwnerId != widget.dataOwnerId;

    final recoveryChanged =
        oldWidget.externalRecoveryProgress !=
            widget.externalRecoveryProgress;

    if (patientChanged) {
      debugPrint(
        'CALENDAR: Data owner changed '
        '${oldWidget.dataOwnerId} -> ${widget.dataOwnerId}',
      );

      _focusedDay =
          widget.externalFocusDay ?? widget.StartDate;

      _selectedDay = _focusedDay;

      // Clear the previous patient's recovery data.
      recoveryProgress.clear();

      // Load the newly selected patient's cloud recovery data.
      if (widget.externalRecoveryProgress != null) {
        recoveryProgress.addAll(
          widget.externalRecoveryProgress!,
        );
      }

      debugPrint(
        'CALENDAR: Loaded recovery after patient change '
        'owner=${widget.dataOwnerId} '
        'days=${recoveryProgress.length}',
      );

      return;
    }

    // Same patient, but Firestore sent updated recovery data.
    if (recoveryChanged) {
      recoveryProgress = {
        ...?widget.externalRecoveryProgress,
      };

      debugPrint(
        'CALENDAR: Cloud recovery updated '
        'owner=${widget.dataOwnerId} '
        'days=${recoveryProgress.length}',
      );
    }
  }

  void focusOn(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
  }

  List<CounselingQuestion> _getPromptsForDay(DateTime day) {
    return widget.prompts.where((prompt) {
      final numberOfDays = prompt.numberOfDays;
      final activityStart = prompt.startDate ?? widget.StartDate;
      final activityEnd = activityStart.add(Duration(days: numberOfDays - 1));

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart =
          DateTime(activityStart.year, activityStart.month, activityStart.day);
      final normalizedEnd =
          DateTime(activityEnd.year, activityEnd.month, activityEnd.day);

      return normalizedDay
              .isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
          normalizedDay.isBefore(normalizedEnd.add(const Duration(days: 1)));
    }).toList();
  }

  List<Medication> _getMedicationsForDay(DateTime day) {
    return widget.medications.where((medication) {
      final numDays = medication.numDays;
      if (numDays == 0) return false;

      final medicationStartDay = medication.startDate ?? widget.StartDate;
      final lastMedicationDay =
          medicationStartDay.add(Duration(days: numDays - 1));

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart = DateTime(medicationStartDay.year,
          medicationStartDay.month, medicationStartDay.day);
      final normalizedEnd = DateTime(lastMedicationDay.year,
          lastMedicationDay.month, lastMedicationDay.day);

      return normalizedDay
              .isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
          normalizedDay.isBefore(normalizedEnd.add(const Duration(days: 1)));
    }).toList();
  }

  bool _hasScheduledItemsForDay(DateTime day) {
    return _getPromptsForDay(day).isNotEmpty ||
        _getMedicationsForDay(day).isNotEmpty;
  }

  Future<void> checkBluetoothConnection() async {
    final List<BluetoothDevice> connectedDevices =
        FlutterBluePlus.connectedDevices;
    if (connectedDevices.isNotEmpty) {
      setState(() {
        isBluetoothConnected = true;
      });
      await _discoverServices(connectedDevices.first);
    } else {
      setState(() {
        isBluetoothConnected = false;
      });
    }
  }

  Future<void> _saveRecoveryProgress(
      DateTime date, List<Map<String, dynamic>> progress) async {
    final box = Hive.box<Map>('calendarData');
    final formattedDate =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final uniqueProgress = progress.toSet().toList();
    box.put(formattedDate, {'progress': uniqueProgress});
  }

  void _loadRecoveryProgress() {
    final box = Hive.box<Map>('calendarData');
    final keys = box.keys;
    for (final key in keys) {
      final data = box.get(key);
      if (data != null && data['progress'] != null) {
        final date = DateTime.parse(key as String);
        recoveryProgress[date] =
            List<Map<String, dynamic>>.from(data['progress']);
      }
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((data) {
            _handleFileData(data);
          });
          setState(() {
            fileCharacteristic = characteristic;
          });
        }
      }
    }
  }

  void _handleFileData(List<int> data) {
    setState(() {
      String chunk = utf8.decode(data);
      fileContent += chunk;
      _parseProgressData(fileContent);
      _writeRecoveryDataFile(fileContent);
    });
  }

  void _parseProgressData(String progressData) {
    final lines = progressData.split('\n');
    DateTime? currentDate;
    for (String rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith("Date:")) {
        final dateString = line.substring(5).trim();
        try {
          currentDate = DateTime.parse(dateString);
        } catch (_) {
          currentDate = null;
        }
        continue;
      }
      if (currentDate == null || line.isEmpty) continue;
      final normalizedDate =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      final existing = recoveryProgress[normalizedDate] ?? [];
      Map<String, dynamic>? parsedEntry;
      if (line.startsWith("Medication Taken:")) {
        final time = line.replaceFirst("Medication Taken:", "").trim();
        parsedEntry = {"type": "medication", "time": time};
      } else if (line.startsWith("Prompt:")) {
        final withoutPrefix = line.replaceFirst("Prompt:", "").trim();
        final parts = withoutPrefix.split("Response:");
        final question = parts[0].trim();
        final response = parts.length > 1 ? parts[1].trim() : "";
        parsedEntry = {
          "type": "prompt",
          "question": question,
          "response": response
        };
      }
      if (parsedEntry != null) {
        if (!existing.any(
          (entry) => mapEquals(entry, parsedEntry),
        )) {
          recoveryProgress
              .putIfAbsent(
                normalizedDate,
                () => [],
              )
              .add(parsedEntry);

          // Keep the local Hive cache.
          _saveRecoveryProgress(
            normalizedDate,
            recoveryProgress[normalizedDate]!,
          );

          // Provider mode: also save to Firestore.
          try {
            final providerCubit =
                context.read<ProviderCubit>();

            if (providerCubit.state.selectedUser != null) {
              providerCubit.saveRecoveryProgress(
                date: normalizedDate,
                entries: [
                  Map<String, dynamic>.from(
                    parsedEntry,
                  ),
                ],
              );
            }
          } catch (error) {
            debugPrint(
              'CALENDAR: Cloud recovery save skipped/error: '
              '$error',
            );
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _getRecoveryProgressForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    if (recoveryProgress.containsKey(normalizedDate)) {
      return recoveryProgress[normalizedDate]!.toSet().toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'CALENDAR BUILD: '
      'owner=${widget.dataOwnerId} '
      'medications=${widget.medications.length} '
      'prompts=${widget.prompts.length}',
    );

    final promptsForDay = _getPromptsForDay(_selectedDay);
    final medicationsForDay = _getMedicationsForDay(_selectedDay);
    final recoveryProgressForDay = _getRecoveryProgressForDay(_selectedDay);

    bool isProvider = false;
    try {
      isProvider = context.read<ProviderCubit>().state.selectedUser != null;
    } catch (_) {}

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isProvider) ...[
                Wrap(
                  spacing: 2,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GetStartedPage()),
                        );
                      },
                      child: const Text('Go to Setup'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ProviderCubit? cubit;
                        try {
                          cubit = context.read<ProviderCubit>();
                        } catch (_) {}

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => cubit != null
                                ? BlocProvider.value(
                                    value: cubit,
                                    child: const EnterPrescriptionData())
                                : const EnterPrescriptionData(),
                          ),
                        );
                      },
                      child: const Text('Medications'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ProviderCubit? cubit;
                        try {
                          cubit = context.read<ProviderCubit>();
                        } catch (_) {}

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => cubit != null
                                ? BlocProvider.value(
                                    value: cubit,
                                    child: const EnterCounselingPrompts(
                                        medications: <Medication>[]))
                                : const EnterCounselingPrompts(
                                    medications: <Medication>[]),
                          ),
                        );
                      },
                      child: const Text(
                        'Counseling',
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
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
                    final normalizedDate =
                        DateTime(day.year, day.month, day.day);

                    final hasRecovery =
                        recoveryProgress[normalizedDate]?.isNotEmpty ?? false;

                    final hasScheduled =
                        _hasScheduledItemsForDay(normalizedDate);

                    return Container(
                      decoration: BoxDecoration(
                        color: hasRecovery
                            ? ColorsManager.mainGreen.withValues(alpha: 0.5)
                            : ColorsManager.mainBlue.withValues(alpha: 0.5),
                        border: hasScheduled && !hasRecovery
                            ? Border.all(
                                color: Colors.purple.withValues(alpha: 0.8),
                                width: 2.0,
                              )
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: _calendarDayContent(
                        day,
                        Colors.white,
                      ),
                    );
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final normalizedDate =
                        DateTime(day.year, day.month, day.day);

                    final hasRecovery =
                        recoveryProgress[normalizedDate]?.isNotEmpty ?? false;

                    final hasScheduled =
                        _hasScheduledItemsForDay(normalizedDate);

                    if (hasRecovery) {
                      return Container(
                        decoration: BoxDecoration(
                          color: ColorsManager.mainGreen.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: _calendarDayContent(
                          day,
                          Colors.white,
                        ),
                      );
                    }

                    if (hasScheduled) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.8),
                            width: 2.0,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: _calendarDayContent(
                          day,
                          Colors.black,
                        ),
                      );
                    }

                    return null;
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final normalizedDate =
                        DateTime(day.year, day.month, day.day);

                    final hasRecovery =
                        recoveryProgress[normalizedDate]?.isNotEmpty ?? false;

                    final hasScheduled =
                        _hasScheduledItemsForDay(normalizedDate);

                    return Container(
                      decoration: BoxDecoration(
                        color: hasRecovery
                            ? ColorsManager.mainGreen
                            : ColorsManager.mainBlue,
                        border: hasScheduled && !hasRecovery
                            ? Border.all(
                                color: Colors.purple,
                                width: 2.0,
                              )
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: _calendarDayContent(
                        day,
                        Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
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
                          color: ColorsManager.mainBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            _formatProgressEntry(progress),
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
                            color:
                                ColorsManager.mainBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                prompt.prompt,
                                style: TextStyle(fontSize: 14.sp),
                                textAlign: TextAlign.center,
                              ),
                              if (prompt.streakEnabled ||
                                  prompt.tokenEnabled) ...[
                                SizedBox(height: 6.h),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: _rewardChips(
                                    streakEnabled: prompt.streakEnabled,
                                    streakTitle: prompt.streakTitle,
                                    streakThreshold: prompt.streakThreshold,
                                    tokenEnabled: prompt.tokenEnabled,
                                    tokenTitle: prompt.tokenTitle,
                                    tokenThreshold: prompt.tokenThreshold,
                                    tokenQuantity: prompt.tokenQuantity,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
                        onTap: () =>
                            _showMedicationDetails(context, medication),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 40) / 3,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color:
                                ColorsManager.mainBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                medication.name,
                                style: TextStyle(fontSize: 14.sp),
                                textAlign: TextAlign.center,
                              ),
                              if (medication.streakEnabled ||
                                  medication.tokenEnabled) ...[
                                SizedBox(height: 6.h),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: _rewardChips(
                                    streakEnabled: medication.streakEnabled,
                                    streakTitle: medication.streakTitle,
                                    streakThreshold: medication.streakThreshold,
                                    tokenEnabled: medication.tokenEnabled,
                                    tokenTitle: medication.tokenTitle,
                                    tokenThreshold: medication.tokenThreshold,
                                    tokenQuantity: medication.tokenQuantity,
                                  ),
                                ),
                              ],
                            ],
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

  void _showPromptDetails(BuildContext context, CounselingQuestion prompt) {
    final rawOptions = prompt.options;
    String options;
    if (rawOptions is List<Map<String, dynamic>>) {
      options = rawOptions.map((e) => e.toString()).join(', ');
    } else if (rawOptions is List<String>) {
      options = rawOptions.join(', ');
    } else if (rawOptions is List) {
      options = rawOptions.map((e) => e.toString()).join(', ');
    } else {
      options = 'No options';
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(prompt.prompt),
          content: Text(
            "Required Response: ${prompt.resReq}\n"
            "Response Options: $options\n"
            "Duration: ${prompt.numberOfDays} day(s)\n\n"
            "${_rewardDetails(
              streakEnabled: prompt.streakEnabled,
              streakTitle: prompt.streakTitle,
              streakThreshold: prompt.streakThreshold,
              tokenEnabled: prompt.tokenEnabled,
              tokenTitle: prompt.tokenTitle,
              tokenThreshold: prompt.tokenThreshold,
              tokenQuantity: prompt.tokenQuantity,
            )}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _showMedicationDetails(BuildContext context, Medication medication) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(medication.name),
          content: Text(
            "Frequency: ${medication.frequency}\n"
            "Dose: ${medication.dose}\n"
            "Times: ${medication.times}\n"
            "Duration: ${medication.numDays} day(s)\n\n"
            "${_rewardDetails(
              streakEnabled: medication.streakEnabled,
              streakTitle: medication.streakTitle,
              streakThreshold: medication.streakThreshold,
              tokenEnabled: medication.tokenEnabled,
              tokenTitle: medication.tokenTitle,
              tokenThreshold: medication.tokenThreshold,
              tokenQuantity: medication.tokenQuantity,
            )}",
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
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/recovery_data.txt');
}

Future<void> _writeRecoveryDataFile(String content) async {
  try {
    final file = await _getRecoveryDataFile();
    await file.writeAsString(content);
  } catch (e) {
    print("Error writing file: $e");
  }
}
