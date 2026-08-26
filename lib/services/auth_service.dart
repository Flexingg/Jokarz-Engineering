import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

class AuthService {
  static const String _webClientId =
      '693644308941-1ach24ufnf3uv80pbqhmtecachjnf1ak.apps.googleusercontent.com';

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
  );

  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges();
  }

  User? get currentUser => _auth?.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get userDisplayName => currentUser?.displayName;
  String? get userEmail => currentUser?.email;
  String? get userPhotoUrl => currentUser?.photoURL;
  String? get userId => currentUser?.uid;

  /// Sign in with Google (Supports Android, iOS, Windows, and Web)
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        // Windows Desktop OAuth 2.0 PKCE loopback flow
        return await _signInWithGoogleWindows(auth);
      } else if (kIsWeb) {
        // Web Google Sign-In flow
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        return await auth.signInWithProvider(googleProvider);
      } else {
        // Android / iOS native Google Sign-In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User aborted Google sign-in
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('AuthService Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Switch / Change Google Account (forces account selector prompt)
  Future<UserCredential?> switchGoogleAccount() async {
    await signOut();
    return await signInWithGoogle();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        await _googleSignIn.disconnect().catchError((_) => null);
        await _googleSignIn.signOut();
      }
      await _auth?.signOut();
    } catch (e) {
      debugPrint('AuthService Sign-Out Error: $e');
    }
  }

  String _randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _deriveCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Windows Desktop Google OAuth 2.0 Loopback Auth with PKCE
  Future<UserCredential?> _signInWithGoogleWindows(FirebaseAuth auth) async {
    final codeVerifier = _randomString(64);
    final codeChallenge = _deriveCodeChallenge(codeVerifier);

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _webClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      final launched =
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not launch system browser for Google Sign-In');
      }

      // Await incoming redirect request (timeout after 2 minutes)
      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () =>
            throw TimeoutException('Sign in timed out waiting for browser response.'),
      );

      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

      request.response.headers.contentType = ContentType.html;
      if (code != null) {
        request.response.write('''
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <title>Jokarz Engineering Sign-In</title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                background-color: #0b151e;
                color: #e2e8f0;
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100vh;
                margin: 0;
              }
              .card {
                background: #122130;
                border: 1px solid #1f364d;
                border-radius: 16px;
                padding: 40px;
                text-align: center;
                box-shadow: 0 10px 25px rgba(0,0,0,0.5);
                max-width: 380px;
              }
              h1 { color: #00e5ff; margin-top: 0; font-size: 22px; }
              p { color: #94a3b8; font-size: 14px; line-height: 1.5; }
              .icon { font-size: 48px; margin-bottom: 16px; }
            </style>
          </head>
          <body>
            <div class="card">
              <div class="icon">⚙️</div>
              <h1>Sign-In Successful!</h1>
              <p>You have signed in to <strong>Jokarz Engineering</strong>.<br>You can close this tab and return to the desktop application.</p>
            </div>
          </body>
          </html>
        ''');
      } else {
        request.response.write(
            '<html><body style="background:#0b151e;color:#ff5252;padding:40px;font-family:sans-serif;"><h3>Sign-in cancelled or failed: $error</h3></body></html>');
      }
      await request.response.close();

      if (code == null) {
        throw Exception('Sign-in cancelled: $error');
      }

      // Exchange authorization code for OAuth ID & Access tokens
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _webClientId,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Failed to exchange auth code: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;

      if (idToken == null) {
        throw Exception('Google OAuth did not return an ID token');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      return await auth.signInWithCredential(credential);
    } finally {
      await server?.close(force: true);
    }
  }
}
