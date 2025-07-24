import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'user_model.dart';
import 'db_helper.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/user.birthday.read',
      'https://www.googleapis.com/auth/user.gender.read',
      'https://www.googleapis.com/auth/user.phonenumbers.read',
    ],
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
      final GoogleSignInAuthentication auth = await account!.authentication;
      final String accessToken = auth.accessToken!;


      final headers = {
        'Authorization': 'Bearer ${auth.accessToken}',
      };

      final response = await http.get(
        Uri.parse('https://people.googleapis.com/v1/people/me?personFields=names,emailAddresses,birthdays,genders,phoneNumbers'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🟡 Full API response: ${response.body}');
        print("Name: ${data['names']?[0]?['displayName']}");
        print("Email: ${data['emailAddresses']?[0]?['value']}");
        print("Birthday: ${data['birthdays']?[0]?['date']}");
        print("Gender: ${data['genders']?[0]?['value']}");
        print("Phone: ${data['phoneNumbers']?[0]?['value']}");
      } else {
        print('Failed to fetch user details: ${response.statusCode}');
        print(response.body);
      }


      // Hide loading indicator
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (account != null) {
        final data = response.statusCode == 200 ? json.decode(response.body) : {};

        final dobObj = data['birthdays']?[0]?['date'];
        String? dob;
        if (dobObj != null) {
          dob = '${dobObj['year'] ?? '0000'}-${dobObj['month']?.toString().padLeft(2, '0') ?? '00'}-${dobObj['day']?.toString().padLeft(2, '0') ?? '00'}';
        }

        final user = UserModel(
          id: account.id,
          name: account.displayName ?? 'Unknown',
          email: account.email,
          photo: account.photoUrl ?? '',
          loginType: 'google',
          dob: dob,
          gender: data['genders']?[0]?['value'],
          phone: (data['phoneNumbers'] != null && data['phoneNumbers'].isNotEmpty)
              ? data['phoneNumbers'][0]['value']
              : null,

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