import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../LoginComp/logic/cubit/auth_cubit.dart'; // Import your AuthCubit
import '/../LoginComp/screens/login/ui/login_screen.dart'; // Import your LoginScreen

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is UserSignedOut) {
          // Navigate to the login page after sign-out
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Home'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                // Call signOut from AuthCubit
                context.read<AuthCubit>().signOut();
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/NodeLogo.png',
                height: 200.h,
                width: 200.w,
              ),
              SizedBox(height: 20.h),
              Text(
                "Welcome to Node Recovery!",
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
