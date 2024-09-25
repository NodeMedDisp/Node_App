import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gap/gap.dart';
import 'surgery_selection_screen.dart';
import '../LoginComp/theming/styles.dart';
import '../Helpers/rive_controller.dart'; // Import the helper class

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  _GetStartedPageState createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final RiveAnimationControllerHelper riveHelper = RiveAnimationControllerHelper();

  @override
  void initState() {
    super.initState();
    // Load the Rive file when the page starts
    riveHelper.loadRiveFile('assets/animations/char1.riv').then((_) {
      setState(() {}); // Ensure the UI updates after the file is loaded
    });
  }

  void _triggerRiveJumpAnimation() {
    riveHelper.addJumpController(); // Trigger jump animation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Node logo at the top, centered, and larger
              Image.asset(
                'assets/images/NodeLogo.png',
                height: 200.h,
                width: 200.w,
              ),
              Gap(0.h),

              // Rive animation widget with "idle" animation as default
              SizedBox(
                height: 300.h,
                width: 300.w,
                child: riveHelper.riveArtboard != null
                    ? rive.Rive(
                  artboard: riveHelper.riveArtboard!,
                  fit: BoxFit.contain, // Adjust this to scale the animation appropriately
                  alignment: Alignment.center, // Make sure the alignment is centered
                )
                    : const CircularProgressIndicator(), // Loading state while Rive file loads
              ),
              const Spacer(),

              // Button to trigger Rive animation and navigate
              ElevatedButton(
                onPressed: () {
                  _triggerRiveJumpAnimation(); // Trigger the jump animation
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurgerySelectionScreen(),
                      ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Sunny will help you with your recovery. Answer some basic questions to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyles.font14Blue400Weight,
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
    riveHelper.dispose(); // Dispose of Rive controllers when the page is closed
  }
}
