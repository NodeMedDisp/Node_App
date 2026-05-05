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

class ProviderMainScreen extends StatefulWidget {
  final String? clinicCode;

  const ProviderMainScreen({super.key, this.clinicCode});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  final GlobalKey<CalendarWidgetState> _calendarKey = GlobalKey<CalendarWidgetState>();

  @override
  void initState() {
    super.initState();
    context.read<ProviderCubit>().loadClinicData(widget.clinicCode);
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
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToScanner();
              },
              child: const Text('Pair Device'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BLEScannerWidget()),
    ).then((_) {
      _calendarKey.currentState?.checkBluetoothConnection();
      setState(() {}); 
    });
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
              List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
              if (connectedDevices.isEmpty) {
                _showBluetoothDialog();
              } else {
                _navigateToScanner();
              }
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
                        context.read<ProviderCubit>().selectUser(user);
                        if (user.latestEntryDate != null) {
                          _calendarKey.currentState?.focusOn(user.latestEntryDate!);
                        }
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
                                        medications: state.demoMedications,
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
                      
                      SizedBox(height: 16.h),
                      Expanded(
                        child: CalendarWidget(
                          key: _calendarKey,
                          prompts: state.demoPrompts,
                          medications: state.demoMedications,
                          StartDate: selectedUser.startDate ?? DateTime.now(),
                          externalFocusDay: selectedUser.latestEntryDate,
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
