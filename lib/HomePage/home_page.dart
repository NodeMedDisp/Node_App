import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Bluetooth library
import '../GetStarted/get_started.dart';
import '/../LoginComp/logic/cubit/auth_cubit.dart'; // Import your AuthCubit
import '/../LoginComp/screens/login/ui/login_screen.dart'; // Import your LoginScreen
import '/HomePage/calendar_widg.dart'; // Import your CalendarWidget
import '/../Bluetooth/bluetooth_trial.dart'; // Import the Bluetooth Setup Screen

class HomePage extends StatefulWidget {
  final List<Map<String, dynamic>> prompts;
  final List<Map<String, String>> medications;

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

  @override
  void initState() {
    super.initState();
    _checkBluetoothConnection(); // Check Bluetooth connection on init
  }

  // Check Bluetooth connection status
  void _checkBluetoothConnection() async {
    // Get the connected devices
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;

    if (connectedDevices.isNotEmpty) {
      setState(() {
        isBluetoothConnected = true; // Mark as connected if any devices found
      });
    } else {
      setState(() {
        isBluetoothConnected = false; // No connected devices
      });

      // If not connected, show the pairing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBluetoothDialog();
      });
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
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BLEScannerWidget(), // Navigate to Bluetooth setup page
                  ),
                );
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
              onPressed: () {
                // Navigate to Bluetooth setup page when the icon is clicked
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BLEScannerWidget()),
                );
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
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
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
                    final connectedDevices = await FlutterBluePlus.connectedSystemDevices;

                    if (connectedDevices.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GetStartedPage(device: connectedDevices.first),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No Bluetooth device found')),
                      );
                    }
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