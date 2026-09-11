import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Bluetooth library
import '../GetStarted/get_started.dart';
import '/../LoginComp/logic/cubit/auth_cubit.dart'; // Import your AuthCubit
import '/../LoginComp/screens/login/ui/login_screen.dart'; // Import your LoginScreen
import '/HomePage/calendar_widg.dart'; // Import your CalendarWidget
import '/../Bluetooth/bluetooth_trial.dart'; // Import the Bluetooth Setup Screen
import '../models/medication.dart';
import '../models/counseling_question.dart';
import '../GetStarted/enter_medication_data.dart';
import '../GetStarted/counseling_questions_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomePage extends StatefulWidget {
  final List<CounselingQuestion> prompts;
  final List<Medication> medications;

  const HomePage({
    super.key,
    required this.prompts,
    required this.medications,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool isBluetoothConnected = false; // Track Bluetooth connection status
  BluetoothDevice? selectedBluetoothDevice;

  @override
  void initState() {
    super.initState();
    _checkBluetoothConnection(); // Check Bluetooth connection on init
  }

  // Check Bluetooth connection status
  Future<void> _checkBluetoothConnection() async {
    try {
      final connectedDevices = await FlutterBluePlus.connectedDevices;

      if (!mounted) return;

      if (connectedDevices.isNotEmpty) {
        final BluetoothDevice restoredDevice = connectedDevices.first;

        setState(() {
          selectedBluetoothDevice = restoredDevice;
          isBluetoothConnected = true;
        });

        debugPrint(
          'HOME: Restored connected device '
          '${restoredDevice.remoteId}',
        );
      } else {
        setState(() {
          selectedBluetoothDevice = null;
          isBluetoothConnected = false;
        });

        debugPrint('HOME: No connected Bluetooth device found');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showBluetoothDialog();
          }
        });
      }
    } catch (error, stackTrace) {
      debugPrint('HOME: Bluetooth connection check failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        selectedBluetoothDevice = null;
        isBluetoothConnected = false;
      });
    }
  }

  Future<BluetoothDevice?> _getConnectedProgrammingDevice() async {
    try {
      final List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;

      if (connectedDevices.isEmpty) {
        debugPrint('PROGRAMMING DEVICE: No connected device found');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No Bluetooth device is connected. Connect the NODE device first.',
              ),
            ),
          );
        }

        return null;
      }

      final BluetoothDevice device = connectedDevices.first;

      debugPrint(
        'PROGRAMMING DEVICE FOUND: '
        '${device.platformName} — ${device.remoteId}',
      );

      return device;
    } catch (error, stackTrace) {
      debugPrint('Could not get connected Bluetooth device: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access Bluetooth device: $error'),
          ),
        );
      }

      return null;
    }
  }

  void _onDaySelected(DateTime selectedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
  }

  // Bluetooth pairing pop-up dialog
  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Welcome to NODE Recovery!!!'),
          content: const Text('Pair a device to configure or view data.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog first

                final device = await Navigator.push<BluetoothDevice>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BLEScannerWidget(),
                  ),
                );

                if (device != null) {
                  setState(() {
                    selectedBluetoothDevice = device;
                    isBluetoothConnected = true;
                  });

                  debugPrint(
                      "DEBUG: HomePage stored BLE device: ${device.remoteId}");
                }
              },
              child: const Text('Pair Device'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is UserSignedOut) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bluetooth),
              onPressed: () async {
                // Navigate to Bluetooth setup page when the icon is clicked
                final device = await Navigator.push<BluetoothDevice>(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BLEScannerWidget()),
                );

                if (device != null) {
                  setState(() {
                    selectedBluetoothDevice = device;
                    isBluetoothConnected = true;
                  });

                  debugPrint(
                      "DEBUG: HomePage stored BLE device: ${device.remoteId}");
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<AuthCubit>().signOut();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/NodeLogo.png',
                  height: 100.h,
                  width: 200.w,
                ),
                SizedBox(height: 10.h),
                Text(
                  "Welcome to Node Recovery!",
                  style:
                      TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  height: 450.h,
                  child: CalendarWidget(
                    prompts: widget.prompts,
                    medications: widget.medications,
                    StartDate: DateTime.now(),
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () async {
                    final BluetoothDevice? device = selectedBluetoothDevice;

                    debugPrint(
                      'HOME -> GET STARTED: '
                      '${device?.remoteId ?? 'NULL DEVICE'}',
                    );

                    if (device == null) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No Bluetooth device is selected. Connect to the device first.',
                          ),
                        ),
                      );

                      return;
                    }
                    debugPrint(
                      'TRACE 1 HOME -> GET STARTED: ${device.remoteId}',
                    );
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GetStartedPage(
                          device: device,
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
