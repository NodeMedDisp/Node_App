import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthCubit() : super(AuthInitial());

  Future<void> createAccountAndLinkItWithGoogleAccount(
      String email,
      String password,
      GoogleSignInAccount googleUser,
      OAuthCredential credential) async {
    emit(AuthLoading());

    try {
      await _auth.createUserWithEmailAndPassword(
        email: googleUser.email,
        password: password,
      );
      await _auth.currentUser!.linkWithCredential(credential);
      await _auth.currentUser!.updateDisplayName(googleUser.displayName);
      await _auth.currentUser!.updatePhotoURL(googleUser.photoUrl);
      emit(UserSingupAndLinkedWithGoogle());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      await _auth.sendPasswordResetEmail(email: email);
      emit(ResetPasswordSent());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user!.emailVerified) {
        emit(UserSignIn());
      } else {
        await _auth.signOut();
        emit(AuthError('Email not verified. Please check your email.'));
        emit(UserNotVerified());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());

    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );

    try {
      // Sign out any existing session to ensure a clean start
      await googleSignIn.signOut();

      // Start the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        emit(AuthError('Google Sign-In was cancelled or failed.'));
        return;
      }

      // Retrieve the ID token (accessToken is deprecated in newer versions)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        emit(AuthError('Failed to retrieve ID token from Google.'));
        return;
      }

      // Create Firebase credential using the ID token
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential authResult =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Check if the user is new
      if (authResult.additionalUserInfo?.isNewUser ?? false) {
        // Delete the auto-created Firebase user to handle onboarding manually
        await FirebaseAuth.instance.currentUser?.delete();

        emit(IsNewUser(
          googleUser: googleUser,
          credential: credential,
        ));
      } else {
        emit(UserSignIn());
      }
    } catch (e) {
      emit(AuthError('Google Sign-In failed: ${e.toString()}'));
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    await _auth.signOut();
    emit(UserSignedOut());
  }

  Future<void> signUpWithEmail(
      String name, String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _auth.currentUser!.updateDisplayName(name);
      await _auth.currentUser!.sendEmailVerification();
      await _auth.signOut();
      emit(UserSingupButNotVerified());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
