import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/medication.dart';
import '../../../../models/counseling_question.dart';
import '../../../core/widgets/login_and_signup_animated_form.dart';
import '../../../core/widgets/no_internet.dart';
import '../../../core/widgets/progress_indicaror.dart';
import '../../../core/widgets/sign_in_with_google_text.dart';
import '../../../core/widgets/terms_and_conditions_text.dart';
import '../../../helpers/extensions.dart';
import '../../../logic/cubit/auth_cubit.dart';
import '../../../routing/routes.dart';
import '../../../theming/colors.dart';
import '../../../theming/styles.dart';
import 'widgets/do_not_have_account.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _clinicCodeController = TextEditingController();
  String _userType = 'User';
  bool _showClinicCodeField = false;

  @override
  void initState() {
    super.initState();
    BlocProvider.of<AuthCubit>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OfflineBuilder(
        connectivityBuilder: (
            BuildContext context,
            List<ConnectivityResult> connectivity,
            Widget child,
            ) {
          final bool connected = connectivity.any(
                (result) => result != ConnectivityResult.none,
          );
          return connected ? _loginPage(context) : const BuildNoInternet();
        },
        child: const Center(
          child: CircularProgressIndicator(
            color: ColorsManager.mainBlue,
          ),
        ),
      ),
    );
  }

  SafeArea _loginPage(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 30.w, right: 30.w, bottom: 15.h, top: 5.h),
        child: SingleChildScrollView(
          child: BlocConsumer<AuthCubit, AuthState>(
            buildWhen: (previous, current) => previous != current,
            listenWhen: (previous, current) => previous != current,
            listener: (context, state) async {
              if (state is AuthLoading) {
                ProgressIndicaror.showProgressIndicator(context);
              } else if (state is AuthError) {
                context.pop();
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.error,
                  animType: AnimType.rightSlide,
                  title: 'Error',
                  desc: state.message,
                ).show();
              } else if (state is UserSignIn) {
                await _saveUserRole(_userType, _clinicCodeController.text);
                await Future.delayed(const Duration(seconds: 2));
                if (!context.mounted) return;

                if (_userType == 'Provider') {
                  context.pushNamedAndRemoveUntil(
                    Routes.providerMain,
                    predicate: (route) => false,
                    arguments: {
                      'clinicCode': _clinicCodeController.text,
                    },
                  );
                } else {
                  context.pushNamedAndRemoveUntil(
                    Routes.homeScreen,
                    predicate: (route) => false,
                    arguments: {
                      'prompts': const <CounselingQuestion>[],
                      'medications': const <Medication>[],
                    },
                  );
                }
              } else if (state is UserNotVerified) {
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.info,
                  animType: AnimType.rightSlide,
                  title: 'Email Not Verified',
                  desc: 'Please check your email and verify your email.',
                ).show();
              } else if (state is IsNewUser) {
                context.pushNamedAndRemoveUntil(
                  Routes.createPassword,
                  predicate: (route) => false,
                  arguments: [state.googleUser, state.credential],
                );
              }
            },
            builder: (context, state) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: TextStyles.font30Blue700Weight,
                        ),
                        Gap(10.h),
                        Text(
                          "Login To Continue Using The App",
                          style: TextStyles.font14Grey400Weight,
                        ),
                      ],
                    ),
                  ),
                  Gap(10.h),
                  SvgPicture.asset(
                    'assets/images/NodeLogo.png',
                    height: 100.h,
                    width: 200.w,
                  ),
                  Gap(10.h),
                  DropdownButtonFormField<String>(
                    value: _userType,
                    onChanged: (String? newValue) {
                      setState(() {
                        _userType = newValue!;
                        _showClinicCodeField = _userType == 'Provider';
                      });
                    },
                    items: <String>['User', 'Provider'].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: "I am a",
                      labelStyle: TextStyles.font14Grey400Weight,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 1.5),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                      ),
                    ),
                  ),
                  Gap(10.h),
                  if (_showClinicCodeField)
                    TextField(
                      controller: _clinicCodeController,
                      decoration: InputDecoration(
                        labelText: 'Clinic Access Code',
                        labelStyle: TextStyles.font14Grey400Weight,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 1.5),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: ColorsManager.mainBlue, width: 2.0),
                        ),
                      ),
                    ),
                  Gap(10.h),
                  EmailAndPassword(),
                  Gap(10.h),
                  const SigninWithGoogleText(),
                  Gap(5.h),
                  InkWell(
                    radius: 50.r,
                    onTap: () {
                      context.read<AuthCubit>().signInWithGoogle();
                    },
                    child: SvgPicture.asset(
                      'assets/svgs/google_logo.svg',
                      width: 50.w,
                      height: 50.h,
                    ),
                  ),
                  const TermsAndConditionsText(),
                  Gap(15.h),
                  const DoNotHaveAccountText(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveUserRole(String userType, String clinicCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userType', userType);
    if (userType == 'Provider') {
      await prefs.setString('clinicCode', clinicCode);
    }
  }
}
