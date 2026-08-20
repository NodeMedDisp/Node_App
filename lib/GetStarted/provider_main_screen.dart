import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../HomePage/calendar_widg.dart';
import '../LoginComp/logic/provider/provider_cubit.dart';
import '../LoginComp/logic/provider/provider_state.dart';
import '../LoginComp/routing/routes.dart';
import '../Bluetooth/bluetooth_trial.dart';
import 'enter_medication_data.dart';
import 'enter_counseling_data.dart';
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
      body: Row(
        children: [
          // LEFT SIDE — USER LIST
          Expanded(
            flex: 3,
            child: BlocBuilder<ProviderCubit, ProviderState>(
              builder: (context, state) {
                final users = state.users;
                final selectedUser = state.selectedUser;
                
                debugPrint(
                  'PROVIDER MAIN BUILD: '
                  'patient=${selectedUser?.id} '
                  'medications=${state.selectedMedications.length} '
                  'prompts=${state.selectedPrompts.length}',
                );

                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (users.isEmpty) {
                  return const Center(child: Text("No users found."));
                }

                return ListView.separated(
                  padding: EdgeInsets.all(12.w),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final user = users[i];
                    final isSelected = selectedUser?.id == user.id;

                    return ListTile(
                      tileColor: isSelected
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.transparent,
                      title: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text("Device: ${user.deviceId}"),
                      onTap: () {
                        debugPrint(
                          'PROVIDER MAIN: Selected patient '
                          'id=${user.id} name=${user.displayName}',
                        );

                        context.read<ProviderCubit>().selectUser(user);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // RIGHT SIDE — CALENDAR
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: BlocBuilder<ProviderCubit, ProviderState>(
                builder: (context, state) {
                  final selectedUser = state.selectedUser;

                  if (selectedUser == null) {
                    return const Center(
                      child: Text("Select a user to view their recovery calendar."),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Header
                      Text(
                        "Viewing: ${selectedUser.displayName}",
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12.h),
                      
                      // Uniform Action Buttons below header
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.medication),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<ProviderCubit>(),
                                      child: const EnterPrescriptionData(),
                                    ),
                                  ),
                                );
                              },
                              label: const Text("Add Medication"),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.question_answer),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<ProviderCubit>(),
                                      child: EnterCounselingPrompts(
                                        medications: state.selectedMedications,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              label: const Text("Add Prompt"),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: const Text('View or Edit Full Program'),
                          onPressed: () {
                            final providerCubit =
                                context.read<ProviderCubit>();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: providerCubit,
                                  child:
                                      const ProviderProgramEditorScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      SizedBox(height: 16.h),
                      Expanded(
                        child: CalendarWidget(
                          key: _calendarKey,

                          dataOwnerId: selectedUser.id,

                          prompts: state.selectedPrompts,
                          medications: state.selectedMedications,

                          StartDate:
                              selectedUser.startDate ?? DateTime.now(),

                          externalFocusDay:
                              selectedUser.latestEntryDate,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
