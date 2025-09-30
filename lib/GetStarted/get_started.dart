import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gap/gap.dart';
import 'NIU surgery_selection_screen.dart';
import 'enter_prescription_data.dart';
import '../LoginComp/theming/styles.dart';
import '../Helpers/rive_controller.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Add this import if you want to differentiate mock mode visually
import 'package:flutter/services.dart'; // Optional for haptic feedback

class GetStartedPage extends StatefulWidget {
  final BluetoothDevice? device;
  final bool isMockDevice; // NEW: flag to indicate mock mode

  const GetStartedPage({super.key, this.device, this.isMockDevice = false});

  @override
  _GetStartedPageState createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final RiveAnimationControllerHelper riveHelper = RiveAnimationControllerHelper();

  @override
  void initState() {
    super.initState();
    riveHelper.loadRiveFile('assets/animations/char1.riv').then((_) {
      setState(() {});
    });
  }

  void _triggerRiveJumpAnimation() {
    riveHelper.addJumpController();
  }

  void _navigateToPrescriptionData() {
    _triggerRiveJumpAnimation();

    Future.delayed(const Duration(milliseconds: 1000), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnterPrescriptionData(device: widget.device),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMock = widget.isMockDevice;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/NodeLogo.png',
                height: 200.h,
                width: 200.w,
              ),
              Gap(0.h),
              SizedBox(
                height: 300.h,
                width: 300.w,
                child: riveHelper.riveArtboard != null
                    ? rive.Rive(
                  artboard: riveHelper.riveArtboard!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                )
                    : const CircularProgressIndicator(),
              ),
              const Spacer(),

              // Main button
              ElevatedButton(
                onPressed: widget.device != null || isMock ? _navigateToPrescriptionData : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  isMock
                      ? 'Simulating recovery with a mock device. Let’s get started!'
                      : 'Sunny will help you with your patient’s recovery. Let’s get started!',
                  textAlign: TextAlign.center,
                  style: TextStyles.font14Blue400Weight,
                ),
              ),

              Gap(20.h),

              // Debug button for testing without Bluetooth
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GetStartedPage(
                        device: null,
                        isMockDevice: true, // NEW: enable mock mode
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
                ),
                child: const Text(
                  'Debug: Use Mock BLE Device',
                  style: TextStyle(color: Colors.black),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    riveHelper.dispose();
  }
}