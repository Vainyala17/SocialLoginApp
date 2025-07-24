import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
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

  // Instagram credentials - Replace with your actual credentials
  static const String instagramClientId = 'YOUR_INSTAGRAM_CLIENT_ID';
  static const String instagramClientSecret = 'YOUR_INSTAGRAM_CLIENT_SECRET';
  static const String instagramRedirectUri = 'https://yourapp.com/auth/instagram/callback';

  // Twitter credentials - Replace with your actual credentials
  static const String twitterClientId = 'YOUR_TWITTER_CLIENT_ID';
  static const String twitterClientSecret = 'YOUR_TWITTER_CLIENT_SECRET';
  static const String twitterRedirectUri = 'https://yourapp.com/auth/twitter/callback';

  // Instagram OAuth URLs
  static const String instagramAuthUrl = 'https://api.instagram.com/oauth/authorize';
  static const String instagramTokenUrl = 'https://api.instagram.com/oauth/access_token';
  static const String instagramUserUrl = 'https://graph.instagram.com/me';

  // Twitter OAuth URLs (OAuth 2.0 with PKCE)
  static const String twitterAuthUrl = 'https://twitter.com/i/oauth2/authorize';
  static const String twitterTokenUrl = 'https://api.twitter.com/2/oauth2/token';
  static const String twitterUserUrl = 'https://api.twitter.com/2/users/me';

  // Google Sign In with better error handling (Your existing code)
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

  // Facebook Sign In (Your existing code)
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

  // NEW: Instagram Sign In
  static Future<UserModel?> signInWithInstagram(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Step 1: Get authorization code
      final authCode = await _getInstagramAuthCode(context);
      if (authCode == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return null;
      }

      // Step 2: Exchange code for access token
      final accessToken = await _getInstagramAccessToken(authCode);
      if (accessToken == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Failed to get Instagram access token');
        return null;
      }

      // Step 3: Get user info
      final userInfo = await _getInstagramUserInfo(accessToken);
      if (userInfo == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Failed to get Instagram user info');
        return null;
      }

      // Hide loading indicator
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Step 4: Create user object and save
      final user = UserModel(
        id: userInfo['id'].toString(),
        name: userInfo['username'] ?? 'Instagram User',
        email: userInfo['email'] ?? '${userInfo['username']}@instagram.local',
        photo: userInfo['profile_picture_url'] ?? '',
        loginType: 'instagram',
      );

      final success = await DBHelper.insertUser(user);
      if (success) {
        return user;
      } else {
        _showError(context, 'Failed to save user data');
        return null;
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showError(context, 'Instagram Sign-In Error: ${e.toString()}');
      print('Instagram Sign-In Error: $e');
      return null;
    }
  }

  // NEW: Twitter Sign In
  static Future<UserModel?> signInWithTwitter(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Step 1: Get authorization code using PKCE
      final authData = await _getTwitterAuthCode(context);
      if (authData == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return null;
      }

      // Step 2: Exchange code for access token
      final accessToken = await _getTwitterAccessToken(
          authData['code']!,
          authData['codeVerifier']!
      );
      if (accessToken == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Failed to get Twitter access token');
        return null;
      }

      // Step 3: Get user info
      final userInfo = await _getTwitterUserInfo(accessToken);
      if (userInfo == null) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Failed to get Twitter user info');
        return null;
      }

      // Hide loading indicator
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Step 4: Create user object and save
      final user = UserModel(
        id: userInfo['id'].toString(),
        name: userInfo['name'] ?? userInfo['username'] ?? 'Twitter User',
        email: userInfo['email'] ?? '${userInfo['username']}@twitter.local',
        photo: userInfo['profile_image_url'] ?? '',
        loginType: 'twitter',
      );

      final success = await DBHelper.insertUser(user);
      if (success) {
        return user;
      } else {
        _showError(context, 'Failed to save user data');
        return null;
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showError(context, 'Twitter Sign-In Error: ${e.toString()}');
      print('Twitter Sign-In Error: $e');
      return null;
    }
  }

  // Instagram OAuth helper methods
  static Future<String?> _getInstagramAuthCode(BuildContext context) async {
    final authUrl = Uri.parse(instagramAuthUrl).replace(queryParameters: {
      'client_id': instagramClientId,
      'redirect_uri': instagramRedirectUri,
      'scope': 'user_profile,user_media',
      'response_type': 'code',
    });

    return await _showOAuthWebView(context, authUrl.toString(), instagramRedirectUri);
  }

  static Future<String?> _getInstagramAccessToken(String authCode) async {
    try {
      final response = await http.post(
        Uri.parse(instagramTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': instagramClientId,
          'client_secret': instagramClientSecret,
          'grant_type': 'authorization_code',
          'redirect_uri': instagramRedirectUri,
          'code': authCode,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Instagram token error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Instagram access token: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getInstagramUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$instagramUserUrl?fields=id,username,media_count&access_token=$accessToken'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Instagram user info error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Instagram user info: $e');
      return null;
    }
  }

  // Twitter OAuth helper methods with PKCE
  static Future<Map<String, String>?> _getTwitterAuthCode(BuildContext context) async {
    // Generate PKCE code verifier and challenge
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final authUrl = Uri.parse(twitterAuthUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': twitterClientId,
      'redirect_uri': twitterRedirectUri,
      'scope': 'tweet.read users.read offline.access',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final authCode = await _showOAuthWebView(context, authUrl.toString(), twitterRedirectUri);

    if (authCode != null) {
      return {
        'code': authCode,
        'codeVerifier': codeVerifier,
      };
    }
    return null;
  }

  static Future<String?> _getTwitterAccessToken(String authCode, String codeVerifier) async {
    try {
      final response = await http.post(
        Uri.parse(twitterTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$twitterClientId:$twitterClientSecret'))}',
        },
        body: {
          'code': authCode,
          'grant_type': 'authorization_code',
          'client_id': twitterClientId,
          'redirect_uri': twitterRedirectUri,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Twitter token error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Twitter access token: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getTwitterUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$twitterUserUrl?user.fields=profile_image_url,email'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        print('Twitter user info error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Twitter user info: $e');
      return null;
    }
  }

  // OAuth WebView helper
  static Future<String?> _showOAuthWebView(
      BuildContext context,
      String authUrl,
      String redirectUri
      ) async {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => OAuthWebView(
          authUrl: authUrl,
          redirectUri: redirectUri,
        ),
      ),
    );
  }

  // Helper methods for Twitter PKCE
  static String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // Helper method to show errors (Your existing code)
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

  // Logout (Your existing code)
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

// OAuth WebView Widget
class OAuthWebView extends StatefulWidget {
  final String authUrl;
  final String redirectUri;

  const OAuthWebView({
    Key? key,
    required this.authUrl,
    required this.redirectUri,
  }) : super(key: key);

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            if (url.startsWith(widget.redirectUri)) {
              _handleRedirect(url);
            }
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  void _handleRedirect(String url) {
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];

    if (code != null) {
      Navigator.of(context).pop(code);
    } else {
      final error = uri.queryParameters['error'];
      Navigator.of(context).pop(null);
      print('OAuth error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}