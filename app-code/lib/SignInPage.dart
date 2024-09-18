import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // For email and password sign-up and sign-in
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    forceSignOut();  // Sign out the user every time the app starts
  }

  // Automatically sign the user out when the app starts
  Future<void> forceSignOut() async {
    await GoogleSignIn().signOut();  // Sign out from Google
    await _auth.signOut();           // Sign out from Firebase
    print("User is signed out. They must sign in again.");
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut();  // Ensure sign-out to force account selection

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;  // If the user cancels the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        print("User signed in: ${user.displayName}");
        return user;
      }
    } catch (e) {
      print("Error during Google sign-in: $e");
      return null;
    }
  }

  // Create a new account with email and password
  Future<void> signUpWithEmailAndPassword() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      User? user = userCredential.user;
      if (user != null) {
        print("User created: ${user.email}");
        updateUI(user);
      }
    } catch (e) {
      print("Error during sign-up: $e");
    }
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      User? user = userCredential.user;
      if (user != null) {
        print("User signed in: ${user.email}");
        updateUI(user);
      }
    } catch (e) {
      print("Error during sign-in: $e");
    }
  }

  // Navigate to Home Page after signing in
  void updateUI(User? user) {
    if (user != null) {
      // Delay the navigation until after the build is done
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      });
    } else {
      // Show a SnackBar if sign-in fails
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sign in")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign In")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google Sign-In Button
              ElevatedButton(
                onPressed: () async {
                  User? user = await signInWithGoogle();
                  if (user != null) {
                    updateUI(user);
                  }
                },
                child: Text("Sign in with Google"),
              ),
              SizedBox(height: 20),

              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 10),

              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              SizedBox(height: 20),

              // Email/Password Sign-Up Button
              ElevatedButton(
                onPressed: () async {
                  await signUpWithEmailAndPassword();
                },
                child: Text("Create Account"),
              ),
              SizedBox(height: 10),

              // Email/Password Sign-In Button
              ElevatedButton(
                onPressed: () async {
                  await signInWithEmailAndPassword();
                },
                child: Text("Sign in with Email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Page after signing in
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome"),
      ),
      body: Center(
        child: Text(
          "Welcome to Node",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
