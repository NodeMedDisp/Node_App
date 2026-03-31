import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../Bluetooth/moc_ble_scanner_widget.dart';
import '../../Bluetooth/mock_ble_scanner_screen.dart';
import '../logic/provider/provider_cubit.dart';
import '/GetStarted/provider_main_screen.dart';
import '/HomePage/home_page.dart';
import '../../models/medication.dart';
import '../../models/counseling_question.dart';
import '../logic/cubit/auth_cubit.dart';
import '../screens/create_password/ui/create_password.dart';
import '../screens/forget/ui/forget_screen.dart';
import '../screens/login/ui/login_screen.dart';
import '../screens/signup/ui/sign_up_sceen.dart';
import 'routes.dart';

class AppRouter {
  late AuthCubit authCubit;

  AppRouter() {
    authCubit = AuthCubit();
  }

  Route? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.forgetScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const ForgetScreen(),
          ),
        );

      case Routes.homeScreen:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: HomePage(
              prompts: args?['prompts'] as List<CounselingQuestion>? ?? [],
              medications: args?['medications'] as List<Medication>? ?? [],
            ),
          ),
        );

      case Routes.mockBLEScannerScreen:
        return MaterialPageRoute(
          builder: (_) => const MockBLEScannerScreen(),
        );

      case Routes.mockBLEScannerWidget:
        return MaterialPageRoute(
          builder: (_) => const MockBLEScannerWidget(),
        );

      case Routes.createPassword:
        final arguments = settings.arguments;
        if (arguments is List) {
          return MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: authCubit,
              child: CreatePassword(
                googleUser: arguments[0],
                credential: arguments[1],
              ),
            ),
          );
        }

      case Routes.signupScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const SignUpScreen(),
          ),
        );

      case Routes.loginScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const LoginScreen(),
          ),
        );

      case Routes.providerMain:
        final arguments = settings.arguments;
        String? clinicCode;
        if (arguments is Map<String, dynamic>) {
          clinicCode = arguments['clinicCode'] as String?;
        }

        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ProviderCubit()..loadClinicData(clinicCode),
            child: ProviderMainScreen(clinicCode: clinicCode),
          ),
        );
    }
    return null;
  }
}
