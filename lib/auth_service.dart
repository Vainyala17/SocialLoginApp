import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'user_model.dart';
import 'db_helper.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Add this if you have a web client ID
    // serverClientId: 'your-web-client-id.googleusercontent.com',
  );

  // Google Sign In with better error handling
  static Future<UserModel?> signInWithGoogle(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // First, try to sign out any existing user
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      // Hide loading indicator
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (account != null) {
        final user = UserModel(
          id: account.id,
          name: account.displayName ?? 'Unknown',
          email: account.email,
          photo: account.photoUrl ?? '',
          loginType: 'google',
        );

        final success = await DBHelper.insertUser(user);
        if (success) {
          return user;
        } else {
          _showError(context, 'Failed to save user data');
        }
      } else {
        _showError(context, 'Google Sign-In was cancelled');
      }
      return null;
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      String errorMessage = 'Google Sign-In failed';

      // Handle specific error codes
      if (e.toString().contains('ApiException: 10')) {
        errorMessage = 'Google Sign-In configuration error. Please check:\n'
            '• SHA-1 fingerprint in Google Cloud Console\n'
            '• Package name matches\n'
            '• google-services.json is correct';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('sign_in_cancelled')) {
        errorMessage = 'Sign-in was cancelled';
      }

      _showError(context, errorMessage);
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  // Facebook Sign In
  static Future<UserModel?> signInWithFacebook(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      // Hide loading indicator
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (result.status == LoginStatus.success) {
        final userData = await FacebookAuth.instance.getUserData();

        final user = UserModel(
          id: userData['id'] ?? '',
          name: userData['name'] ?? 'Unknown',
          email: userData['email'] ?? '',
          photo: userData['picture']?['data']?['url'] ?? '',
          loginType: 'facebook',
        );

        final success = await DBHelper.insertUser(user);
        if (success) {
          return user;
        } else {
          _showError(context, 'Failed to save user data');
        }
      } else {
        _showError(context, 'Facebook Login Failed: ${result.message ?? result.status.toString()}');
      }
      return null;
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showError(context, 'Facebook Sign-In Error: ${e.toString()}');
      print('Facebook Sign-In Error: $e');
      return null;
    }
  }

  // Helper method to show errors
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Logout
  static Future<bool> logout() async {
    try {
      // Clear database
      await DBHelper.logout();

      // Google Sign-out
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Google signout error: $e');
      }

      // Facebook logout
      try {
        await FacebookAuth.instance.logOut();
      } catch (e) {
        print('Facebook logout error: $e');
      }

      return true;
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }
}