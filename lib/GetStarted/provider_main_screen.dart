import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../HomePage/calendar_widg.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/logic/provider/provider_state.dart';
import '../LoginComp/routing/routes.dart';
import '../Bluetooth/bluetooth_trial.dart';
import 'provider_program_editor_screen.dart';
import '../Bluetooth/node_ble_file_transfer_service.dart';
import '../Bluetooth/recovery_program_file_formatter.dart';

class ProviderMainScreen extends StatefulWidget {
  final String? clinicCode;

  const ProviderMainScreen({super.key, this.clinicCode});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  final GlobalKey<CalendarWidgetState> _calendarKey = GlobalKey<CalendarWidgetState>();

  Future<void> _showCreatePatientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final deviceIdController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create New Patient'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Patient name',
                      hintText: 'Enter the patient name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the patient name.';
                      }

                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: deviceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final displayName = nameController.text.trim();
    final deviceId = deviceIdController.text.trim();

    nameController.dispose();
    deviceIdController.dispose();

    if (shouldCreate != true || !mounted) {
      return;
    }

    try {
      await context.read<ProviderCubit>().createPatient(
        displayName: displayName,
        deviceId: deviceId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('$displayName was created.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('PROVIDER CREATE PATIENT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Could not create patient: $error',
          ),
        ),
      );
    }
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Connection'),
          content: const Text('Pair a device to configure or view data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _navigateToScanner();
              },
              child: const Text('Pair Device'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToScanner() async {
    final providerCubit = context.read<ProviderCubit>();

    final device = await Navigator.push<BluetoothDevice>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: providerCubit,
          child: const BLEScannerWidget(),
        ),
      ),
    );

    if (!mounted || device == null) {
      return;
    }

    await _sendSelectedPatientProgram(device);
  }

  Future<void> _sendSelectedPatientProgram(
    BluetoothDevice device,
  ) async {
    final state = context.read<ProviderCubit>().state;
    final selectedPatient = state.selectedUser;

    if (selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a patient before configuring NODE.',
          ),
        ),
      );
      return;
    }

    if (state.selectedMedications.isEmpty &&
        state.selectedPrompts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected patient has no recovery program to send.',
          ),
        ),
      );
      return;
    }

    final fileContent = RecoveryProgramFileFormatter.build(
      medications: state.selectedMedications,
      prompts: state.selectedPrompts,
    );

    debugPrint(
      'PROVIDER BLE: Sending program '
      'patient=${selectedPatient.id} '
      'medications=${state.selectedMedications.length} '
      'prompts=${state.selectedPrompts.length} '
      'device=${device.remoteId}',
    );

    try {
      await const NodeBleFileTransferService().send(
        device: device,
        fileContents: fileContent,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '${selectedPatient.displayName} was sent to NODE.',
          ),
        ),
      );

      await _calendarKey.currentState
          ?.checkBluetoothConnection();
    } catch (error, stackTrace) {
      debugPrint('PROVIDER BLE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Could not configure NODE: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Provider Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            color: _calendarKey.currentState?.isBluetoothConnected == true
                ? Colors.blue
                : Colors.grey,
            onPressed: () async {
              final connectedDevices =
                  FlutterBluePlus.connectedDevices;

              if (connectedDevices.isEmpty) {
                _showBluetoothDialog();
                return;
              }

              await _sendSelectedPatientProgram(
                connectedDevices.first,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.loginScreen,
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: BlocBuilder<ProviderCubit, ProviderState>(
          builder: (context, state) {
            final users = state.users;
            final selectedUser = state.selectedUser;

            final selectedUserId =
                selectedUser != null &&
                        users.any((user) => user.id == selectedUser.id)
                    ? selectedUser.id
                    : null;

            debugPrint(
              'PROVIDER MAIN BUILD: '
              'patient=${selectedUser?.id} '
              'medications=${state.selectedMedications.length} '
              'prompts=${state.selectedPrompts.length}',
            );

            if (state.loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PATIENT DROPDOWN AND CREATE-PATIENT BUTTON
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Patient',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUserId,
                            isExpanded: true,
                            hint: Text(
                              users.isEmpty
                                  ? 'No patients yet'
                                  : 'Select a patient',
                            ),
                            items: users.map((user) {
                              final deviceDescription =
                                  user.deviceId.trim().isEmpty
                                      ? ''
                                      : ' — ${user.deviceId}';

                              return DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(
                                  '${user.displayName}$deviceDescription',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: users.isEmpty
                                ? null
                                : (patientId) {
                                    if (patientId == null) {
                                      return;
                                    }

                                    final patient = users.firstWhere(
                                      (user) => user.id == patientId,
                                    );

                                    debugPrint(
                                      'PROVIDER MAIN: Selected patient '
                                      'id=${patient.id} '
                                      'name=${patient.displayName}',
                                    );

                                    context
                                        .read<ProviderCubit>()
                                        .selectUser(patient);
                                  },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    FilledButton.icon(
                      onPressed: _showCreatePatientDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Create Patient'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 18.h,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                Expanded(
                  child: selectedUser == null
                      ? Center(
                          child: Text(
                            users.isEmpty
                                ? 'Create your first patient to begin.'
                                : 'Select a patient to view their recovery calendar.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SELECTED PATIENT HEADER AND PROGRAM EDITOR
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Viewing: ${selectedUser.displayName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text(
                                    'View or Edit Full Program',
                                  ),
                                  onPressed: () {
                                    final providerCubit =
                                        context.read<ProviderCubit>();

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BlocProvider.value(
                                          value: providerCubit,
                                          child: const
                                              ProviderProgramEditorScreen(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            SizedBox(height: 16.h),

                            // SELECTED PATIENT CALENDAR
                            Expanded(
                              child: CalendarWidget(
                                key: _calendarKey,
                                dataOwnerId: selectedUser.id,
                                prompts: state.selectedPrompts,
                                medications: state.selectedMedications,
                                StartDate:
                                    selectedUser.startDate ??
                                        DateTime.now(),
                                externalFocusDay:
                                    selectedUser.latestEntryDate,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}