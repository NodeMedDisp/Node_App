import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gap/gap.dart';
import 'enter_medication_data.dart';
import '../LoginComp/theming/styles.dart';
import '../Helpers/rive_controller.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';

class GetStartedPage extends StatefulWidget {
  final BluetoothDevice? device;
  final bool isMockDevice;

  const GetStartedPage({
    super.key,
    this.device,
    this.isMockDevice = false,
  });

  @override
  _GetStartedPageState createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final RiveAnimationControllerHelper riveHelper =
      RiveAnimationControllerHelper();

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
      debugPrint(
        'TRACE 2 GET STARTED -> PRESCRIPTION: ${widget.device?.remoteId}',
      );
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final maxWidth = constraints.maxWidth;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Column(
                children: [
                  // Logo (scales automatically)
                  SizedBox(
                    height: maxHeight * 0.18,
                    child: FittedBox(
                      child: Image.asset('assets/images/NodeLogo.png'),
                    ),
                  ),

                  // Rive animation (scales with screen)
                  SizedBox(
                    height: maxHeight * 0.35,
                    child: riveHelper.riveArtboard != null
                        ? rive.Rive(
                            artboard: riveHelper.riveArtboard!,
                            fit: BoxFit.contain,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),

                  const Spacer(),

                  // Main button
                  SizedBox(
                    width: maxWidth * 0.9,
                    child: ElevatedButton(
                      onPressed: widget.device != null || isMock
                          ? _navigateToPrescriptionData
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: maxHeight * 0.02,
                        ),
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
                  ),

                  Gap(maxHeight * 0.02),

                  // Debug button
                  SizedBox(
                    width: maxWidth * 0.9,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GetStartedPage(
                              device: null,
                              isMockDevice: true,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(
                          vertical: maxHeight * 0.015,
                        ),
                      ),
                      child: const Text(
                        'Debug: Use Mock BLE Device',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    riveHelper.dispose();
    super.dispose();
  }
}
