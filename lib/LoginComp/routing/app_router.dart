import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../Bluetooth/moc_ble_scanner_widget.dart';
import '../../Bluetooth/mock_ble_scanner_screen.dart';
import '../../GetStarted/provider_main_screen.dart';
import '../../HomePage/home_page.dart';
import '../../Patient/patient_cubit.dart';
import '../../Patient/patient_repository.dart';
import '../data/firestore_provider_repository.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/provider/provider_cubit.dart';
import '../screens/create_password/ui/create_password.dart';
import '../screens/forget/ui/forget_screen.dart';
import '../screens/login/ui/login_screen.dart';
import '../screens/signup/ui/sign_up_sceen.dart';
import 'routes.dart';

class AppRouter {
  final String? savedClinicCode;
  late AuthCubit authCubit;

  AppRouter({this.savedClinicCode}) {
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
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: authCubit),
              BlocProvider(
                create: (_) => PatientCubit(
                  repository: FirestorePatientRepository(),
                )..start(),
              ),
            ],
            child: const HomePage(),
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
        final args = settings.arguments as Map<String, dynamic>?;
        final clinicCode = args?['clinicCode'] as String? ?? savedClinicCode;
        final normalizedClinicId = clinicCode?.trim().isNotEmpty == true
            ? clinicCode!.trim()
            : 'demo-clinic';

        debugPrint(
          'ROUTER: Opening provider clinic=$normalizedClinicId',
        );

        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ProviderCubit(
              repository: FirestoreProviderRepository(),
            )..loadClinicData(normalizedClinicId),
            child: ProviderMainScreen(
              clinicCode: normalizedClinicId,
            ),
          ),
        );
    }

    return null;
  }
}
