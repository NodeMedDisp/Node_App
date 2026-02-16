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

  await Hive.initFlutter();

  // Explicitly clear the Hive box for testing purposes
  await clearHiveBoxForTesting();

  // Open the Hive box after clearing it
  await Hive.openBox<Map>('calendarData');
  await Hive.openBox<Map>('promptsData');
  await Hive.openBox<Map>('medicationsData');


  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Determine the initial route
  final User? user = (() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      print("Error fetching current user: $e");
      return null;
    }
  })();

  final String initialRoute = (user == null || !user.emailVerified)
      ? Routes.loginScreen
      : Routes.homeScreen;

  runApp(
    BlocProvider(
      create: (context) => AuthCubit(),
      child: MyApp(router: AppRouter(), initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter router;
  final String initialRoute;

  const MyApp({super.key, required this.router, required this.initialRoute});

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

/// Clear a specific Hive box for testing purposes
Future<void> clearHiveBoxForTesting() async {
/*
  final boxName = 'calendarData';
  if (await Hive.boxExists(boxName)) {
    print("Clearing Hive box '$boxName'...");
    await Hive.deleteBoxFromDisk(boxName); // Deletes only this box
    print("Hive box '$boxName' cleared.");
  } else {
    print("Hive box '$boxName' does not exist; nothing to clear.");
  }
*/
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
