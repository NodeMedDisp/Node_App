import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../../models/medication.dart';
import '../../../../models/counseling_question.dart';
import '../../../core/widgets/already_have_account_text.dart';
import '../../../core/widgets/login_and_signup_animated_form.dart';
import '../../../core/widgets/progress_indicaror.dart';
import '../../../core/widgets/sign_in_with_google_text.dart';
import '../../../core/widgets/terms_and_conditions_text.dart';
import '../../../logic/cubit/auth_cubit.dart';
import '../../../routing/routes.dart';
import '../../../theming/styles.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 30.w, right: 30.w, bottom: 15.h, top: 5.h),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Account',
                  style: TextStyles.font24Blue700Weight,
                ),
                Gap(8.h),
                Text(
                  'Sign up now and start exploring all that our\napp has to offer. We\'re excited to welcome\nyou to our community!',
                  style: TextStyles.font14Grey400Weight,
                ),
                Gap(8.h),
                BlocConsumer<AuthCubit, AuthState>(
                  buildWhen: (previous, current) => previous != current,
                  listenWhen: (previous, current) => previous != current,
                  listener: (context, state) async {
                    if (state is AuthLoading) {
                      ProgressIndicaror.showProgressIndicator(context);
                    } else if (state is AuthError) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      await AwesomeDialog(
                        context: context,
                        dialogType: DialogType.error,
                        animType: AnimType.rightSlide,
                        title: 'Error',
                        desc: state.message,
                      ).show();
                    } else if (state is UserSignIn) {
                      await Future.delayed(const Duration(seconds: 2));
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.homeScreen,
                        (route) => false,
                        arguments: {
                          'prompts': const <CounselingQuestion>[],
                          'medications': const <Medication>[],
                        },
                      );
                    } else if (state is IsNewUser) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.createPassword,
                        (route) => false,
                        arguments: [state.googleUser, state.credential],
                      );
                    } else if (state is UserSingupButNotVerified) {
                      Navigator.of(context).pop();
                      await AwesomeDialog(
                        context: context,
                        dialogType: DialogType.success,
                        animType: AnimType.rightSlide,
                        title: 'Sign up Success',
                        desc: 'Don\'t forget to verify your email check inbox.',
                      ).show();
                      await Future.delayed(const Duration(seconds: 2));
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.loginScreen,
                        (route) => false,
                      );
                    }
                  },
                  builder: (context, state) {
                    return Column(
                      children: [
                        EmailAndPassword(
                          isSignUpPage: true,
                        ),
                        Gap(10.h),
                        const SigninWithGoogleText(),
                        Gap(5.h),
                        InkWell(
                          onTap: () {
                            context.read<AuthCubit>().signInWithGoogle();
                          },
                          child: SvgPicture.asset(
                            'assets/svgs/google_logo.svg',
                            width: 40.w,
                            height: 40.h,
                          ),
                        ),
                        const TermsAndConditionsText(),
                        Gap(15.h),
                        const AlreadyHaveAccountText(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    BlocProvider.of<AuthCubit>(context);
  }
}
