import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:rive/rive.dart';
import 'LoginComp/logic/cubit/auth_cubit.dart'; // Update the import path
import 'firebase_options.dart';
import 'LoginComp/routing/app_router.dart';
import 'LoginComp/routing/routes.dart';
import 'LoginComp/theming/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required for Flutter Web when using Rive
  if (kIsWeb) {
    await RiveFile.initialize();
  }

  debugPrint('Before Hive');
  await Hive.initFlutter();

  // Explicitly clear the Hive box for testing purposes
  debugPrint('Before Clear Hive');
  await clearHiveBoxForTesting();

  // Open the Hive box after clearing it
  debugPrint('Before Opening Hive');
  await Hive.openBox<Map>('calendarData');
  await Hive.openBox<Map>('promptsData');
  await Hive.openBox<Map>('medicationsData');

  debugPrint('STARTUP 1: Before Firebase');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));

    debugPrint('STARTUP 2: Firebase initialized');
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

  debugPrint('STARTUP 3: Before reading Firebase user');

  User? user;

  try {
    user = FirebaseAuth.instance.currentUser;
    debugPrint('STARTUP 4: Current user read successfully');
    debugPrint('STARTUP 4A: User signed in = ${user != null}');
    debugPrint('STARTUP 4B: Email verified = ${user?.emailVerified}');
  } catch (error, stackTrace) {
    debugPrint('STARTUP ERROR: Could not read current user: $error');
    debugPrintStack(stackTrace: stackTrace);
    user = null;
  }

  final String initialRoute = (user == null || !user.emailVerified)
      ? Routes.loginScreen
      : Routes.homeScreen;

  debugPrint('STARTUP 5: Initial route = $initialRoute');
  debugPrint('STARTUP 6: Before runApp');

  debugPrint('STARTUP 6: Before runApp');

  runApp(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        debugPrint('STARTUP 7: ScreenUtil initialized');

        return BlocProvider(
          create: (_) => AuthCubit(),
          child: MyApp(
            router: AppRouter(),
            initialRoute: initialRoute,
          ),
        );
      },
    ),
  );

  debugPrint('STARTUP 8: After runApp');
}

class MyApp extends StatelessWidget {
  final AppRouter router;
  final String initialRoute;

  const MyApp({super.key, required this.router, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    debugPrint('STARTUP 9: MyApp build called');

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
  }
}

/// Clear a specific Hive box for testing purposes
Future<void> clearHiveBoxForTesting() async {
  final boxName2 = 'promptsData';
  if (await Hive.boxExists(boxName2)) {
    print("Clearing Hive box '$boxName2'...");
    await Hive.deleteBoxFromDisk(boxName2); // Deletes only this box
    print("Hive box '$boxName2' cleared.");
  } else {
    print("Hive box '$boxName2' does not exist; nothing to clear.");
  }

  final boxName3 = 'medicationsData';
  if (await Hive.boxExists(boxName3)) {
    print("Clearing Hive box '$boxName3'...");
    await Hive.deleteBoxFromDisk(boxName3); // Deletes only this box
    print("Hive box '$boxName3' cleared.");
  } else {
    print("Hive box '$boxName3' does not exist; nothing to clear.");
  }
}
