import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'LoginComp/logic/cubit/auth_cubit.dart';
import 'LoginComp/routing/app_router.dart';
import 'LoginComp/routing/routes.dart';
import 'LoginComp/theming/colors.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await RiveFile.initialize();
  }

  await Hive.initFlutter();
  await clearHiveBoxForTesting();
  await Hive.openBox<Map>('calendarData');
  await Hive.openBox<Map>('promptsData');
  await Hive.openBox<Map>('medicationsData');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    debugPrint('STARTUP ERROR: Firebase failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase startup failed:\n\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return;
  }

  User? user;
  try {
    user = FirebaseAuth.instance.currentUser;
  } catch (error, stackTrace) {
    debugPrint('STARTUP ERROR: Could not read current user: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  final preferences = await SharedPreferences.getInstance();
  final savedUserType = preferences.getString('userType');
  final savedClinicCode = preferences.getString('clinicCode');

  final String initialRoute;
  if (user == null || !user.emailVerified) {
    initialRoute = Routes.loginScreen;
  } else if (savedUserType == 'Provider') {
    initialRoute = Routes.providerMain;
  } else {
    initialRoute = Routes.homeScreen;
  }

  runApp(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return BlocProvider(
          create: (_) => AuthCubit(),
          child: MyApp(
            router: AppRouter(savedClinicCode: savedClinicCode),
            initialRoute: initialRoute,
          ),
        );
      },
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter router;
  final String initialRoute;

  const MyApp({
    super.key,
    required this.router,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NODE Recovery',
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
  }
}

/// Retained from the current main branch. Remove this test-only cleanup once
/// prompts and medications no longer need to be reset on every app start.
Future<void> clearHiveBoxForTesting() async {
  const boxNames = <String>[
    'promptsData',
    'medicationsData',
  ];

  for (final boxName in boxNames) {
    if (await Hive.boxExists(boxName)) {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }
}
