import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  // Use super parameter for key
  const LoginPage({super.key, required this.colorScheme});

  final ColorScheme colorScheme;  // ColorScheme passed in from main.dart

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use Firebase Authentication to log in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Handle successful login (remove print statement for production)
      // You can replace this with proper navigation or state change logic
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Changed from background to surface
      backgroundColor: widget.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: widget.colorScheme.primary,
        title: Text('Login', style: TextStyle(color: widget.colorScheme.onPrimary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                // Changed from onBackground to onSurface
                labelStyle: TextStyle(color: widget.colorScheme.onSurface),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.colorScheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.colorScheme.secondary),
                ),
              ),
              style: TextStyle(color: widget.colorScheme.onSurface),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                // Changed from onBackground to onSurface
                labelStyle: TextStyle(color: widget.colorScheme.onSurface),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.colorScheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.colorScheme.secondary),
                ),
              ),
              style: TextStyle(color: widget.colorScheme.onSurface),
            ),
            const SizedBox(height: 24.0),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16.0),
            _isLoading
                ? CircularProgressIndicator(color: widget.colorScheme.primary)
                : ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.colorScheme.primary,
                foregroundColor: widget.colorScheme.onPrimary,
              ),
              child: const Text('Login'),  // Added 'const' for performance
            ),
          ],
        ),
      ),
    );
  }
}
