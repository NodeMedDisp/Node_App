import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import for BlocProvider
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/../LoginComp/logic/cubit/auth_cubit.dart'; // Import your AuthCubit
import 'firebase_options.dart';
import 'LoginComp/routing/app_router.dart';
import 'LoginComp/routing/routes.dart';
import 'LoginComp/theming/colors.dart';

late String initialRoute;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    ScreenUtil.ensureScreenSize(),
  ]);

  // Determine the initial route based on auth state
  FirebaseAuth.instance.authStateChanges().listen(
        (user) {
      if (user == null || !user.emailVerified) {
        initialRoute = Routes.loginScreen;
      } else {
        initialRoute = Routes.homeScreen;
      }
    },
  );

  runApp(
    BlocProvider(
      create: (context) => AuthCubit(),
      child: MyApp(router: AppRouter()),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: 'Login & Signup App',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: ColorsManager.backGreen,
            primaryColor: ColorsManager.mainBlue,
            colorScheme: ColorScheme.fromSwatch().copyWith(
              secondary: ColorsManager.mainGreen,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: ColorsManager.mainBlue,
              selectionColor: ColorsManager.mainGreen,
              selectionHandleColor: ColorsManager.mainGreen,
            ),
          ),
          onGenerateRoute: router.generateRoute,
          debugShowCheckedModeBanner: false,
          initialRoute: initialRoute,
        );
      },
    );
  }
}
