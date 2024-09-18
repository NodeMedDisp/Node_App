import 'package:flutter/material.dart';
import 'login_page.dart';  // Import the login page
import 'package:firebase_core/firebase_core.dart';  // Import Firebase Core

void main() async {
  // Ensure that all widgets are fully initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.greenAccent,
        ),
      ),
      home: MyHomePage(),  // Display the initial page
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Directly return the LoginPage
    return LoginPage(colorScheme: colorScheme);
  }
}
